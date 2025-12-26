// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Target-specific Cache Management Module
//!
//! Provides cleanup functionality for user-facing applications:
//! - Browsers (Safari, Chrome, Firefox, Edge, Brave, Opera, Arc)
//! - Cloud Services (iCloud, Dropbox, OneDrive, Google Drive)
//! - General Application Caches
//! - Logs and Crash Reports
//!
//! This module targets the most common cache accumulations affecting
//! all macOS users, potentially saving 5-30GB of disk space.

pub mod app_cache;
pub mod browser;
pub mod logs;

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

// Re-export main types for convenience
pub use app_cache::AppCacheCleaner;
pub use browser::BrowserCleaner;
pub use logs::{
    LogCleanupError, LogCleanupResult, LogCleaner, LogEntry, LogScanSummary, LogSource, LogType,
};

/// Supported browsers
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Browser {
    Safari,
    Chrome,
    Firefox,
    Edge,
    Brave,
    Opera,
    Arc,
}

impl Browser {
    /// Get the display name for this browser
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Safari => "Safari",
            Self::Chrome => "Google Chrome",
            Self::Firefox => "Firefox",
            Self::Edge => "Microsoft Edge",
            Self::Brave => "Brave",
            Self::Opera => "Opera",
            Self::Arc => "Arc",
        }
    }

    /// Get the bundle ID for this browser
    pub fn bundle_id(&self) -> &'static str {
        match self {
            Self::Safari => "com.apple.Safari",
            Self::Chrome => "com.google.Chrome",
            Self::Firefox => "org.mozilla.firefox",
            Self::Edge => "com.microsoft.edgemac",
            Self::Brave => "com.brave.Browser",
            Self::Opera => "com.operasoftware.Opera",
            Self::Arc => "company.thebrowser.Browser",
        }
    }

    /// Get the application path for this browser
    pub fn app_path(&self) -> &'static str {
        match self {
            Self::Safari => "/Applications/Safari.app",
            Self::Chrome => "/Applications/Google Chrome.app",
            Self::Firefox => "/Applications/Firefox.app",
            Self::Edge => "/Applications/Microsoft Edge.app",
            Self::Brave => "/Applications/Brave Browser.app",
            Self::Opera => "/Applications/Opera.app",
            Self::Arc => "/Applications/Arc.app",
        }
    }

    /// Get the process name for this browser
    pub fn process_name(&self) -> &'static str {
        match self {
            Self::Safari => "Safari",
            Self::Chrome => "Google Chrome",
            Self::Firefox => "firefox",
            Self::Edge => "Microsoft Edge",
            Self::Brave => "Brave Browser",
            Self::Opera => "Opera",
            Self::Arc => "Arc",
        }
    }

    /// Get all browser variants
    pub fn all() -> &'static [Browser] {
        &[
            Browser::Safari,
            Browser::Chrome,
            Browser::Firefox,
            Browser::Edge,
            Browser::Brave,
            Browser::Opera,
            Browser::Arc,
        ]
    }
}

/// Supported cloud services
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum CloudServiceType {
    ICloud,
    Dropbox,
    OneDrive,
    GoogleDrive,
}

impl CloudServiceType {
    /// Get the display name for this cloud service
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::ICloud => "iCloud",
            Self::Dropbox => "Dropbox",
            Self::OneDrive => "OneDrive",
            Self::GoogleDrive => "Google Drive",
        }
    }

    /// Get the bundle ID prefix for this cloud service
    pub fn bundle_id_prefix(&self) -> &'static str {
        match self {
            Self::ICloud => "com.apple.bird",
            Self::Dropbox => "com.getdropbox.dropbox",
            Self::OneDrive => "com.microsoft.OneDrive",
            Self::GoogleDrive => "com.google.GoogleDrive",
        }
    }

    /// Get all cloud service variants
    pub fn all() -> &'static [CloudServiceType] {
        &[
            CloudServiceType::ICloud,
            CloudServiceType::Dropbox,
            CloudServiceType::OneDrive,
            CloudServiceType::GoogleDrive,
        ]
    }
}

/// Information about a browser target
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrowserTarget {
    /// Browser type
    pub browser: Browser,
    /// Whether the browser is installed
    pub is_installed: bool,
    /// Whether the browser is currently running
    pub is_running: bool,
    /// Cache paths for this browser
    pub cache_paths: Vec<PathBuf>,
    /// Profile path (Firefox-specific)
    pub profile_path: Option<PathBuf>,
    /// Total cache size in bytes
    pub cache_size: u64,
}

/// Result of a browser scan
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrowserScanResult {
    /// Browser that was scanned
    pub browser: Browser,
    /// Whether the browser is installed
    pub installed: bool,
    /// Whether the browser is running
    pub running: bool,
    /// Total cache size
    pub cache_size: u64,
    /// Individual cache entries
    pub cache_entries: Vec<BrowserCacheEntry>,
    /// Warnings or errors
    pub warnings: Vec<String>,
}

/// Individual browser cache entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrowserCacheEntry {
    /// Path to the cache
    pub path: PathBuf,
    /// Display name
    pub name: String,
    /// Size in bytes
    pub size: u64,
    /// Type of cache
    pub cache_type: BrowserCacheType,
}

/// Types of browser caches
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BrowserCacheType {
    /// General browser cache
    Cache,
    /// Media cache (Safari-specific)
    MediaCache,
    /// Service worker cache
    ServiceWorker,
    /// Code cache
    CodeCache,
    /// GPU shader cache
    GpuCache,
    /// Profile-specific cache (Firefox)
    ProfileCache,
}

impl BrowserCacheType {
    /// Get the display name for this cache type
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Cache => "Browser Cache",
            Self::MediaCache => "Media Cache",
            Self::ServiceWorker => "Service Worker Cache",
            Self::CodeCache => "Code Cache",
            Self::GpuCache => "GPU Shader Cache",
            Self::ProfileCache => "Profile Cache",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_browser_display_names() {
        assert_eq!(Browser::Safari.display_name(), "Safari");
        assert_eq!(Browser::Chrome.display_name(), "Google Chrome");
        assert_eq!(Browser::Firefox.display_name(), "Firefox");
    }

    #[test]
    fn test_browser_bundle_ids() {
        assert_eq!(Browser::Safari.bundle_id(), "com.apple.Safari");
        assert_eq!(Browser::Chrome.bundle_id(), "com.google.Chrome");
    }

    #[test]
    fn test_cloud_service_display_names() {
        assert_eq!(CloudServiceType::ICloud.display_name(), "iCloud");
        assert_eq!(CloudServiceType::Dropbox.display_name(), "Dropbox");
    }

    #[test]
    fn test_browser_all() {
        let browsers = Browser::all();
        assert_eq!(browsers.len(), 7);
    }

    #[test]
    fn test_cloud_service_all() {
        let services = CloudServiceType::all();
        assert_eq!(services.len(), 4);
    }
}
