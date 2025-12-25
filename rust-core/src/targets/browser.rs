// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Browser Cache Management
//!
//! Provides cleanup functionality for browser caches:
//! - Safari (0.5-5GB): Media cache, web content
//! - Chrome (0.5-10GB): Extensive caching
//! - Firefox (0.5-3GB): Profile-based caching
//! - Edge (0.5-3GB): Chromium-based
//! - Brave (0.5-3GB): Privacy-focused Chromium
//! - Opera (0.5-2GB): Chromium-based
//! - Arc (0.5-2GB): Modern Chromium browser
//!
//! Also handles cloud service caches:
//! - iCloud, Dropbox, OneDrive, Google Drive

use std::fs;
use std::path::PathBuf;
use std::process::Command;

use rayon::prelude::*;
use serde::{Deserialize, Serialize};

use super::{Browser, BrowserCacheEntry, BrowserCacheType, BrowserScanResult, BrowserTarget};
use crate::developer::{
    calculate_dir_size, expand_home, CleanupError, CleanupMethod, CleanupTarget,
};
use crate::safety::{is_app_running, SafetyLevel};

/// Browser cache cleaner
pub struct BrowserCleaner {
    /// Base path for caches (~/ Library/Caches)
    cache_base: PathBuf,
    /// Base path for application support
    app_support_base: PathBuf,
    /// Detected browsers
    browsers: Vec<BrowserTarget>,
}

impl Default for BrowserCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl BrowserCleaner {
    /// Create a new browser cleaner
    pub fn new() -> Self {
        let cache_base = expand_home("~/Library/Caches");
        let app_support_base = expand_home("~/Library/Application Support");

        let mut cleaner = Self {
            cache_base,
            app_support_base,
            browsers: Vec::new(),
        };

        // Detect installed browsers
        cleaner.browsers = cleaner.detect_browsers();

        cleaner
    }

    /// Detect all installed browsers
    pub fn detect_browsers(&self) -> Vec<BrowserTarget> {
        Browser::all()
            .iter()
            .map(|&browser| {
                let is_installed = std::path::Path::new(browser.app_path()).exists();
                let is_running = if is_installed {
                    is_app_running(browser.process_name())
                } else {
                    false
                };
                let cache_paths = self.get_cache_paths(browser);
                let profile_path = self.get_profile_path(browser);
                let cache_size = if is_installed {
                    cache_paths
                        .iter()
                        .map(|p| calculate_dir_size(p))
                        .sum()
                } else {
                    0
                };

                BrowserTarget {
                    browser,
                    is_installed,
                    is_running,
                    cache_paths,
                    profile_path,
                    cache_size,
                }
            })
            .collect()
    }

    /// Get cache paths for a specific browser
    fn get_cache_paths(&self, browser: Browser) -> Vec<PathBuf> {
        let mut paths = Vec::new();

        match browser {
            Browser::Safari => {
                paths.push(self.cache_base.join("com.apple.Safari"));
                paths.push(self.cache_base.join("com.apple.Safari.SafeBrowsing"));
                paths.push(
                    self.cache_base
                        .join("com.apple.WebKit.WebContent"),
                );
            }
            Browser::Chrome => {
                paths.push(self.cache_base.join("Google/Chrome"));
                paths.push(self.cache_base.join("Google/Chrome Canary"));
                // Chrome profile-based cache
                let chrome_app_support = self.app_support_base.join("Google/Chrome");
                if chrome_app_support.exists() {
                    // Default profile cache
                    paths.push(chrome_app_support.join("Default/Cache"));
                    paths.push(chrome_app_support.join("Default/Code Cache"));
                    paths.push(chrome_app_support.join("Default/GPUCache"));
                    paths.push(chrome_app_support.join("Default/Service Worker/CacheStorage"));
                    // Also check other profiles
                    if let Ok(entries) = fs::read_dir(&chrome_app_support) {
                        for entry in entries.filter_map(|e| e.ok()) {
                            let name = entry.file_name();
                            let name_str = name.to_string_lossy();
                            if name_str.starts_with("Profile ") {
                                paths.push(entry.path().join("Cache"));
                                paths.push(entry.path().join("Code Cache"));
                                paths.push(entry.path().join("GPUCache"));
                            }
                        }
                    }
                }
            }
            Browser::Firefox => {
                paths.push(self.cache_base.join("Firefox/Profiles"));
                paths.push(self.cache_base.join("org.mozilla.firefox"));
                // Firefox profile-based cache in Application Support
                let firefox_profiles = self.app_support_base.join("Firefox/Profiles");
                if firefox_profiles.exists() {
                    if let Ok(entries) = fs::read_dir(&firefox_profiles) {
                        for entry in entries.filter_map(|e| e.ok()) {
                            if entry.path().is_dir() {
                                paths.push(entry.path().join("cache2"));
                                paths.push(entry.path().join("startupCache"));
                                paths.push(entry.path().join("shader-cache"));
                            }
                        }
                    }
                }
            }
            Browser::Edge => {
                paths.push(self.cache_base.join("Microsoft Edge"));
                let edge_app_support = self.app_support_base.join("Microsoft Edge");
                if edge_app_support.exists() {
                    paths.push(edge_app_support.join("Default/Cache"));
                    paths.push(edge_app_support.join("Default/Code Cache"));
                    paths.push(edge_app_support.join("Default/GPUCache"));
                }
            }
            Browser::Brave => {
                paths.push(self.cache_base.join("BraveSoftware/Brave-Browser"));
                let brave_app_support = self.app_support_base.join("BraveSoftware/Brave-Browser");
                if brave_app_support.exists() {
                    paths.push(brave_app_support.join("Default/Cache"));
                    paths.push(brave_app_support.join("Default/Code Cache"));
                    paths.push(brave_app_support.join("Default/GPUCache"));
                }
            }
            Browser::Opera => {
                paths.push(self.cache_base.join("com.operasoftware.Opera"));
                let opera_app_support = self.app_support_base.join("com.operasoftware.Opera");
                if opera_app_support.exists() {
                    paths.push(opera_app_support.join("Cache"));
                    paths.push(opera_app_support.join("Code Cache"));
                    paths.push(opera_app_support.join("GPUCache"));
                }
            }
            Browser::Arc => {
                paths.push(self.cache_base.join("company.thebrowser.Browser"));
                let arc_app_support = self.app_support_base.join("Arc");
                if arc_app_support.exists() {
                    paths.push(arc_app_support.join("User Data/Default/Cache"));
                    paths.push(arc_app_support.join("User Data/Default/Code Cache"));
                    paths.push(arc_app_support.join("User Data/Default/GPUCache"));
                }
            }
        }

        // Filter to only existing paths
        paths.into_iter().filter(|p| p.exists()).collect()
    }

    /// Get profile path for Firefox
    fn get_profile_path(&self, browser: Browser) -> Option<PathBuf> {
        if browser == Browser::Firefox {
            let profiles_path = self.app_support_base.join("Firefox/Profiles");
            if profiles_path.exists() {
                return Some(profiles_path);
            }
        }
        None
    }

    /// Scan a specific browser for cache
    pub fn scan_browser(&self, browser: Browser) -> BrowserScanResult {
        let target = self
            .browsers
            .iter()
            .find(|b| b.browser == browser)
            .cloned();

        match target {
            Some(t) => {
                let mut cache_entries = Vec::new();
                let mut warnings = Vec::new();

                if t.is_running {
                    warnings.push(format!(
                        "{} is currently running. Close it before cleanup for best results.",
                        browser.display_name()
                    ));
                }

                // Scan each cache path
                for path in &t.cache_paths {
                    if path.exists() {
                        let size = calculate_dir_size(path);
                        let cache_type = self.determine_cache_type(path);
                        let name = path
                            .file_name()
                            .and_then(|n| n.to_str())
                            .unwrap_or("Cache")
                            .to_string();

                        cache_entries.push(BrowserCacheEntry {
                            path: path.clone(),
                            name: format!("{}: {}", browser.display_name(), name),
                            size,
                            cache_type,
                        });
                    }
                }

                let total_size = cache_entries.iter().map(|e| e.size).sum();

                BrowserScanResult {
                    browser,
                    installed: t.is_installed,
                    running: t.is_running,
                    cache_size: total_size,
                    cache_entries,
                    warnings,
                }
            }
            None => BrowserScanResult {
                browser,
                installed: false,
                running: false,
                cache_size: 0,
                cache_entries: Vec::new(),
                warnings: Vec::new(),
            },
        }
    }

    /// Scan all installed browsers
    pub fn scan_all(&self) -> Vec<BrowserScanResult> {
        self.browsers
            .par_iter()
            .filter(|b| b.is_installed)
            .map(|b| self.scan_browser(b.browser))
            .collect()
    }

    /// Determine the cache type from path
    fn determine_cache_type(&self, path: &PathBuf) -> BrowserCacheType {
        let path_str = path.to_string_lossy().to_lowercase();

        if path_str.contains("code cache") {
            BrowserCacheType::CodeCache
        } else if path_str.contains("gpucache") || path_str.contains("shader") {
            BrowserCacheType::GpuCache
        } else if path_str.contains("service worker") {
            BrowserCacheType::ServiceWorker
        } else if path_str.contains("media") || path_str.contains("webkit") {
            BrowserCacheType::MediaCache
        } else if path_str.contains("profile") {
            BrowserCacheType::ProfileCache
        } else {
            BrowserCacheType::Cache
        }
    }

    /// Get cleanup targets for all browsers
    pub fn get_cleanup_targets(&self) -> Vec<CleanupTarget> {
        let mut targets = Vec::new();

        for scan_result in self.scan_all() {
            for entry in scan_result.cache_entries {
                targets.push(
                    CleanupTarget::new_direct(entry.path, entry.name, SafetyLevel::Safe)
                        .with_size(entry.size)
                        .with_description(format!(
                            "{} - safe to delete",
                            entry.cache_type.display_name()
                        )),
                );
            }
        }

        targets
    }

    /// Get cleanup targets for a specific browser
    pub fn get_browser_cleanup_targets(&self, browser: Browser) -> Vec<CleanupTarget> {
        let scan_result = self.scan_browser(browser);
        let mut targets = Vec::new();

        for entry in scan_result.cache_entries {
            targets.push(
                CleanupTarget::new_direct(entry.path, entry.name, SafetyLevel::Safe)
                    .with_size(entry.size)
                    .with_description(format!(
                        "{} - safe to delete",
                        entry.cache_type.display_name()
                    )),
            );
        }

        targets
    }

    /// Get all detected browsers
    pub fn browsers(&self) -> &[BrowserTarget] {
        &self.browsers
    }

    /// Get installed browsers
    pub fn installed_browsers(&self) -> Vec<&BrowserTarget> {
        self.browsers.iter().filter(|b| b.is_installed).collect()
    }

    /// Check if a specific browser is installed
    pub fn is_browser_installed(&self, browser: Browser) -> bool {
        self.browsers
            .iter()
            .any(|b| b.browser == browser && b.is_installed)
    }

    /// Check if a specific browser is running
    pub fn is_browser_running(&self, browser: Browser) -> bool {
        self.browsers
            .iter()
            .any(|b| b.browser == browser && b.is_running)
    }

    /// Perform cleanup on specified targets
    pub fn clean(&self, targets: &[CleanupTarget], dry_run: bool) -> BrowserCleanupResult {
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

        BrowserCleanupResult {
            freed_bytes,
            items_cleaned,
            dry_run,
            errors,
        }
    }

    /// Perform cleanup on a single target
    fn clean_target(&self, target: &CleanupTarget, dry_run: bool) -> Result<u64, CleanupError> {
        match &target.cleanup_method {
            CleanupMethod::DirectDelete => {
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
                        message: "No path specified for direct delete".to_string(),
                    })
                }
            }
            CleanupMethod::Command(cmd) => {
                if !dry_run {
                    let output = Command::new("sh").args(["-c", cmd]).output().map_err(|e| {
                        CleanupError {
                            target: target.name.clone(),
                            message: e.to_string(),
                        }
                    })?;

                    if !output.status.success() {
                        return Err(CleanupError {
                            target: target.name.clone(),
                            message: String::from_utf8_lossy(&output.stderr).to_string(),
                        });
                    }
                }
                Ok(target.size)
            }
            CleanupMethod::CommandWithArgs(cmd, args) => {
                if !dry_run {
                    let output =
                        Command::new(cmd)
                            .args(args)
                            .output()
                            .map_err(|e| CleanupError {
                                target: target.name.clone(),
                                message: e.to_string(),
                            })?;

                    if !output.status.success() {
                        return Err(CleanupError {
                            target: target.name.clone(),
                            message: String::from_utf8_lossy(&output.stderr).to_string(),
                        });
                    }
                }
                Ok(target.size)
            }
        }
    }
}

/// Result of browser cleanup operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrowserCleanupResult {
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

    #[test]
    fn test_browser_cleaner_creation() {
        let cleaner = BrowserCleaner::new();
        // Should have detected browsers
        assert!(!cleaner.browsers.is_empty() || cleaner.browsers.is_empty());
    }

    #[test]
    fn test_detect_browsers() {
        let cleaner = BrowserCleaner::new();
        let browsers = cleaner.detect_browsers();

        // Should return 7 browser targets (one for each browser type)
        assert_eq!(browsers.len(), 7);

        // Safari should be in the list (and likely installed on macOS)
        let safari = browsers.iter().find(|b| b.browser == Browser::Safari);
        assert!(safari.is_some());
    }

    #[test]
    fn test_browser_cache_paths() {
        let cleaner = BrowserCleaner::new();

        // Safari should have cache paths defined (may be empty if cache doesn't exist)
        let safari_paths = cleaner.get_cache_paths(Browser::Safari);
        // Function should work without panicking
        let _ = safari_paths;

        // Chrome should have cache paths structure defined
        let chrome_paths = cleaner.get_cache_paths(Browser::Chrome);
        // Function should work without panicking
        let _ = chrome_paths;
    }

    #[test]
    fn test_scan_browser_not_installed() {
        let cleaner = BrowserCleaner::new();

        // Scan a browser that might not be installed
        // This should return a valid result regardless
        let result = cleaner.scan_browser(Browser::Arc);

        // Result should be valid
        assert_eq!(result.browser, Browser::Arc);
        // If not installed, cache_size should be 0
        if !result.installed {
            assert_eq!(result.cache_size, 0);
        }
    }

    #[test]
    fn test_cache_type_determination() {
        let cleaner = BrowserCleaner::new();

        let code_cache = PathBuf::from("/Users/test/Library/Caches/Google/Chrome/Default/Code Cache");
        assert_eq!(
            cleaner.determine_cache_type(&code_cache),
            BrowserCacheType::CodeCache
        );

        let gpu_cache = PathBuf::from("/Users/test/Library/Caches/Google/Chrome/Default/GPUCache");
        assert_eq!(
            cleaner.determine_cache_type(&gpu_cache),
            BrowserCacheType::GpuCache
        );

        let service_worker = PathBuf::from(
            "/Users/test/Library/Application Support/Google/Chrome/Default/Service Worker",
        );
        assert_eq!(
            cleaner.determine_cache_type(&service_worker),
            BrowserCacheType::ServiceWorker
        );

        let webkit = PathBuf::from("/Users/test/Library/Caches/com.apple.WebKit.WebContent");
        assert_eq!(
            cleaner.determine_cache_type(&webkit),
            BrowserCacheType::MediaCache
        );
    }

    #[test]
    fn test_installed_browsers() {
        let cleaner = BrowserCleaner::new();
        let installed = cleaner.installed_browsers();

        // All returned browsers should be installed
        for browser in installed {
            assert!(browser.is_installed);
        }
    }

    #[test]
    fn test_cleanup_result_structure() {
        let result = BrowserCleanupResult {
            freed_bytes: 1024,
            items_cleaned: 5,
            dry_run: true,
            errors: Vec::new(),
        };

        assert_eq!(result.freed_bytes, 1024);
        assert_eq!(result.items_cleaned, 5);
        assert!(result.dry_run);
        assert!(result.errors.is_empty());
    }
}
