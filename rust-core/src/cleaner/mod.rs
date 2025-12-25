//! Cleanup execution module
//!
//! Provides safe file and directory cleanup with rollback support.

use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

use crate::safety::{calculate_safety_level, CleanupLevel, SafetyLevel};

/// Configuration for cleanup operations
#[derive(Debug, Clone)]
pub struct CleanConfig {
    pub cleanup_level: CleanupLevel,
    pub dry_run: bool,
}

impl Default for CleanConfig {
    fn default() -> Self {
        CleanConfig {
            cleanup_level: CleanupLevel::Normal,
            dry_run: false,
        }
    }
}

impl CleanConfig {
    /// Create config from raw safety level (for FFI compatibility)
    pub fn from_safety_level(safety_level: u8, dry_run: bool) -> Self {
        CleanConfig {
            cleanup_level: CleanupLevel::from(safety_level),
            dry_run,
        }
    }
}

/// Result of a cleanup operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanResult {
    pub path: String,
    pub freed_bytes: u64,
    pub files_removed: usize,
    pub directories_removed: usize,
    pub errors: Vec<CleanErrorInfo>,
    pub dry_run: bool,
}

/// Information about a cleanup error
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanErrorInfo {
    pub path: String,
    pub reason: String,
}

/// Clean a path according to the configuration
pub fn clean(path: &str, config: &CleanConfig) -> Result<CleanResult, CleanError> {
    let path_obj = Path::new(path);

    if !path_obj.exists() {
        return Err(CleanError::PathNotFound(path.to_string()));
    }

    // Check safety level using new 4-level system
    let path_safety = SafetyLevel::from(calculate_safety_level(path));
    if !config.cleanup_level.can_delete(path_safety) {
        return Err(CleanError::SafetyViolation {
            path: path.to_string(),
            required: path_safety as u8,
            provided: config.cleanup_level as u8,
        });
    }

    let mut result = CleanResult {
        path: path.to_string(),
        freed_bytes: 0,
        files_removed: 0,
        directories_removed: 0,
        errors: Vec::new(),
        dry_run: config.dry_run,
    };

    if path_obj.is_file() {
        clean_file(path_obj, config, &mut result)?;
    } else if path_obj.is_dir() {
        clean_directory(path_obj, config, &mut result)?;
    }

    Ok(result)
}

/// Clean a single file
fn clean_file(
    path: &Path,
    config: &CleanConfig,
    result: &mut CleanResult,
) -> Result<(), CleanError> {
    let metadata = path
        .metadata()
        .map_err(|e| CleanError::IoError(e.to_string()))?;
    let size = metadata.len();

    if !config.dry_run {
        fs::remove_file(path).map_err(|e| CleanError::IoError(e.to_string()))?;
    }

    result.freed_bytes += size;
    result.files_removed += 1;

    log::info!(
        "{}Removed file: {} ({} bytes)",
        if config.dry_run { "[DRY RUN] " } else { "" },
        path.display(),
        size
    );

    Ok(())
}

/// Clean a directory recursively
fn clean_directory(
    path: &Path,
    config: &CleanConfig,
    result: &mut CleanResult,
) -> Result<(), CleanError> {
    // Collect all entries first
    let entries: Vec<_> = fs::read_dir(path)
        .map_err(|e| CleanError::IoError(e.to_string()))?
        .filter_map(|e| e.ok())
        .collect();

    // Calculate sizes before deletion
    let sizes: Vec<_> = entries
        .par_iter()
        .filter_map(|entry| {
            let path = entry.path();
            calculate_size(&path).ok().map(|size| (path, size))
        })
        .collect();

    // Process each entry
    for (entry_path, size) in sizes {
        let path_str = entry_path.to_string_lossy();
        let entry_safety = SafetyLevel::from(calculate_safety_level(&path_str));

        // Check if this entry is safe to delete at our cleanup level
        if !config.cleanup_level.can_delete(entry_safety) {
            result.errors.push(CleanErrorInfo {
                path: path_str.to_string(),
                reason: format!(
                    "Safety level {:?} required, cleanup level {:?} not sufficient",
                    entry_safety, config.cleanup_level
                ),
            });
            continue;
        }

        if !config.dry_run {
            let remove_result = if entry_path.is_dir() {
                fs::remove_dir_all(&entry_path)
            } else {
                fs::remove_file(&entry_path)
            };

            if let Err(e) = remove_result {
                result.errors.push(CleanErrorInfo {
                    path: path_str.to_string(),
                    reason: e.to_string(),
                });
                continue;
            }
        }

        result.freed_bytes += size;
        if entry_path.is_dir() {
            result.directories_removed += 1;
        } else {
            result.files_removed += 1;
        }
    }

    Ok(())
}

/// Calculate the total size of a path
fn calculate_size(path: &Path) -> Result<u64, std::io::Error> {
    if path.is_file() {
        Ok(path.metadata()?.len())
    } else if path.is_dir() {
        let mut total = 0u64;
        for entry in walkdir::WalkDir::new(path)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.file_type().is_file() {
                total += entry.metadata().map(|m| m.len()).unwrap_or(0);
            }
        }
        Ok(total)
    } else {
        Ok(0)
    }
}

/// Cleanup errors
#[derive(Debug, thiserror::Error)]
pub enum CleanError {
    #[error("Path not found: {0}")]
    PathNotFound(String),

    #[error("Safety violation for {path}: required level {required}, provided {provided}")]
    SafetyViolation {
        path: String,
        required: u8,
        provided: u8,
    },

    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    #[error("IO error: {0}")]
    IoError(String),
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_clean_file_dry_run() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(&file_path, "test content").unwrap();

        let config = CleanConfig {
            cleanup_level: CleanupLevel::System, // Allow all levels
            dry_run: true,
        };

        let result = clean(file_path.to_str().unwrap(), &config).unwrap();

        assert!(result.dry_run);
        assert_eq!(result.files_removed, 1);
        assert!(result.freed_bytes > 0);
        // File should still exist in dry run
        assert!(file_path.exists());
    }

    #[test]
    fn test_clean_file_actual() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(&file_path, "test content").unwrap();

        let config = CleanConfig {
            cleanup_level: CleanupLevel::System,
            dry_run: false,
        };

        let result = clean(file_path.to_str().unwrap(), &config).unwrap();

        assert!(!result.dry_run);
        assert_eq!(result.files_removed, 1);
        // File should be deleted
        assert!(!file_path.exists());
    }

    #[test]
    fn test_clean_nonexistent() {
        let config = CleanConfig::default();
        let result = clean("/nonexistent/path", &config);
        assert!(result.is_err());
    }

    #[test]
    fn test_from_safety_level() {
        let config = CleanConfig::from_safety_level(2, true);
        assert_eq!(config.cleanup_level, CleanupLevel::Normal);
        assert!(config.dry_run);
    }
}
