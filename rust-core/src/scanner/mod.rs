//! File system scanner module
//!
//! Provides parallel directory scanning and analysis capabilities.

// Allow deprecated categorize_path until scanner is refactored to use SafetyValidator
#![allow(deprecated)]

use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use walkdir::WalkDir;

use crate::safety::{categorize_path, PathCategory};

/// Analysis result for a scanned path
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub path: String,
    pub total_size: u64,
    pub file_count: usize,
    pub directory_count: usize,
    pub categories: Vec<CategoryStats>,
    pub largest_items: Vec<FileInfo>,
    pub oldest_items: Vec<FileInfo>,
}

/// Statistics for a category
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryStats {
    pub category: String,
    pub size: u64,
    pub count: usize,
}

/// Information about a file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileInfo {
    pub path: String,
    pub size: u64,
    pub modified: Option<i64>,
    pub category: String,
}

/// Scanner configuration
#[derive(Debug, Clone)]
pub struct ScanConfig {
    pub max_depth: Option<usize>,
    pub follow_symlinks: bool,
    pub include_hidden: bool,
    pub min_size: Option<u64>,
}

impl Default for ScanConfig {
    fn default() -> Self {
        ScanConfig {
            max_depth: None,
            follow_symlinks: false,
            include_hidden: true,
            min_size: None,
        }
    }
}

/// Analyze a path and return statistics
pub fn analyze(path: &str) -> Result<AnalysisResult, ScanError> {
    analyze_with_config(path, &ScanConfig::default())
}

/// Analyze a path with custom configuration
pub fn analyze_with_config(path: &str, config: &ScanConfig) -> Result<AnalysisResult, ScanError> {
    let path = Path::new(path);

    if !path.exists() {
        return Err(ScanError::PathNotFound(path.to_string_lossy().to_string()));
    }

    let mut walker = WalkDir::new(path).follow_links(config.follow_symlinks);

    if let Some(depth) = config.max_depth {
        walker = walker.max_depth(depth);
    }

    // Collect entries in parallel
    let entries: Vec<_> = walker
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| {
            if !config.include_hidden {
                e.file_name()
                    .to_str()
                    .map(|s| !s.starts_with('.'))
                    .unwrap_or(false)
            } else {
                true
            }
        })
        .collect();

    // Process entries in parallel
    let file_infos: Vec<FileInfo> = entries
        .par_iter()
        .filter(|e| e.file_type().is_file())
        .filter_map(|e| {
            let metadata = e.metadata().ok()?;
            let size = metadata.len();

            if let Some(min) = config.min_size {
                if size < min {
                    return None;
                }
            }

            let path_str = e.path().to_string_lossy().to_string();
            let category = categorize_path(&path_str);

            let modified = metadata
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as i64);

            Some(FileInfo {
                path: path_str,
                size,
                modified,
                category: format!("{:?}", category),
            })
        })
        .collect();

    // Calculate statistics
    let total_size: u64 = file_infos.iter().map(|f| f.size).sum();
    let file_count = file_infos.len();
    let directory_count = entries.iter().filter(|e| e.file_type().is_dir()).count();

    // Group by category
    let mut category_map: HashMap<PathCategory, (u64, usize)> = HashMap::new();
    for entry in &entries {
        if entry.file_type().is_file() {
            let path_str = entry.path().to_string_lossy();
            let category = categorize_path(&path_str);
            let size = entry.metadata().map(|m| m.len()).unwrap_or(0);

            let entry = category_map.entry(category).or_insert((0, 0));
            entry.0 += size;
            entry.1 += 1;
        }
    }

    let categories: Vec<CategoryStats> = category_map
        .into_iter()
        .map(|(cat, (size, count))| CategoryStats {
            category: format!("{:?}", cat),
            size,
            count,
        })
        .collect();

    // Get top 10 largest files
    let mut largest = file_infos.clone();
    largest.sort_by(|a, b| b.size.cmp(&a.size));
    let largest_items: Vec<FileInfo> = largest.into_iter().take(10).collect();

    // Get top 10 oldest files
    let mut oldest = file_infos;
    oldest.sort_by(|a, b| a.modified.cmp(&b.modified));
    let oldest_items: Vec<FileInfo> = oldest.into_iter().take(10).collect();

    Ok(AnalysisResult {
        path: path.to_string_lossy().to_string(),
        total_size,
        file_count,
        directory_count,
        categories,
        largest_items,
        oldest_items,
    })
}

/// Scanner errors
#[derive(Debug, thiserror::Error)]
pub enum ScanError {
    #[error("Path not found: {0}")]
    PathNotFound(String),

    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_analyze_empty_dir() {
        let dir = tempdir().unwrap();
        let result = analyze(dir.path().to_str().unwrap()).unwrap();

        assert_eq!(result.file_count, 0);
        assert_eq!(result.total_size, 0);
    }

    #[test]
    fn test_analyze_with_files() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(&file_path, "hello world").unwrap();

        let result = analyze(dir.path().to_str().unwrap()).unwrap();

        assert_eq!(result.file_count, 1);
        assert!(result.total_size > 0);
    }

    #[test]
    fn test_analyze_nonexistent_path() {
        let result = analyze("/nonexistent/path");
        assert!(result.is_err());
    }
}
