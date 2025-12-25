// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Path definitions for safety classification
//!
//! Defines protected paths (DANGER) and warning paths (WARNING) that require
//! special handling during cleanup operations.

use std::path::{Path, PathBuf};

/// Protected paths that should NEVER be deleted (DANGER level)
///
/// These paths are critical system files or user data that could cause
/// system instability or data loss if deleted.
pub const PROTECTED_PATHS: &[&str] = &[
    // System directories
    "/System",
    "/usr/bin",
    "/usr/sbin",
    "/usr/lib",
    "/usr/libexec",
    "/bin",
    "/sbin",
    "/private/var/db",
    "/private/var/folders",
    "/Library/Extensions",
    "/Library/Frameworks",
    // User critical data (will be expanded with home dir)
    "Library/Keychains",
    "Library/Application Support",
    "Library/Mail",
    "Library/Messages",
    "Library/Preferences",
    "Library/Accounts",
    "Library/Cookies",
    "Library/Calendars",
    "Library/Contacts",
    "Library/Safari/Bookmarks.plist",
    "Library/Safari/History.db",
    // Documents and user files
    "Documents",
    "Desktop",
    "Pictures",
    "Movies",
    "Music",
    "Downloads",
];

/// Warning paths that require user confirmation before deletion (WARNING level)
///
/// These paths contain data that may take significant time to re-download
/// or rebuild, but won't cause system instability if deleted.
pub const WARNING_PATHS: &[&str] = &[
    // Container data
    "Library/Containers",
    "Library/Group Containers",
    // System caches
    "/Library/Caches",
    // Developer tools requiring re-download
    "Library/Developer/Xcode/iOS DeviceSupport",
    "Library/Developer/Xcode/watchOS DeviceSupport",
    "Library/Developer/Xcode/tvOS DeviceSupport",
    // Docker and VMs
    "Library/Containers/com.docker.docker",
    ".docker",
    // Apple-specific patterns (glob-style, handled separately)
];

/// Glob patterns for warning paths
pub const WARNING_PATTERNS: &[&str] = &["com.apple.*", "*.app/Contents/MacOS/*"];

/// Caution paths that are safe to delete but may require rebuild (CAUTION level)
pub const CAUTION_PATHS: &[&str] = &[
    // User caches
    "Library/Caches",
    // Old logs
    "Library/Logs",
    // Application state
    "Library/Saved Application State",
    // Temporary items
    ".Trash",
];

/// Safe paths that can be deleted without concern (SAFE level)
pub const SAFE_PATHS: &[&str] = &[
    // Browser caches
    "Library/Caches/Google/Chrome",
    "Library/Caches/Firefox",
    "Library/Caches/com.apple.Safari",
    "Library/Caches/com.brave.Browser",
    // Temporary files
    "/tmp",
    "/private/tmp",
    "/var/tmp",
    "Library/Caches/Temporary Items",
];

/// Path category for classification
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PathCategory {
    /// System critical paths - never delete
    SystemCritical,
    /// User critical data - never delete
    UserCritical,
    /// Developer caches requiring re-download
    DeveloperCache,
    /// Application containers
    AppContainer,
    /// Browser caches
    BrowserCache,
    /// Application caches
    AppCache,
    /// Log files
    Logs,
    /// Temporary files
    Temporary,
    /// User documents
    UserDocuments,
    /// Unknown/other
    Unknown,
}

/// Expands a path pattern that may start with ~ to the actual home directory
pub fn expand_home(path: &str) -> PathBuf {
    if path.starts_with('~') {
        if let Some(home) = dirs::home_dir() {
            return home.join(path.trim_start_matches("~/").trim_start_matches('~'));
        }
    }
    PathBuf::from(path)
}

/// Check if a path matches any of the given patterns
pub fn matches_any_path(path: &Path, patterns: &[&str]) -> bool {
    let path_str = path.to_string_lossy();

    for pattern in patterns {
        let expanded = expand_home(pattern);
        let pattern_str = expanded.to_string_lossy();

        // Check if path starts with or contains the pattern
        if path_str.starts_with(pattern_str.as_ref()) {
            return true;
        }

        // Also check relative path matching for user paths
        if !pattern.starts_with('/') {
            if let Some(home) = dirs::home_dir() {
                let full_pattern = home.join(pattern);
                if path.starts_with(&full_pattern) {
                    return true;
                }
            }
        }
    }

    false
}

/// Check if a path is in the user's home directory
pub fn is_in_home_dir(path: &Path) -> bool {
    if let Some(home) = dirs::home_dir() {
        path.starts_with(&home)
    } else {
        false
    }
}

/// Get the relative path from home directory
pub fn relative_to_home(path: &Path) -> Option<PathBuf> {
    dirs::home_dir().and_then(|home| path.strip_prefix(&home).ok().map(PathBuf::from))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_expand_home() {
        let expanded = expand_home("~/Library/Caches");
        assert!(expanded.to_string_lossy().contains("Library/Caches"));
        assert!(!expanded.to_string_lossy().starts_with('~'));
    }

    #[test]
    fn test_matches_system_path() {
        let path = Path::new("/System/Library/Fonts");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_is_in_home_dir() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Documents/test.txt");
            assert!(is_in_home_dir(&path));
        }

        assert!(!is_in_home_dir(Path::new("/System/Library")));
    }
}
