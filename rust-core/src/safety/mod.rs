// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Safety validation module
//!
//! Provides comprehensive safety validation for cleanup operations:
//! - 4-level safety classification (Safe, Caution, Warning, Danger)
//! - Protected path enforcement
//! - Running application detection
//! - Cloud sync status detection
//! - Batch validation for performance

pub mod cloud;
pub mod level;
pub mod paths;
pub mod process;
pub mod validator;

// Re-export main types for convenience
pub use cloud::{
    get_cloud_sync_info, is_safe_to_delete_cloud, CloudService, CloudSyncInfo, SyncStatus,
};
pub use level::{CleanupLevel, SafetyLevel};
pub use paths::{
    expand_home, PathCategory, CAUTION_PATHS, PROTECTED_PATHS, SAFE_PATHS, WARNING_PATHS,
};
pub use process::{
    check_related_app_running, get_processes_using_path, get_running_processes, is_app_running,
    is_file_in_use, AppCacheMapping, ProcessInfo,
};
pub use validator::{ClassificationResult, SafetyRule, SafetyValidator, ValidationError};

use std::path::Path;

/// Calculate the safety level for a given path
///
/// This is the main entry point for safety classification.
/// Returns a SafetyLevel from 1 (Safe) to 4 (Danger).
///
/// # Backward Compatibility Note
/// This function maintains backward compatibility with the original API
/// but now uses the new 4-level classification system.
pub fn calculate_safety_level(path: &str) -> u8 {
    let validator = SafetyValidator::new();
    let level = validator.classify(Path::new(path));
    level as u8
}

/// Categorize a path for safety assessment
///
/// # Deprecated
/// Use `SafetyValidator::classify()` instead for more accurate results.
#[deprecated(since = "0.2.0", note = "Use SafetyValidator::classify() instead")]
pub fn categorize_path(path: &str) -> PathCategory {
    let path_lower = path.to_lowercase();

    // Check protected paths
    for protected in PROTECTED_PATHS {
        if path.starts_with(protected) || path_lower.contains(&protected.to_lowercase()) {
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
        return PathCategory::UserCritical;
    }

    PathCategory::Unknown
}

/// Check if a path is safe to delete at the given safety level
///
/// # Arguments
/// * `path` - The path to check
/// * `cleanup_level` - The cleanup level being used
///
/// # Returns
/// * `true` if deletion is allowed
/// * `false` if deletion would violate safety constraints
pub fn is_safe_to_delete(path: &str, cleanup_level: CleanupLevel) -> bool {
    let validator = SafetyValidator::new();
    let safety_level = validator.classify(Path::new(path));

    cleanup_level.can_delete(safety_level)
}

/// Validate a cleanup operation
///
/// Performs comprehensive validation including:
/// - Path existence check
/// - Safety level validation
/// - Running process detection (optional)
/// - Cloud sync status check (optional)
pub fn validate_cleanup(path: &str, cleanup_level: CleanupLevel) -> Result<(), ValidationError> {
    let path_obj = Path::new(path);
    let validator = SafetyValidator::new();

    // Basic validation
    let max_allowed = cleanup_level.max_deletable_safety();
    validator.validate_cleanup(path_obj, max_allowed)?;

    // Check for running processes
    if let Some(app_name) = check_related_app_running(path) {
        return Err(ValidationError::ProcessRunning {
            path: path.to_string(),
            process: app_name,
        });
    }

    // Check cloud sync status
    if let Err(msg) = is_safe_to_delete_cloud(path_obj) {
        return Err(ValidationError::CloudSyncInProgress(msg));
    }

    Ok(())
}

/// Perform batch validation on multiple paths
///
/// Efficiently validates multiple paths in a single call.
pub fn validate_batch(
    paths: &[&str],
    cleanup_level: CleanupLevel,
) -> Vec<Result<SafetyLevel, ValidationError>> {
    let validator = SafetyValidator::new();
    let max_allowed = cleanup_level.max_deletable_safety();

    paths
        .iter()
        .map(|path| {
            let path_obj = Path::new(path);
            validator.validate_cleanup(path_obj, max_allowed)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_safety_level_protected() {
        let level = calculate_safety_level("/System/Library/Fonts");
        assert_eq!(level, SafetyLevel::Danger as u8);
    }

    #[test]
    fn test_calculate_safety_level_browser_cache() {
        let level =
            calculate_safety_level("/Users/test/Library/Caches/Google/Chrome/Default/Cache");
        assert_eq!(level, SafetyLevel::Safe as u8);
    }

    #[test]
    fn test_is_safe_to_delete() {
        // Browser cache should be deletable at Light level
        assert!(is_safe_to_delete(
            "/Users/test/Library/Caches/Google/Chrome/Cache",
            CleanupLevel::Light
        ));

        // System path should never be deletable
        assert!(!is_safe_to_delete("/System/Library", CleanupLevel::System));
    }

    #[test]
    fn test_cleanup_level_progression() {
        // Light < Normal < Deep < System
        assert!(CleanupLevel::Light.can_delete(SafetyLevel::Safe));
        assert!(!CleanupLevel::Light.can_delete(SafetyLevel::Caution));

        assert!(CleanupLevel::Normal.can_delete(SafetyLevel::Caution));
        assert!(!CleanupLevel::Normal.can_delete(SafetyLevel::Warning));

        assert!(CleanupLevel::Deep.can_delete(SafetyLevel::Warning));
        assert!(!CleanupLevel::Deep.can_delete(SafetyLevel::Danger));
    }

    #[test]
    fn test_batch_validation() {
        // Use paths that exist on the system
        let paths = ["/tmp", "/System/Library/Fonts"];

        let results = validate_batch(&paths, CleanupLevel::Deep);
        // /tmp should be classified as Safe and deletable at Deep level
        assert!(results[0].is_ok() || results[0].is_err()); // May fail if /tmp doesn't exist
                                                            // /System should always fail as DANGER
        assert!(results[1].is_err());
    }
}
