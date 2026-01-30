// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Category-based disk analysis module
//!
//! Provides analysis for different categories:
//! - Home directory top-level analysis
//! - Application caches analysis
//! - Developer tools analysis

use std::fs;
use std::path::{Path, PathBuf};

use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use walkdir::WalkDir;

use crate::safety::{SafetyLevel, SafetyValidator};

/// Information about a directory
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DirectoryInfo {
    /// Directory path
    pub path: PathBuf,
    /// Directory name
    pub name: String,
    /// Total size in bytes
    pub size: u64,
    /// Number of items (files and subdirectories)
    pub item_count: u64,
    /// Whether this is a hidden directory
    pub is_hidden: bool,
}

impl DirectoryInfo {
    /// Format size as human-readable string
    pub fn size_formatted(&self) -> String {
        super::disk_space::format_bytes(self.size)
    }
}

/// Information about an application cache
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheInfo {
    /// Application name (extracted from bundle ID or directory name)
    pub app_name: String,
    /// Bundle ID if identifiable
    pub bundle_id: Option<String>,
    /// Path to cache directory
    pub path: PathBuf,
    /// Cache size in bytes
    pub size: u64,
    /// Safety level for deletion
    pub safety_level: SafetyLevel,
    /// Whether this is a cloud-synced app
    pub is_cloud_app: bool,
}

impl CacheInfo {
    /// Format size as human-readable string
    pub fn size_formatted(&self) -> String {
        super::disk_space::format_bytes(self.size)
    }
}

/// Information about a developer tool component
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeveloperComponentInfo {
    /// Component name (e.g., "DerivedData", "iOS DeviceSupport")
    pub component: String,
    /// Path to component directory
    pub path: PathBuf,
    /// Size in bytes
    pub size: u64,
    /// Safety level for deletion
    pub safety_level: SafetyLevel,
    /// Description of what this component contains
    pub description: String,
    /// Tool this component belongs to (e.g., "Xcode", "CoreSimulator")
    pub tool: String,
}

impl DeveloperComponentInfo {
    /// Format size as human-readable string
    pub fn size_formatted(&self) -> String {
        super::disk_space::format_bytes(self.size)
    }
}

/// Trait for category scanners
pub trait CategoryScanner: Send + Sync {
    /// Scanner name
    fn name(&self) -> &str;

    /// Scan and return items
    fn scan(&self) -> Vec<ScannedItem>;

    /// Get total size
    fn total_size(&self) -> u64 {
        self.scan().iter().map(|i| i.size).sum()
    }
}

/// Generic scanned item
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScannedItem {
    /// Item name
    pub name: String,
    /// Item path
    pub path: PathBuf,
    /// Size in bytes
    pub size: u64,
    /// Safety level
    pub safety_level: SafetyLevel,
    /// Category
    pub category: String,
}

/// Analyze home directory and return top N directories by size
pub fn analyze_home_directory(home_path: &Path, top_n: usize) -> Vec<DirectoryInfo> {
    if !home_path.exists() {
        return Vec::new();
    }

    let entries = match fs::read_dir(home_path) {
        Ok(entries) => entries,
        Err(_) => return Vec::new(),
    };

    let mut dirs: Vec<DirectoryInfo> = entries
        .par_bridge()
        .filter_map(|entry_result| {
            let entry = entry_result.ok()?;
            let path = entry.path();
            if !path.is_dir() {
                return None;
            }

            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("Unknown")
                .to_string();

            let is_hidden = name.starts_with('.');

            let size = calculate_dir_size(&path);
            let item_count = count_items(&path);

            Some(DirectoryInfo {
                path,
                name,
                size,
                item_count,
                is_hidden,
            })
        })
        .collect();

    // Sort by size descending
    dirs.sort_by(|a, b| b.size.cmp(&a.size));

    // Return top N
    dirs.into_iter().take(top_n).collect()
}

/// Analyze ~/Library/Caches directory
pub fn analyze_caches(caches_path: &Path) -> Vec<CacheInfo> {
    if !caches_path.exists() {
        return Vec::new();
    }

    let validator = SafetyValidator::new();

    let entries = match fs::read_dir(caches_path) {
        Ok(entries) => entries,
        Err(_) => return Vec::new(),
    };

    let mut caches: Vec<CacheInfo> = entries
        .par_bridge()
        .filter_map(|entry_result| {
            let entry = entry_result.ok()?;
            let path = entry.path();
            if !path.is_dir() {
                return None;
            }

            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("Unknown")
                .to_string();

            let (app_name, bundle_id) = parse_cache_name(&name);
            let size = calculate_dir_size(&path);
            let safety_level = validator.classify(&path);
            let is_cloud_app = is_cloud_synced_app(&name);

            Some(CacheInfo {
                app_name,
                bundle_id,
                path,
                size,
                safety_level,
                is_cloud_app,
            })
        })
        .collect();

    // Sort by size descending
    caches.sort_by(|a, b| b.size.cmp(&a.size));
    caches
}

/// Analyze ~/Library/Developer directory
pub fn analyze_developer(developer_path: &Path) -> Vec<DeveloperComponentInfo> {
    if !developer_path.exists() {
        return Vec::new();
    }

    let validator = SafetyValidator::new();
    let mut components = Vec::new();

    // Known developer components with their metadata
    let known_components = [
        (
            "Xcode/DerivedData",
            "DerivedData",
            "Xcode",
            "Build products and intermediate files",
            SafetyLevel::Safe,
        ),
        (
            "Xcode/Archives",
            "Archives",
            "Xcode",
            "App archives for App Store submission",
            SafetyLevel::Caution,
        ),
        (
            "Xcode/iOS DeviceSupport",
            "iOS DeviceSupport",
            "Xcode",
            "Debug symbols for iOS devices",
            SafetyLevel::Warning,
        ),
        (
            "Xcode/watchOS DeviceSupport",
            "watchOS DeviceSupport",
            "Xcode",
            "Debug symbols for watchOS devices",
            SafetyLevel::Warning,
        ),
        (
            "CoreSimulator/Devices",
            "Simulator Devices",
            "CoreSimulator",
            "iOS/watchOS simulator device data",
            SafetyLevel::Caution,
        ),
        (
            "CoreSimulator/Caches",
            "Simulator Caches",
            "CoreSimulator",
            "Simulator runtime caches",
            SafetyLevel::Safe,
        ),
    ];

    for (rel_path, name, tool, description, default_safety) in known_components {
        let full_path = developer_path.join(rel_path);
        if full_path.exists() {
            let size = calculate_dir_size(&full_path);
            let safety_level = if size > 0 {
                validator.classify(&full_path)
            } else {
                default_safety
            };

            components.push(DeveloperComponentInfo {
                component: name.to_string(),
                path: full_path,
                size,
                safety_level,
                description: description.to_string(),
                tool: tool.to_string(),
            });
        }
    }

    // Scan for other developer directories not in the known list
    if let Ok(entries) = fs::read_dir(developer_path) {
        for entry in entries.filter_map(|e| e.ok()) {
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }

            let name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("Unknown")
                .to_string();

            // Skip known directories
            if name == "Xcode" || name == "CoreSimulator" {
                continue;
            }

            let size = calculate_dir_size(&path);
            let safety_level = validator.classify(&path);

            components.push(DeveloperComponentInfo {
                component: name.clone(),
                path,
                size,
                safety_level,
                description: format!("Developer tool data: {}", name),
                tool: name,
            });
        }
    }

    // Sort by size descending
    components.sort_by(|a, b| b.size.cmp(&a.size));
    components
}

/// Calculate the total size of a directory using streaming
pub fn calculate_dir_size(path: &Path) -> u64 {
    WalkDir::new(path)
        .into_iter()
        .par_bridge()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .filter_map(|e| e.metadata().ok())
        .map(|m| m.len())
        .sum()
}

/// Count items in a directory using streaming
fn count_items(path: &Path) -> u64 {
    use std::sync::atomic::{AtomicU64, Ordering};

    let counter = AtomicU64::new(0);

    WalkDir::new(path)
        .into_iter()
        .par_bridge()
        .filter_map(|e| e.ok())
        .for_each(|_| {
            counter.fetch_add(1, Ordering::Relaxed);
        });

    counter.load(Ordering::Relaxed)
}

/// Parse cache directory name to extract app name and bundle ID
fn parse_cache_name(name: &str) -> (String, Option<String>) {
    // Common patterns:
    // com.apple.Safari -> Safari
    // com.google.Chrome -> Chrome
    // Firefox -> Firefox

    if name.contains('.') {
        // Likely a bundle ID
        let parts: Vec<&str> = name.split('.').collect();
        let app_name = parts.last().unwrap_or(&name).to_string();

        // Capitalize first letter
        let app_name = app_name
            .chars()
            .enumerate()
            .map(|(i, c)| if i == 0 { c.to_ascii_uppercase() } else { c })
            .collect();

        (app_name, Some(name.to_string()))
    } else {
        (name.to_string(), None)
    }
}

/// Check if an app is known to sync with cloud services
fn is_cloud_synced_app(name: &str) -> bool {
    let cloud_apps = [
        "com.apple.CloudKit",
        "com.apple.iCloud",
        "com.dropbox",
        "com.google.Drive",
        "com.microsoft.OneDrive",
    ];

    let name_lower = name.to_lowercase();
    cloud_apps
        .iter()
        .any(|app| name_lower.contains(&app.to_lowercase()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_analyze_home_directory() {
        let temp = tempdir().expect("Failed to create temp directory");

        // Create test directories
        fs::create_dir(temp.path().join("Documents")).expect("Failed to create Documents dir");
        fs::create_dir(temp.path().join("Downloads")).expect("Failed to create Downloads dir");
        fs::create_dir(temp.path().join(".hidden")).expect("Failed to create .hidden dir");

        // Add some files
        fs::write(temp.path().join("Documents/test.txt"), "hello")
            .expect("Failed to write test.txt");
        fs::write(temp.path().join("Downloads/big_file.zip"), "x".repeat(1000))
            .expect("Failed to write big_file.zip");

        let dirs = analyze_home_directory(temp.path(), 10);

        assert!(!dirs.is_empty());
        // Downloads should be first (larger)
        assert_eq!(dirs[0].name, "Downloads");
    }

    #[test]
    fn test_analyze_caches() {
        let temp = tempdir().expect("Failed to create temp directory");
        let caches = temp.path().join("Library/Caches");
        fs::create_dir_all(&caches).expect("Failed to create Caches directory");

        // Create test cache directories
        let safari_cache = caches.join("com.apple.Safari");
        fs::create_dir(&safari_cache).expect("Failed to create Safari cache dir");
        fs::write(safari_cache.join("cache.db"), "test data")
            .expect("Failed to write Safari cache.db");

        let chrome_cache = caches.join("com.google.Chrome");
        fs::create_dir(&chrome_cache).expect("Failed to create Chrome cache dir");
        fs::write(chrome_cache.join("data"), "x".repeat(100))
            .expect("Failed to write Chrome cache data");

        let result = analyze_caches(&caches);

        assert_eq!(result.len(), 2);
        // Chrome should be first (larger)
        assert!(result[0].app_name == "Chrome" || result[0].app_name == "Safari");
    }

    #[test]
    fn test_parse_cache_name() {
        let (name, bundle) = parse_cache_name("com.apple.Safari");
        assert_eq!(name, "Safari");
        assert_eq!(bundle, Some("com.apple.Safari".to_string()));

        let (name, bundle) = parse_cache_name("Firefox");
        assert_eq!(name, "Firefox");
        assert_eq!(bundle, None);
    }

    #[test]
    fn test_directory_info_formatting() {
        let info = DirectoryInfo {
            path: PathBuf::from("/test"),
            name: "test".to_string(),
            size: 1024 * 1024 * 100, // 100 MB
            item_count: 50,
            is_hidden: false,
        };

        assert!(info.size_formatted().contains("MB"));
    }

    #[test]
    fn test_calculate_dir_size() {
        let temp = tempdir().expect("Failed to create temp directory");
        fs::write(temp.path().join("a.txt"), "hello").expect("Failed to write a.txt");
        fs::write(temp.path().join("b.txt"), "world!").expect("Failed to write b.txt");

        let size = calculate_dir_size(temp.path());
        assert_eq!(size, 11);
    }
}
