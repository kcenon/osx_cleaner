// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Application Cache Management
//!
//! Provides cleanup functionality for general application caches:
//! - ~/Library/Caches - Application caches
//! - Cloud service caches (iCloud, Dropbox, OneDrive, Google Drive)
//!
//! This module scans all application caches and provides
//! intelligent cleanup options based on size and safety.

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::RwLock;
use std::time::{Duration, Instant};

use rayon::prelude::*;
use serde::{Deserialize, Serialize};

use super::CloudServiceType;
use crate::developer::{calculate_dir_size, expand_home, CleanupError, CleanupTarget};
use crate::safety::{is_app_running, SafetyLevel, SyncStatus};

/// Default exclusions - apps whose caches should not be cleaned
const DEFAULT_EXCLUSIONS: &[&str] = &[
    // System critical
    "com.apple.LaunchServices",
    "com.apple.iconservices",
    "com.apple.nsservicescache",
    "com.apple.Spotlight",
    "com.apple.preferences",
    "com.apple.DiskUtility",
    "com.apple.finder",
    // Security related
    "com.apple.security",
    "com.apple.keychain",
    "com.apple.trustd",
    // Currently managed by other modules
    "com.apple.Safari",
    "Google",
    "Firefox",
    "Microsoft Edge",
    "BraveSoftware",
    "com.operasoftware",
    "company.thebrowser",
];

/// Cloud service bundle ID patterns
const CLOUD_SERVICE_PATTERNS: &[(&str, CloudServiceType)] = &[
    ("com.apple.bird", CloudServiceType::ICloud),
    ("com.apple.CloudKit", CloudServiceType::ICloud),
    ("com.getdropbox", CloudServiceType::Dropbox),
    ("com.microsoft.OneDrive", CloudServiceType::OneDrive),
    ("com.google.GoogleDrive", CloudServiceType::GoogleDrive),
];

/// Cache entry for mdfind results
struct CacheEntry {
    /// Cached app name (None if lookup failed)
    value: Option<String>,
    /// When this entry expires
    expires_at: Instant,
}

/// Thread-safe cache for app name lookups
struct AppNameCache {
    /// Cache storage
    cache: RwLock<HashMap<String, CacheEntry>>,
    /// Time-to-live for cache entries
    ttl: Duration,
}

impl AppNameCache {
    /// Create a new cache with specified TTL
    fn new(ttl: Duration) -> Self {
        Self {
            cache: RwLock::new(HashMap::new()),
            ttl,
        }
    }

    /// Get app name from cache or perform lookup
    fn get_or_lookup(&self, bundle_id: &str) -> Option<String> {
        // Check cache first (read lock)
        {
            match self.cache.read() {
                Ok(cache) => {
                    if let Some(entry) = cache.get(bundle_id) {
                        if entry.expires_at > Instant::now() {
                            return entry.value.clone();
                        }
                    }
                }
                Err(poisoned) => {
                    log::warn!("Cache read lock poisoned, recovering: {}", poisoned);
                    // Recover from poison and continue
                    let cache = poisoned.into_inner();
                    if let Some(entry) = cache.get(bundle_id) {
                        if entry.expires_at > Instant::now() {
                            return entry.value.clone();
                        }
                    }
                }
            }
        }

        // Cache miss - perform lookup
        let result = self.lookup_app_name(bundle_id);

        // Store in cache (write lock)
        {
            match self.cache.write() {
                Ok(mut cache) => {
                    cache.insert(
                        bundle_id.to_string(),
                        CacheEntry {
                            value: result.clone(),
                            expires_at: Instant::now() + self.ttl,
                        },
                    );
                }
                Err(poisoned) => {
                    log::warn!("Cache write lock poisoned, recovering: {}", poisoned);
                    // Recover from poison and continue
                    let mut cache = poisoned.into_inner();
                    cache.insert(
                        bundle_id.to_string(),
                        CacheEntry {
                            value: result.clone(),
                            expires_at: Instant::now() + self.ttl,
                        },
                    );
                }
            }
        }

        result
    }

    /// Perform actual mdfind lookup
    fn lookup_app_name(&self, bundle_id: &str) -> Option<String> {
        // Try to get the app name using mdfind
        if let Ok(output) = Command::new("mdfind")
            .args(["kMDItemCFBundleIdentifier", "==", bundle_id])
            .output()
        {
            if output.status.success() {
                let path_str = String::from_utf8_lossy(&output.stdout);
                if let Some(path) = path_str.trim().lines().next() {
                    // Extract app name from path (e.g., /Applications/Foo.app -> Foo)
                    if let Some(app_name) = std::path::Path::new(path)
                        .file_stem()
                        .and_then(|s| s.to_str())
                        .map(|s| s.trim_end_matches(".app").to_string())
                    {
                        if !app_name.is_empty() {
                            return Some(app_name);
                        }
                    }
                }
            }
        }

        // Fallback: parse bundle ID
        // e.g., com.apple.Preview -> Preview
        //       com.spotify.client -> Spotify
        bundle_id.split('.').next_back().map(|s| {
            let mut chars = s.chars();
            match chars.next() {
                None => String::new(),
                Some(c) => c.to_uppercase().collect::<String>() + chars.as_str(),
            }
        })
    }

    /// Clear expired cache entries
    #[allow(dead_code)]
    fn clear_expired(&self) {
        match self.cache.write() {
            Ok(mut cache) => {
                let now = Instant::now();
                cache.retain(|_, entry| entry.expires_at > now);
            }
            Err(poisoned) => {
                log::warn!("Cache write lock poisoned while clearing, recovering: {}", poisoned);
                let mut cache = poisoned.into_inner();
                let now = Instant::now();
                cache.retain(|_, entry| entry.expires_at > now);
            }
        }
    }
}

/// Application cache cleaner
pub struct AppCacheCleaner {
    /// Base path for caches
    cache_base: PathBuf,
    /// Exclusions - bundle IDs or prefixes to skip
    exclusions: HashSet<String>,
    /// Whether to include cloud service caches
    include_cloud_caches: bool,
    /// Cache for app name lookups
    app_name_cache: AppNameCache,
}

impl Default for AppCacheCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl AppCacheCleaner {
    /// Create a new app cache cleaner
    pub fn new() -> Self {
        let exclusions = DEFAULT_EXCLUSIONS.iter().map(|s| s.to_string()).collect();

        Self {
            cache_base: expand_home("~/Library/Caches"),
            exclusions,
            include_cloud_caches: true,
            app_name_cache: AppNameCache::new(Duration::from_secs(300)), // 5 minutes TTL
        }
    }

    /// Create a new app cache cleaner with custom exclusions
    pub fn with_exclusions(exclusions: Vec<String>) -> Self {
        let mut all_exclusions: HashSet<String> =
            DEFAULT_EXCLUSIONS.iter().map(|s| s.to_string()).collect();
        all_exclusions.extend(exclusions);

        Self {
            cache_base: expand_home("~/Library/Caches"),
            exclusions: all_exclusions,
            include_cloud_caches: true,
            app_name_cache: AppNameCache::new(Duration::from_secs(300)), // 5 minutes TTL
        }
    }

    /// Set whether to include cloud service caches
    pub fn set_include_cloud_caches(&mut self, include: bool) {
        self.include_cloud_caches = include;
    }

    /// Check if a bundle ID should be excluded
    fn is_excluded(&self, bundle_id: &str) -> bool {
        for exclusion in &self.exclusions {
            if bundle_id.starts_with(exclusion) || bundle_id.contains(exclusion) {
                return true;
            }
        }
        false
    }

    /// Identify if a cache belongs to a cloud service
    fn identify_cloud_service(&self, bundle_id: &str) -> Option<CloudServiceType> {
        for (pattern, service) in CLOUD_SERVICE_PATTERNS {
            if bundle_id.starts_with(pattern) || bundle_id.contains(pattern) {
                return Some(*service);
            }
        }
        None
    }

    /// Scan all application caches
    pub fn scan_all_caches(&self) -> Vec<AppCacheEntry> {
        if !self.cache_base.exists() {
            return Vec::new();
        }

        let entries: Vec<_> = match fs::read_dir(&self.cache_base) {
            Ok(entries) => entries.filter_map(|e| e.ok()).collect(),
            Err(_) => return Vec::new(),
        };

        entries
            .par_iter()
            .filter_map(|entry| {
                let path = entry.path();
                if !path.is_dir() {
                    return None;
                }

                let bundle_id = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("")
                    .to_string();

                // Skip excluded apps
                if self.is_excluded(&bundle_id) {
                    return None;
                }

                // Check for cloud service
                let cloud_service = self.identify_cloud_service(&bundle_id);
                if cloud_service.is_some() && !self.include_cloud_caches {
                    return None;
                }

                let size = calculate_dir_size(&path);
                if size == 0 {
                    return None;
                }

                // Determine safety level based on cloud status
                let (safety_level, sync_warning) = if let Some(service) = cloud_service {
                    let sync_status = self.check_cloud_sync_status(&path, service);
                    match sync_status {
                        SyncStatus::Syncing => (
                            SafetyLevel::Warning,
                            Some(format!(
                                "{} is currently syncing - wait for completion",
                                service.display_name()
                            )),
                        ),
                        SyncStatus::Pending => (
                            SafetyLevel::Caution,
                            Some(format!("{} has pending sync items", service.display_name())),
                        ),
                        SyncStatus::CloudOnly => (
                            SafetyLevel::Warning,
                            Some(format!(
                                "{} file only exists in cloud",
                                service.display_name()
                            )),
                        ),
                        SyncStatus::LocalOnly => (
                            SafetyLevel::Caution,
                            Some(format!(
                                "{} file not yet synced to cloud",
                                service.display_name()
                            )),
                        ),
                        SyncStatus::Error => (
                            SafetyLevel::Caution,
                            Some(format!("{} sync error detected", service.display_name())),
                        ),
                        SyncStatus::Synced | SyncStatus::NotApplicable => (SafetyLevel::Safe, None),
                    }
                } else {
                    (SafetyLevel::Safe, None)
                };

                // Get app name from bundle ID
                let app_name = self.get_app_name(&bundle_id).unwrap_or(bundle_id.clone());

                // Check if related app is running
                let is_running = self.is_related_app_running(&bundle_id);

                Some(AppCacheEntry {
                    path,
                    bundle_id,
                    app_name,
                    size,
                    safety_level,
                    cloud_service,
                    sync_warning,
                    is_app_running: is_running,
                })
            })
            .collect()
    }

    /// Get top N caches by size
    pub fn get_top_caches(&self, n: usize) -> Vec<AppCacheEntry> {
        let mut caches = self.scan_all_caches();
        caches.sort_by(|a, b| b.size.cmp(&a.size));
        caches.into_iter().take(n).collect()
    }

    /// Get total cache size
    pub fn get_total_cache_size(&self) -> u64 {
        self.scan_all_caches().iter().map(|e| e.size).sum()
    }

    /// Get app name from bundle ID (cached)
    fn get_app_name(&self, bundle_id: &str) -> Option<String> {
        self.app_name_cache.get_or_lookup(bundle_id)
    }

    /// Check if the related app is running
    fn is_related_app_running(&self, bundle_id: &str) -> bool {
        // Get app name from bundle ID and check if it's running
        if let Some(app_name) = self.get_app_name(bundle_id) {
            return is_app_running(&app_name);
        }

        // Try common process name patterns
        let process_patterns = [
            bundle_id.to_string(),
            bundle_id.split('.').next_back().unwrap_or("").to_string(),
        ];

        for pattern in process_patterns {
            if !pattern.is_empty() && is_app_running(&pattern) {
                return true;
            }
        }

        false
    }

    /// Check cloud sync status for a cache directory
    fn check_cloud_sync_status(&self, path: &Path, service: CloudServiceType) -> SyncStatus {
        use crate::safety::cloud::{
            get_dropbox_status, get_google_drive_status, get_icloud_status, get_onedrive_status,
        };

        // Use the safety module's cloud sync detection
        match service {
            CloudServiceType::ICloud => {
                // Check iCloud sync status using brctl
                get_icloud_status(path).unwrap_or_else(|| {
                    // Fallback to legacy brctl check
                    let output = Command::new("brctl").args(["status"]).output();
                    match output {
                        Ok(o) if o.status.success() => {
                            let status = String::from_utf8_lossy(&o.stdout);
                            if status.contains("syncing") {
                                SyncStatus::Syncing
                            } else if status.contains("pending") {
                                SyncStatus::Pending
                            } else {
                                SyncStatus::Synced
                            }
                        }
                        _ => SyncStatus::NotApplicable,
                    }
                })
            }
            CloudServiceType::Dropbox => {
                // Implement proper Dropbox sync detection
                get_dropbox_status(path).unwrap_or_else(|| {
                    // Fallback: check if app is running
                    if is_app_running("Dropbox") {
                        SyncStatus::Synced
                    } else {
                        SyncStatus::NotApplicable
                    }
                })
            }
            CloudServiceType::OneDrive => {
                // Implement proper OneDrive sync detection
                get_onedrive_status(path).unwrap_or_else(|| {
                    // Fallback: check if app is running
                    if is_app_running("OneDrive") {
                        SyncStatus::Synced
                    } else {
                        SyncStatus::NotApplicable
                    }
                })
            }
            CloudServiceType::GoogleDrive => {
                // Implement proper Google Drive sync detection
                get_google_drive_status(path).unwrap_or_else(|| {
                    // Fallback: check if app is running
                    if is_app_running("Google Drive") {
                        SyncStatus::Synced
                    } else {
                        SyncStatus::NotApplicable
                    }
                })
            }
        }
    }

    /// Get cleanup targets for all scannable caches
    pub fn get_cleanup_targets(&self) -> Vec<CleanupTarget> {
        self.scan_all_caches()
            .into_iter()
            .map(|entry| entry.to_cleanup_target(true))
            .collect()
    }

    /// Get cleanup targets for specific bundle IDs
    pub fn get_cleanup_targets_for(&self, bundle_ids: &[&str]) -> Vec<CleanupTarget> {
        let caches = self.scan_all_caches();
        let bundle_set: HashSet<&str> = bundle_ids.iter().copied().collect();

        caches
            .into_iter()
            .filter(|e| bundle_set.contains(e.bundle_id.as_str()))
            .map(|entry| entry.to_cleanup_target(false))
            .collect()
    }

    /// Perform cleanup on specified targets
    pub fn clean(&self, targets: &[CleanupTarget], dry_run: bool) -> AppCacheCleanupResult {
        let mut freed_bytes = 0u64;
        let mut items_cleaned = 0usize;
        let mut errors = Vec::new();

        for target in targets {
            match self.clean_target(target, dry_run) {
                Ok(size) => {
                    freed_bytes += size;
                    items_cleaned += 1;
                    log::info!(
                        "{}Cleaned: {} ({} bytes)",
                        if dry_run { "[DRY RUN] " } else { "" },
                        target.name,
                        size
                    );
                }
                Err(e) => {
                    log::warn!("Failed to clean {}: {}", target.name, e.message);
                    errors.push(e);
                }
            }
        }

        AppCacheCleanupResult {
            freed_bytes,
            items_cleaned,
            dry_run,
            errors,
        }
    }

    /// Perform cleanup on a single target
    fn clean_target(&self, target: &CleanupTarget, dry_run: bool) -> Result<u64, CleanupError> {
        if let Some(path) = &target.path {
            if !dry_run {
                if path.is_dir() {
                    fs::remove_dir_all(path).map_err(|e| CleanupError {
                        target: target.name.clone(),
                        message: e.to_string(),
                    })?;
                } else {
                    fs::remove_file(path).map_err(|e| CleanupError {
                        target: target.name.clone(),
                        message: e.to_string(),
                    })?;
                }
            }
            Ok(target.size)
        } else {
            Err(CleanupError {
                target: target.name.clone(),
                message: "No path specified for cleanup".to_string(),
            })
        }
    }
}

/// Information about an application cache entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppCacheEntry {
    /// Path to the cache directory
    pub path: PathBuf,
    /// Bundle ID
    pub bundle_id: String,
    /// Resolved app name
    pub app_name: String,
    /// Size in bytes
    pub size: u64,
    /// Safety level
    pub safety_level: SafetyLevel,
    /// Cloud service type if applicable
    pub cloud_service: Option<CloudServiceType>,
    /// Sync warning if applicable
    pub sync_warning: Option<String>,
    /// Whether the related app is running
    pub is_app_running: bool,
}

impl AppCacheEntry {
    /// Convert AppCacheEntry to CleanupTarget
    ///
    /// Creates a CleanupTarget with the appropriate name, size, and safety level.
    /// Optionally includes additional description based on app running status
    /// and sync warnings.
    ///
    /// # Arguments
    ///
    /// * `include_details` - Whether to include detailed description
    ///
    /// # Returns
    ///
    /// A CleanupTarget configured for this cache entry
    pub fn to_cleanup_target(&self, include_details: bool) -> CleanupTarget {
        let mut target = CleanupTarget::new_direct(
            self.path.clone(),
            format!("{} Cache", self.app_name),
            self.safety_level,
        )
        .with_size(self.size);

        if include_details {
            let mut desc = format!("Application cache for {}", self.app_name);
            if self.is_app_running {
                desc.push_str(" (app is running)");
            }
            if let Some(warning) = &self.sync_warning {
                desc.push_str(&format!(" - Warning: {}", warning));
            }
            target = target.with_description(desc);
        } else {
            target = target.with_description(format!("Application cache for {}", self.app_name));
        }

        target
    }
}

/// Result of app cache cleanup operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppCacheCleanupResult {
    /// Space freed in bytes
    pub freed_bytes: u64,
    /// Number of items cleaned
    pub items_cleaned: usize,
    /// Whether this was a dry run
    pub dry_run: bool,
    /// Errors encountered during cleanup
    pub errors: Vec<CleanupError>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_app_cache_cleaner_creation() {
        let cleaner = AppCacheCleaner::new();
        assert!(!cleaner.exclusions.is_empty());
    }

    #[test]
    fn test_default_exclusions() {
        let cleaner = AppCacheCleaner::new();

        // System caches should be excluded
        assert!(cleaner.is_excluded("com.apple.LaunchServices"));
        assert!(cleaner.is_excluded("com.apple.Spotlight"));

        // Browser caches should be excluded (handled by browser module)
        assert!(cleaner.is_excluded("com.apple.Safari"));
        assert!(cleaner.is_excluded("Google"));
    }

    #[test]
    fn test_custom_exclusions() {
        let cleaner = AppCacheCleaner::with_exclusions(vec!["com.example.myapp".to_string()]);

        assert!(cleaner.is_excluded("com.example.myapp"));
        // Default exclusions should still apply
        assert!(cleaner.is_excluded("com.apple.LaunchServices"));
    }

    #[test]
    fn test_cloud_service_identification() {
        let cleaner = AppCacheCleaner::new();

        assert_eq!(
            cleaner.identify_cloud_service("com.apple.bird"),
            Some(CloudServiceType::ICloud)
        );
        assert_eq!(
            cleaner.identify_cloud_service("com.getdropbox.dropbox"),
            Some(CloudServiceType::Dropbox)
        );
        assert_eq!(
            cleaner.identify_cloud_service("com.microsoft.OneDrive"),
            Some(CloudServiceType::OneDrive)
        );
        assert_eq!(
            cleaner.identify_cloud_service("com.example.normalapp"),
            None
        );
    }

    #[test]
    fn test_app_name_parsing() {
        let cleaner = AppCacheCleaner::new();

        // Test fallback parsing
        let name = cleaner.get_app_name("com.spotify.client");
        assert!(name.is_some());
        // Should capitalize first letter
        if let Some(n) = name {
            assert!(n.starts_with(|c: char| c.is_uppercase()));
        }
    }

    #[test]
    fn test_cleanup_result_structure() {
        let result = AppCacheCleanupResult {
            freed_bytes: 2048,
            items_cleaned: 3,
            dry_run: false,
            errors: Vec::new(),
        };

        assert_eq!(result.freed_bytes, 2048);
        assert_eq!(result.items_cleaned, 3);
        assert!(!result.dry_run);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_include_cloud_caches_toggle() {
        let mut cleaner = AppCacheCleaner::new();
        assert!(cleaner.include_cloud_caches);

        cleaner.set_include_cloud_caches(false);
        assert!(!cleaner.include_cloud_caches);
    }

    #[test]
    fn test_scan_handles_empty_cache_dir() {
        let temp = tempdir().unwrap();
        let cleaner = AppCacheCleaner {
            cache_base: temp.path().to_path_buf(),
            exclusions: HashSet::new(),
            include_cloud_caches: true,
            app_name_cache: AppNameCache::new(Duration::from_secs(300)),
        };

        // Should return empty vec, not panic
        let caches = cleaner.scan_all_caches();
        assert!(caches.is_empty());
    }

    #[test]
    fn test_get_top_caches() {
        let cleaner = AppCacheCleaner::new();

        // Just verify it doesn't panic
        let top = cleaner.get_top_caches(10);
        // Result depends on actual system state
        assert!(top.len() <= 10);
    }

    #[test]
    fn test_app_cache_entry_to_cleanup_target_with_details() {
        let entry = AppCacheEntry {
            path: PathBuf::from("/tmp/test"),
            bundle_id: "com.example.app".to_string(),
            app_name: "Example App".to_string(),
            size: 1024,
            safety_level: SafetyLevel::Safe,
            cloud_service: None,
            sync_warning: Some("Test warning".to_string()),
            is_app_running: true,
        };

        let target = entry.to_cleanup_target(true);

        assert_eq!(target.name, "Example App Cache");
        assert_eq!(target.size, 1024);
        assert_eq!(target.safety_level, SafetyLevel::Safe);
        assert!(target.description.is_some());

        let desc = target.description.unwrap();
        assert!(desc.contains("Application cache for Example App"));
        assert!(desc.contains("app is running"));
        assert!(desc.contains("Warning: Test warning"));
    }

    #[test]
    fn test_app_cache_entry_to_cleanup_target_without_details() {
        let entry = AppCacheEntry {
            path: PathBuf::from("/tmp/test"),
            bundle_id: "com.example.app".to_string(),
            app_name: "Example App".to_string(),
            size: 2048,
            safety_level: SafetyLevel::Caution,
            cloud_service: None,
            sync_warning: Some("Test warning".to_string()),
            is_app_running: true,
        };

        let target = entry.to_cleanup_target(false);

        assert_eq!(target.name, "Example App Cache");
        assert_eq!(target.size, 2048);
        assert_eq!(target.safety_level, SafetyLevel::Caution);
        assert!(target.description.is_some());

        let desc = target.description.unwrap();
        assert_eq!(desc, "Application cache for Example App");
        // Should not contain detailed info when include_details is false
        assert!(!desc.contains("app is running"));
        assert!(!desc.contains("Warning:"));
    }

    #[test]
    fn test_app_cache_entry_to_cleanup_target_minimal() {
        let entry = AppCacheEntry {
            path: PathBuf::from("/tmp/test"),
            bundle_id: "com.example.minimal".to_string(),
            app_name: "Minimal".to_string(),
            size: 512,
            safety_level: SafetyLevel::Safe,
            cloud_service: None,
            sync_warning: None,
            is_app_running: false,
        };

        let target = entry.to_cleanup_target(true);

        assert_eq!(target.name, "Minimal Cache");
        assert_eq!(target.size, 512);
        assert!(target.description.is_some());

        let desc = target.description.unwrap();
        assert_eq!(desc, "Application cache for Minimal");
    }
}
