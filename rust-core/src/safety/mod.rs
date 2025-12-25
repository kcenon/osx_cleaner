//! Safety validation module
//!
//! Provides safety level calculation and validation for cleanup operations.
//! Safety levels range from 1 (most aggressive) to 5 (most conservative).

use std::path::Path;

/// Safety levels for cleanup operations
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(C)]
pub enum SafetyLevel {
    /// Level 1: Aggressive - includes system files
    Aggressive = 1,
    /// Level 2: Normal - includes most caches
    Normal = 2,
    /// Level 3: Conservative - default, safe caches only
    Conservative = 3,
    /// Level 4: Safe - only definitely safe items
    Safe = 4,
    /// Level 5: Paranoid - only user-specified items
    Paranoid = 5,
}

impl From<u8> for SafetyLevel {
    fn from(value: u8) -> Self {
        match value {
            1 => SafetyLevel::Aggressive,
            2 => SafetyLevel::Normal,
            3 => SafetyLevel::Conservative,
            4 => SafetyLevel::Safe,
            _ => SafetyLevel::Paranoid,
        }
    }
}

/// Path categories for safety classification
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PathCategory {
    /// System critical paths - never delete
    SystemCritical,
    /// System paths that can be cleaned carefully
    System,
    /// User configuration paths
    UserConfig,
    /// Application caches
    AppCache,
    /// Developer tool caches
    DeveloperCache,
    /// Browser caches
    BrowserCache,
    /// Temporary files
    Temporary,
    /// Log files
    Logs,
    /// User documents - high protection
    UserDocuments,
    /// Unknown/other
    Unknown,
}

/// Protected paths that should never be deleted
const PROTECTED_PATHS: &[&str] = &[
    "/System",
    "/usr",
    "/bin",
    "/sbin",
    "/Library/Extensions",
    "/Library/Frameworks",
    "/Applications",
];

/// Calculate the safety level for a given path
///
/// Returns a value from 1 (least safe to delete) to 5 (most safe to delete)
pub fn calculate_safety_level(path: &str) -> u8 {
    let category = categorize_path(path);

    match category {
        PathCategory::SystemCritical => 0, // Never delete
        PathCategory::System => 1,
        PathCategory::UserConfig => 2,
        PathCategory::UserDocuments => 2,
        PathCategory::Unknown => 3,
        PathCategory::AppCache => 4,
        PathCategory::DeveloperCache => 4,
        PathCategory::BrowserCache => 5,
        PathCategory::Logs => 5,
        PathCategory::Temporary => 5,
    }
}

/// Categorize a path for safety assessment
pub fn categorize_path(path: &str) -> PathCategory {
    let path_lower = path.to_lowercase();

    // Check protected paths
    for protected in PROTECTED_PATHS {
        if path.starts_with(protected) {
            return PathCategory::SystemCritical;
        }
    }

    // Check for user documents
    if path_lower.contains("/documents/")
        || path_lower.contains("/desktop/")
        || path_lower.contains("/pictures/")
        || path_lower.contains("/movies/")
        || path_lower.contains("/music/")
    {
        return PathCategory::UserDocuments;
    }

    // Check for developer caches
    if path_lower.contains("/deriveddata")
        || path_lower.contains("/.gradle/")
        || path_lower.contains("/.npm/")
        || path_lower.contains("/.cargo/")
        || path_lower.contains("/.pub-cache")
        || path_lower.contains("/coresimulator/")
    {
        return PathCategory::DeveloperCache;
    }

    // Check for browser caches
    if path_lower.contains("/chrome/")
        || path_lower.contains("/firefox/")
        || path_lower.contains("/safari/")
        || path_lower.contains("/brave/")
    {
        return PathCategory::BrowserCache;
    }

    // Check for caches
    if path_lower.contains("/caches/") || path_lower.contains("/cache/") {
        return PathCategory::AppCache;
    }

    // Check for logs
    if path_lower.contains("/logs/") || path_lower.contains(".log") {
        return PathCategory::Logs;
    }

    // Check for temporary files
    if path_lower.contains("/tmp/") || path_lower.contains("/temp/") || path_lower.contains("/.tmp")
    {
        return PathCategory::Temporary;
    }

    // Check for user configuration
    if path_lower.contains("/preferences/") || path_lower.contains("/.config/") {
        return PathCategory::UserConfig;
    }

    // Check for system paths
    if path.starts_with("/Library/") || path.starts_with("/private/") {
        return PathCategory::System;
    }

    PathCategory::Unknown
}

/// Check if a path is safe to delete at the given safety level
pub fn is_safe_to_delete(path: &str, required_level: SafetyLevel) -> bool {
    let path_safety = calculate_safety_level(path);
    path_safety >= required_level as u8
}

/// Validate a cleanup operation
pub fn validate_cleanup(path: &str, safety_level: SafetyLevel) -> Result<(), ValidationError> {
    // Check if path exists
    if !Path::new(path).exists() {
        return Err(ValidationError::PathNotFound(path.to_string()));
    }

    // Check if path is protected
    for protected in PROTECTED_PATHS {
        if path.starts_with(protected) {
            return Err(ValidationError::ProtectedPath(path.to_string()));
        }
    }

    // Check safety level
    if !is_safe_to_delete(path, safety_level) {
        return Err(ValidationError::SafetyLevelTooLow {
            path: path.to_string(),
            required: calculate_safety_level(path),
            provided: safety_level as u8,
        });
    }

    Ok(())
}

/// Validation errors
#[derive(Debug, thiserror::Error)]
pub enum ValidationError {
    #[error("Path not found: {0}")]
    PathNotFound(String),

    #[error("Protected path: {0}")]
    ProtectedPath(String),

    #[error("Safety level too low for path {path}: required {required}, provided {provided}")]
    SafetyLevelTooLow {
        path: String,
        required: u8,
        provided: u8,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_protected_paths() {
        assert_eq!(
            categorize_path("/System/Library/Fonts"),
            PathCategory::SystemCritical
        );
        assert_eq!(categorize_path("/usr/bin/ls"), PathCategory::SystemCritical);
    }

    #[test]
    fn test_developer_cache() {
        let path = "/Users/test/Library/Developer/Xcode/DerivedData/Project";
        assert_eq!(categorize_path(path), PathCategory::DeveloperCache);
        assert!(calculate_safety_level(path) >= 4);
    }

    #[test]
    fn test_browser_cache() {
        let path = "/Users/test/Library/Caches/Google/Chrome/Default/Cache";
        assert_eq!(categorize_path(path), PathCategory::BrowserCache);
        assert_eq!(calculate_safety_level(path), 5);
    }

    #[test]
    fn test_user_documents() {
        let path = "/Users/test/Documents/important.txt";
        assert_eq!(categorize_path(path), PathCategory::UserDocuments);
        assert!(calculate_safety_level(path) <= 2);
    }

    #[test]
    fn test_safety_level_conversion() {
        assert_eq!(SafetyLevel::from(1), SafetyLevel::Aggressive);
        assert_eq!(SafetyLevel::from(3), SafetyLevel::Conservative);
        assert_eq!(SafetyLevel::from(5), SafetyLevel::Paranoid);
        assert_eq!(SafetyLevel::from(99), SafetyLevel::Paranoid);
    }
}
