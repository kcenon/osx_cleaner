// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! File system utilities module
//!
//! Provides file system abstractions and utilities for the cleaner.

use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

/// Information about disk usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskUsage {
    pub total_bytes: u64,
    pub used_bytes: u64,
    pub available_bytes: u64,
    pub usage_percent: f64,
}

/// Get disk usage for a path
pub fn get_disk_usage(path: &str) -> Result<DiskUsage, FsError> {
    use sysinfo::Disks;

    let path = Path::new(path);
    let disks = Disks::new_with_refreshed_list();

    // Find the disk that contains this path
    let disk = disks
        .iter()
        .filter(|d| path.starts_with(d.mount_point()))
        .max_by_key(|d| d.mount_point().as_os_str().len())
        .ok_or_else(|| FsError::DiskNotFound(path.to_string_lossy().to_string()))?;

    let total = disk.total_space();
    let available = disk.available_space();
    let used = total.saturating_sub(available);
    let percent = if total > 0 {
        (used as f64 / total as f64) * 100.0
    } else {
        0.0
    };

    Ok(DiskUsage {
        total_bytes: total,
        used_bytes: used,
        available_bytes: available,
        usage_percent: percent,
    })
}

/// Calculate the size of a path (file or directory)
pub fn get_size(path: &str) -> Result<u64, FsError> {
    let path = Path::new(path);

    if !path.exists() {
        return Err(FsError::PathNotFound(path.to_string_lossy().to_string()));
    }

    if path.is_file() {
        Ok(fs::metadata(path)
            .map_err(|e| FsError::IoError(e.to_string()))?
            .len())
    } else {
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
    }
}

/// Format bytes as human-readable string
pub fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB", "PB"];
    const THRESHOLD: f64 = 1024.0;

    if bytes == 0 {
        return "0 B".to_string();
    }

    let mut size = bytes as f64;
    let mut unit_index = 0;

    while size >= THRESHOLD && unit_index < UNITS.len() - 1 {
        size /= THRESHOLD;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.2} {}", size, UNITS[unit_index])
    }
}

/// Check if a path is writable
pub fn is_writable(path: &str) -> bool {
    let path = Path::new(path);

    if !path.exists() {
        // Check if parent directory is writable
        if let Some(parent) = path.parent() {
            // If parent path cannot be converted to string, treat as not writable
            if let Some(parent_str) = parent.to_str() {
                return is_writable(parent_str);
            }
            return false;
        }
        return false;
    }

    // Try to open file/dir for writing
    if path.is_file() {
        fs::OpenOptions::new().write(true).open(path).is_ok()
    } else {
        // For directories, try to create a temporary file
        let test_path = path.join(".osxcleaner_test");
        if fs::write(&test_path, "").is_ok() {
            let _ = fs::remove_file(&test_path);
            true
        } else {
            false
        }
    }
}

/// Check if a path exists
pub fn exists(path: &str) -> bool {
    Path::new(path).exists()
}

/// Check if a path is a directory
pub fn is_directory(path: &str) -> bool {
    Path::new(path).is_dir()
}

/// Check if a path is a file
pub fn is_file(path: &str) -> bool {
    Path::new(path).is_file()
}

/// Check if a path is a symlink
pub fn is_symlink(path: &str) -> bool {
    Path::new(path).is_symlink()
}

/// File system errors
#[derive(Debug, thiserror::Error)]
pub enum FsError {
    #[error("Path not found: {0}")]
    PathNotFound(String),

    #[error("Disk not found for path: {0}")]
    DiskNotFound(String),

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
    fn test_format_bytes() {
        assert_eq!(format_bytes(0), "0 B");
        assert_eq!(format_bytes(512), "512 B");
        assert_eq!(format_bytes(1024), "1.00 KB");
        assert_eq!(format_bytes(1024 * 1024), "1.00 MB");
        assert_eq!(format_bytes(1024 * 1024 * 1024), "1.00 GB");
    }

    #[test]
    fn test_get_size_file() {
        let dir = tempdir().expect("Failed to create temp directory");
        let file_path = dir.path().join("test.txt");
        std::fs::write(&file_path, "hello").expect("Failed to write test file");

        let size = get_size(file_path.to_str().expect("Path should be valid UTF-8"))
            .expect("Get size should succeed");
        assert_eq!(size, 5);
    }

    #[test]
    fn test_get_size_directory() {
        let dir = tempdir().expect("Failed to create temp directory");
        std::fs::write(dir.path().join("a.txt"), "aaa").expect("Failed to write test file a");
        std::fs::write(dir.path().join("b.txt"), "bb").expect("Failed to write test file b");

        let size = get_size(dir.path().to_str().expect("Path should be valid UTF-8"))
            .expect("Get size should succeed");
        assert_eq!(size, 5);
    }

    #[test]
    fn test_is_writable() {
        let dir = tempdir().expect("Failed to create temp directory");
        assert!(is_writable(
            dir.path().to_str().expect("Path should be valid UTF-8")
        ));

        let file_path = dir.path().join("test.txt");
        std::fs::write(&file_path, "test").expect("Failed to write test file");
        assert!(is_writable(
            file_path.to_str().expect("Path should be valid UTF-8")
        ));
    }

    #[test]
    fn test_exists() {
        let dir = tempdir().unwrap();
        assert!(exists(dir.path().to_str().unwrap()));
        assert!(!exists("/nonexistent/path"));
    }

    #[test]
    fn test_is_directory() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(&file_path, "test").unwrap();

        assert!(is_directory(dir.path().to_str().unwrap()));
        assert!(!is_directory(file_path.to_str().unwrap()));
    }
}
