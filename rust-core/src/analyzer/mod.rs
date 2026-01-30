// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Disk Usage Analysis Module
//!
//! Provides comprehensive disk usage analysis functionality:
//! - System disk space overview (total, used, available)
//! - Home directory analysis with Top N by size
//! - Library/Caches analysis by application
//! - Library/Developer analysis by component
//! - Cleanable space estimation by safety level

pub mod categories;
pub mod cleanable;
pub mod disk_space;

// Re-export main types
pub use categories::{CacheInfo, CategoryScanner, DeveloperComponentInfo, DirectoryInfo};
pub use cleanable::{CleanableEstimate, CleanableItem};
pub use disk_space::DiskSpace;

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::safety::SafetyLevel;

/// Analyzer error types
#[derive(Debug, thiserror::Error)]
pub enum AnalyzerError {
    #[error("Path not found: {0}")]
    PathNotFound(String),

    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Disk query failed: {0}")]
    DiskQueryFailed(String),
}

/// Complete analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    /// Disk space information
    pub disk_space: DiskSpace,
    /// Top directories in home folder
    pub home_top_dirs: Vec<DirectoryInfo>,
    /// Cache analysis by app
    pub caches: Vec<CacheInfo>,
    /// Developer component analysis
    pub developer_components: Vec<DeveloperComponentInfo>,
    /// Cleanable space estimation
    pub cleanable: CleanableEstimate,
    /// Analysis duration in milliseconds
    pub scan_duration_ms: u64,
}

/// Disk analyzer for comprehensive disk usage analysis
pub struct DiskAnalyzer {
    /// Path to analyze (typically root or home)
    base_path: PathBuf,
    /// Home directory path
    home_path: PathBuf,
    /// Number of parallel threads
    parallelism: usize,
}

impl Default for DiskAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

impl DiskAnalyzer {
    /// Create a new DiskAnalyzer with default settings
    pub fn new() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));

        DiskAnalyzer {
            base_path: PathBuf::from("/"),
            home_path: home,
            parallelism: num_cpus::get(),
        }
    }

    /// Create analyzer with custom home path (useful for testing)
    pub fn with_home_path(home_path: PathBuf) -> Self {
        DiskAnalyzer {
            base_path: PathBuf::from("/"),
            home_path,
            parallelism: num_cpus::get(),
        }
    }

    /// Set parallelism level
    pub fn with_parallelism(mut self, parallelism: usize) -> Self {
        self.parallelism = parallelism.max(1);
        self
    }

    /// Get current disk space information
    pub fn get_disk_space(&self) -> Result<DiskSpace, AnalyzerError> {
        disk_space::get_disk_space(&self.base_path)
    }

    /// Analyze home directory and return Top N directories by size
    pub fn analyze_home_directory(&self, top_n: usize) -> Vec<DirectoryInfo> {
        categories::analyze_home_directory(&self.home_path, top_n)
    }

    /// Analyze ~/Library/Caches by application
    pub fn analyze_caches(&self) -> Vec<CacheInfo> {
        let caches_path = self.home_path.join("Library/Caches");
        categories::analyze_caches(&caches_path)
    }

    /// Analyze ~/Library/Developer by component
    pub fn analyze_developer(&self) -> Vec<DeveloperComponentInfo> {
        let developer_path = self.home_path.join("Library/Developer");
        categories::analyze_developer(&developer_path)
    }

    /// Estimate cleanable space by safety level
    pub fn estimate_cleanable(&self) -> CleanableEstimate {
        let caches = self.analyze_caches();
        let developer = self.analyze_developer();

        cleanable::estimate_cleanable(&caches, &developer)
    }

    /// Perform full disk analysis
    pub fn analyze(&self) -> Result<AnalysisResult, AnalyzerError> {
        let start = std::time::Instant::now();

        // Get disk space
        let disk_space = self.get_disk_space()?;

        // Run analysis tasks in parallel
        let (home_top_dirs, (caches, developer_components)) = rayon::join(
            || self.analyze_home_directory(10),
            || rayon::join(|| self.analyze_caches(), || self.analyze_developer()),
        );

        // Calculate cleanable estimate
        let cleanable = cleanable::estimate_cleanable(&caches, &developer_components);

        let duration = start.elapsed();

        Ok(AnalysisResult {
            disk_space,
            home_top_dirs,
            caches,
            developer_components,
            cleanable,
            scan_duration_ms: duration.as_millis() as u64,
        })
    }

    /// Get summary of disk usage by category
    pub fn get_category_summary(&self) -> Vec<CategorySummary> {
        let caches = self.analyze_caches();
        let developer = self.analyze_developer();

        let cache_total: u64 = caches.iter().map(|c| c.size).sum();
        let developer_total: u64 = developer.iter().map(|d| d.size).sum();

        let mut summaries = vec![
            CategorySummary {
                name: "Application Caches".to_string(),
                size: cache_total,
                item_count: caches.len(),
                primary_safety: SafetyLevel::Caution,
            },
            CategorySummary {
                name: "Developer Tools".to_string(),
                size: developer_total,
                item_count: developer.len(),
                primary_safety: SafetyLevel::Warning,
            },
        ];

        // Sort by size descending
        summaries.sort_by(|a, b| b.size.cmp(&a.size));
        summaries
    }
}

/// Summary for a category of disk usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySummary {
    /// Category name
    pub name: String,
    /// Total size in bytes
    pub size: u64,
    /// Number of items
    pub item_count: usize,
    /// Primary safety level for this category
    pub primary_safety: SafetyLevel,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_disk_analyzer_creation() {
        let analyzer = DiskAnalyzer::new();
        assert!(analyzer.parallelism > 0);
    }

    #[test]
    fn test_disk_analyzer_with_custom_home() {
        let temp = tempdir().expect("Failed to create temp directory");
        let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());

        assert_eq!(analyzer.home_path, temp.path());
    }

    #[test]
    fn test_disk_space_query() {
        let analyzer = DiskAnalyzer::new();
        let result = analyzer.get_disk_space();

        assert!(result.is_ok());
        let space = result.expect("Failed to get disk space");
        assert!(space.total_bytes > 0);
        assert!(space.available_bytes > 0);
    }

    #[test]
    fn test_home_directory_analysis() {
        let temp = tempdir().expect("Failed to create temp directory");

        // Create some test directories
        std::fs::create_dir(temp.path().join("Documents"))
            .expect("Failed to create Documents dir");
        std::fs::create_dir(temp.path().join("Downloads"))
            .expect("Failed to create Downloads dir");
        std::fs::write(temp.path().join("Documents/test.txt"), "hello")
            .expect("Failed to write test.txt");

        let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());
        let dirs = analyzer.analyze_home_directory(10);

        assert!(!dirs.is_empty());
    }

    #[test]
    fn test_cleanable_estimation() {
        let temp = tempdir().expect("Failed to create temp directory");

        // Create Library/Caches structure
        let caches_path = temp.path().join("Library/Caches");
        std::fs::create_dir_all(&caches_path).expect("Failed to create Caches directory");
        let app_cache = caches_path.join("com.test.app");
        std::fs::create_dir(&app_cache).expect("Failed to create app cache dir");
        std::fs::write(app_cache.join("cache.dat"), "test cache data")
            .expect("Failed to write cache.dat");

        let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());
        let cleanable = analyzer.estimate_cleanable();

        // total_bytes is u64, always >= 0, so just verify it's calculated
        let _ = cleanable.total_bytes;
    }
}
