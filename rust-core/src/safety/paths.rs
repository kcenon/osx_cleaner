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

/// Categorizes a path into its appropriate PathCategory
///
/// This function analyzes the path structure and content to determine
/// what type of data it represents, which helps in safety classification.
pub fn categorize_path(path: &Path) -> PathCategory {
    let path_str = path.to_string_lossy();

    // Check system critical paths first
    if path_str.starts_with("/System")
        || path_str.starts_with("/usr/bin")
        || path_str.starts_with("/usr/sbin")
        || path_str.starts_with("/usr/lib")
        || path_str.starts_with("/usr/libexec")
        || path_str.starts_with("/bin")
        || path_str.starts_with("/sbin")
        || path_str.starts_with("/private/var/db")
        || path_str.starts_with("/Library/Extensions")
        || path_str.starts_with("/Library/Frameworks")
    {
        return PathCategory::SystemCritical;
    }

    // Check if path is in home directory
    if let Some(rel_path) = relative_to_home(path) {
        let rel_str = rel_path.to_string_lossy();
        let rel_lower = rel_str.to_lowercase();

        // User critical data
        if rel_str.starts_with("Library/Keychains")
            || rel_str.starts_with("Library/Application Support")
            || rel_str.starts_with("Library/Mail")
            || rel_str.starts_with("Library/Messages")
            || rel_str.starts_with("Library/Preferences")
            || rel_str.starts_with("Library/Accounts")
            || rel_str.starts_with("Library/Cookies")
            || rel_str.starts_with("Library/Calendars")
            || rel_str.starts_with("Library/Contacts")
            || rel_str.starts_with("Library/Safari/Bookmarks.plist")
            || rel_str.starts_with("Library/Safari/History.db")
        {
            return PathCategory::UserCritical;
        }

        // User documents
        if rel_str.starts_with("Documents")
            || rel_str.starts_with("Desktop")
            || rel_str.starts_with("Pictures")
            || rel_str.starts_with("Movies")
            || rel_str.starts_with("Music")
            || rel_str.starts_with("Downloads")
        {
            return PathCategory::UserDocuments;
        }

        // Developer caches
        if rel_lower.contains("/deriveddata")
            || rel_str.starts_with("Library/Developer/Xcode/iOS DeviceSupport")
            || rel_str.starts_with("Library/Developer/Xcode/watchOS DeviceSupport")
            || rel_str.starts_with("Library/Developer/Xcode/tvOS DeviceSupport")
            || rel_str.starts_with("Library/Developer/CoreSimulator")
            || rel_str.starts_with(".gradle/caches")
            || rel_str.starts_with(".npm")
            || rel_str.starts_with(".cargo/registry")
            || rel_str.starts_with(".pub-cache")
            || rel_str.starts_with(".cocoapods")
        {
            return PathCategory::DeveloperCache;
        }

        // Application containers
        if rel_str.starts_with("Library/Containers")
            || rel_str.starts_with("Library/Group Containers")
        {
            return PathCategory::AppContainer;
        }

        // Browser caches
        if rel_lower.contains("/google/chrome")
            || rel_lower.contains("/firefox")
            || rel_lower.contains("/safari")
            || rel_lower.contains("/brave")
            || rel_lower.contains("/microsoft edge")
            || rel_lower.contains("/opera")
        {
            return PathCategory::BrowserCache;
        }

        // Application caches
        if rel_str.starts_with("Library/Caches") {
            return PathCategory::AppCache;
        }

        // Log files
        if rel_str.starts_with("Library/Logs") || rel_lower.ends_with(".log") {
            return PathCategory::Logs;
        }

        // Temporary files
        if rel_str.starts_with(".Trash") || rel_str.starts_with("Library/Caches/Temporary Items") {
            return PathCategory::Temporary;
        }
    }

    // Check system-level temporary paths
    if path_str.starts_with("/tmp")
        || path_str.starts_with("/private/tmp")
        || path_str.starts_with("/var/tmp")
    {
        return PathCategory::Temporary;
    }

    // Check system-level caches
    if path_str.starts_with("/Library/Caches") {
        return PathCategory::AppCache;
    }

    // Check system-level logs
    if path_str.starts_with("/var/log") || path_str.starts_with("/Library/Logs") {
        return PathCategory::Logs;
    }

    PathCategory::Unknown
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

    // ===== Home Directory Expansion Tests =====

    #[test]
    fn test_expand_home_with_tilde() {
        let expanded = expand_home("~/Library/Caches");
        assert!(expanded.to_string_lossy().contains("Library/Caches"));
        assert!(!expanded.to_string_lossy().starts_with('~'));
    }

    #[test]
    fn test_expand_home_without_tilde() {
        let expanded = expand_home("/System/Library");
        assert_eq!(expanded, PathBuf::from("/System/Library"));
    }

    #[test]
    fn test_expand_home_tilde_only() {
        let expanded = expand_home("~");
        if let Some(home) = dirs::home_dir() {
            assert_eq!(expanded, home);
        }
    }

    #[test]
    fn test_expand_home_preserves_subpath() {
        let expanded = expand_home("~/Documents/subfolder/file.txt");
        assert!(expanded
            .to_string_lossy()
            .contains("Documents/subfolder/file.txt"));
    }

    // ===== System Protected Paths Tests =====

    #[test]
    fn test_protected_path_system() {
        let path = Path::new("/System/Library/Fonts");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_protected_path_usr_bin() {
        let path = Path::new("/usr/bin/ls");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_protected_path_usr_sbin() {
        let path = Path::new("/usr/sbin/diskutil");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_protected_path_bin() {
        let path = Path::new("/bin/bash");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_protected_path_sbin() {
        let path = Path::new("/sbin/mount");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_protected_path_private_var_db() {
        let path = Path::new("/private/var/db/dslocal");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    #[test]
    fn test_protected_path_private_var_folders() {
        let path = Path::new("/private/var/folders/xx/temp");
        assert!(matches_any_path(path, PROTECTED_PATHS));
    }

    // ===== User Protected Paths Tests =====

    #[test]
    fn test_protected_path_keychains() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Keychains/login.keychain-db");
            assert!(matches_any_path(&path, PROTECTED_PATHS));
        }
    }

    #[test]
    fn test_protected_path_application_support() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Application Support/SomeApp");
            assert!(matches_any_path(&path, PROTECTED_PATHS));
        }
    }

    #[test]
    fn test_protected_path_mail() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Mail/V9/Mailboxes");
            assert!(matches_any_path(&path, PROTECTED_PATHS));
        }
    }

    #[test]
    fn test_protected_path_messages() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Messages/chat.db");
            assert!(matches_any_path(&path, PROTECTED_PATHS));
        }
    }

    #[test]
    fn test_protected_path_preferences() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Preferences/com.apple.finder.plist");
            assert!(matches_any_path(&path, PROTECTED_PATHS));
        }
    }

    #[test]
    fn test_protected_path_documents() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Documents/important.doc");
            assert!(matches_any_path(&path, PROTECTED_PATHS));
        }
    }

    // ===== Warning Paths Tests =====

    #[test]
    fn test_warning_path_containers() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Containers/com.apple.mail");
            assert!(matches_any_path(&path, WARNING_PATHS));
        }
    }

    #[test]
    fn test_warning_path_group_containers() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Group Containers/group.com.apple");
            assert!(matches_any_path(&path, WARNING_PATHS));
        }
    }

    #[test]
    fn test_warning_path_library_caches() {
        let path = Path::new("/Library/Caches/com.apple.installer");
        assert!(matches_any_path(path, WARNING_PATHS));
    }

    #[test]
    fn test_warning_path_ios_device_support() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Developer/Xcode/iOS DeviceSupport/16.0");
            assert!(matches_any_path(&path, WARNING_PATHS));
        }
    }

    #[test]
    fn test_warning_path_docker() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Containers/com.docker.docker/Data");
            assert!(matches_any_path(&path, WARNING_PATHS));
        }
    }

    // ===== Caution Paths Tests =====

    #[test]
    fn test_caution_path_user_caches() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Caches/com.someapp");
            assert!(matches_any_path(&path, CAUTION_PATHS));
        }
    }

    #[test]
    fn test_caution_path_logs() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Logs/DiagnosticReports");
            assert!(matches_any_path(&path, CAUTION_PATHS));
        }
    }

    #[test]
    fn test_caution_path_saved_state() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Saved Application State/com.app.saved");
            assert!(matches_any_path(&path, CAUTION_PATHS));
        }
    }

    #[test]
    fn test_caution_path_trash() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join(".Trash/deleted_file");
            assert!(matches_any_path(&path, CAUTION_PATHS));
        }
    }

    // ===== Safe Paths Tests =====

    #[test]
    fn test_safe_path_chrome_cache() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Caches/Google/Chrome/Default/Cache");
            assert!(matches_any_path(&path, SAFE_PATHS));
        }
    }

    #[test]
    fn test_safe_path_firefox_cache() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Caches/Firefox/Profiles/cache2");
            assert!(matches_any_path(&path, SAFE_PATHS));
        }
    }

    #[test]
    fn test_safe_path_safari_cache() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Caches/com.apple.Safari/fsCachedData");
            assert!(matches_any_path(&path, SAFE_PATHS));
        }
    }

    #[test]
    fn test_safe_path_tmp() {
        let path = Path::new("/tmp/temp_file");
        assert!(matches_any_path(path, SAFE_PATHS));
    }

    #[test]
    fn test_safe_path_private_tmp() {
        let path = Path::new("/private/tmp/temp_file");
        assert!(matches_any_path(path, SAFE_PATHS));
    }

    // ===== Home Directory Detection Tests =====

    #[test]
    fn test_is_in_home_dir_true() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Documents/test.txt");
            assert!(is_in_home_dir(&path));
        }
    }

    #[test]
    fn test_is_in_home_dir_false() {
        assert!(!is_in_home_dir(Path::new("/System/Library")));
        assert!(!is_in_home_dir(Path::new("/usr/bin")));
        assert!(!is_in_home_dir(Path::new("/tmp")));
    }

    #[test]
    fn test_relative_to_home() {
        if let Some(home) = dirs::home_dir() {
            let path = home.join("Library/Caches");
            let rel = relative_to_home(&path);
            assert_eq!(rel, Some(PathBuf::from("Library/Caches")));
        }
    }

    #[test]
    fn test_relative_to_home_not_in_home() {
        let path = Path::new("/System/Library");
        let rel = relative_to_home(path);
        assert!(rel.is_none());
    }

    // ===== Path Categorization Tests =====

    #[test]
    fn test_categorize_system_critical() {
        assert_eq!(
            categorize_path(Path::new("/System/Library")),
            PathCategory::SystemCritical
        );
        assert_eq!(
            categorize_path(Path::new("/usr/bin/ls")),
            PathCategory::SystemCritical
        );
        assert_eq!(
            categorize_path(Path::new("/bin/bash")),
            PathCategory::SystemCritical
        );
    }

    #[test]
    fn test_categorize_user_critical() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Library/Keychains")),
                PathCategory::UserCritical
            );
            assert_eq!(
                categorize_path(&home.join("Library/Mail")),
                PathCategory::UserCritical
            );
            assert_eq!(
                categorize_path(&home.join("Library/Preferences")),
                PathCategory::UserCritical
            );
        }
    }

    #[test]
    fn test_categorize_user_documents() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Documents")),
                PathCategory::UserDocuments
            );
            assert_eq!(
                categorize_path(&home.join("Desktop")),
                PathCategory::UserDocuments
            );
            assert_eq!(
                categorize_path(&home.join("Downloads")),
                PathCategory::UserDocuments
            );
        }
    }

    #[test]
    fn test_categorize_developer_cache() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Library/Developer/Xcode/iOS DeviceSupport/16.0")),
                PathCategory::DeveloperCache
            );
            assert_eq!(
                categorize_path(&home.join(".npm/cache")),
                PathCategory::DeveloperCache
            );
            assert_eq!(
                categorize_path(&home.join(".gradle/caches")),
                PathCategory::DeveloperCache
            );
        }
    }

    #[test]
    fn test_categorize_app_container() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Library/Containers/com.apple.mail")),
                PathCategory::AppContainer
            );
            assert_eq!(
                categorize_path(&home.join("Library/Group Containers/group.com.app")),
                PathCategory::AppContainer
            );
        }
    }

    #[test]
    fn test_categorize_browser_cache() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Library/Caches/Google/Chrome")),
                PathCategory::BrowserCache
            );
            assert_eq!(
                categorize_path(&home.join("Library/Caches/Firefox")),
                PathCategory::BrowserCache
            );
        }
    }

    #[test]
    fn test_categorize_app_cache() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Library/Caches/com.someapp")),
                PathCategory::AppCache
            );
        }
        assert_eq!(
            categorize_path(Path::new("/Library/Caches/com.apple.installer")),
            PathCategory::AppCache
        );
    }

    #[test]
    fn test_categorize_logs() {
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join("Library/Logs/DiagnosticReports")),
                PathCategory::Logs
            );
        }
        assert_eq!(
            categorize_path(Path::new("/var/log/system.log")),
            PathCategory::Logs
        );
    }

    #[test]
    fn test_categorize_temporary() {
        assert_eq!(
            categorize_path(Path::new("/tmp/tempfile")),
            PathCategory::Temporary
        );
        assert_eq!(
            categorize_path(Path::new("/private/tmp/tempfile")),
            PathCategory::Temporary
        );
        if let Some(home) = dirs::home_dir() {
            assert_eq!(
                categorize_path(&home.join(".Trash/deleted")),
                PathCategory::Temporary
            );
        }
    }

    #[test]
    fn test_categorize_unknown() {
        assert_eq!(
            categorize_path(Path::new("/some/random/path")),
            PathCategory::Unknown
        );
    }

    // ===== Warning Patterns Tests =====

    #[test]
    fn test_warning_patterns_contains_apple() {
        assert!(WARNING_PATTERNS.contains(&"com.apple.*"));
    }

    #[test]
    fn test_warning_patterns_contains_app_binary() {
        assert!(WARNING_PATTERNS.contains(&"*.app/Contents/MacOS/*"));
    }
}
