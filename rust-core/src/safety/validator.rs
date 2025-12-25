//! Safety validator module
//!
//! Provides centralized validation logic for cleanup operations.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::safety::level::SafetyLevel;
use crate::safety::paths::{
    expand_home, is_in_home_dir, matches_any_path, relative_to_home, CAUTION_PATHS,
    PROTECTED_PATHS, SAFE_PATHS, WARNING_PATHS, WARNING_PATTERNS,
};

/// Trait for implementing custom safety rules
pub trait SafetyRule: Send + Sync {
    /// Returns the name of this rule
    fn name(&self) -> &str;

    /// Evaluate this rule for the given path
    /// Returns Some(SafetyLevel) if this rule applies, None otherwise
    fn evaluate(&self, path: &Path) -> Option<SafetyLevel>;

    /// Returns a description of why this rule applies
    fn description(&self) -> &str;
}

/// Result of classifying a path
#[derive(Debug, Clone)]
pub struct ClassificationResult {
    pub path: PathBuf,
    pub level: SafetyLevel,
    pub reason: String,
    pub rule_name: Option<String>,
}

/// Validation error types
#[derive(Debug, Clone, thiserror::Error)]
pub enum ValidationError {
    #[error("Path not found: {0}")]
    PathNotFound(String),

    #[error("Protected path: {path} - {reason}")]
    ProtectedPath { path: String, reason: String },

    #[error("Safety level {required} required for {path}, but cleanup level only allows {allowed}")]
    SafetyLevelMismatch {
        path: String,
        required: SafetyLevel,
        allowed: SafetyLevel,
    },

    #[error("Running process detected: {process} is using {path}")]
    ProcessRunning { path: String, process: String },

    #[error("Cloud sync in progress for: {0}")]
    CloudSyncInProgress(String),
}

/// Safety validator for cleanup operations
pub struct SafetyValidator {
    protected_paths: Vec<PathBuf>,
    warning_paths: Vec<PathBuf>,
    custom_rules: Vec<Arc<dyn SafetyRule>>,
    glob_patterns: Vec<glob::Pattern>,
    classification_cache: HashMap<PathBuf, SafetyLevel>,
}

impl Default for SafetyValidator {
    fn default() -> Self {
        Self::new()
    }
}

impl SafetyValidator {
    /// Create a new SafetyValidator with default paths
    pub fn new() -> Self {
        let protected_paths: Vec<PathBuf> =
            PROTECTED_PATHS.iter().map(|p| expand_home(p)).collect();

        let warning_paths: Vec<PathBuf> = WARNING_PATHS.iter().map(|p| expand_home(p)).collect();

        let glob_patterns: Vec<glob::Pattern> = WARNING_PATTERNS
            .iter()
            .filter_map(|p| glob::Pattern::new(p).ok())
            .collect();

        SafetyValidator {
            protected_paths,
            warning_paths,
            custom_rules: Vec::new(),
            glob_patterns,
            classification_cache: HashMap::new(),
        }
    }

    /// Add a custom safety rule
    pub fn add_rule(&mut self, rule: Arc<dyn SafetyRule>) {
        self.custom_rules.push(rule);
    }

    /// Add a protected path
    pub fn add_protected_path(&mut self, path: PathBuf) {
        if !self.protected_paths.contains(&path) {
            self.protected_paths.push(path);
        }
    }

    /// Add a warning path
    pub fn add_warning_path(&mut self, path: PathBuf) {
        if !self.warning_paths.contains(&path) {
            self.warning_paths.push(path);
        }
    }

    /// Classify a path's safety level
    pub fn classify(&self, path: &Path) -> SafetyLevel {
        // Check custom rules first
        for rule in &self.custom_rules {
            if let Some(level) = rule.evaluate(path) {
                return level;
            }
        }

        // Check protected paths (DANGER)
        if self.is_protected(path) {
            return SafetyLevel::Danger;
        }

        // Check warning paths
        if self.is_warning_path(path) {
            return SafetyLevel::Warning;
        }

        // Check caution paths
        if self.is_caution_path(path) {
            return SafetyLevel::Caution;
        }

        // Check safe paths
        if self.is_safe_path(path) {
            return SafetyLevel::Safe;
        }

        // Classify based on path characteristics
        self.classify_by_characteristics(path)
    }

    /// Check if a path is protected (DANGER level)
    pub fn is_protected(&self, path: &Path) -> bool {
        // Check hardcoded protected paths
        for protected in &self.protected_paths {
            if path.starts_with(protected) {
                return true;
            }
        }

        // Check if it's a user critical path
        if is_in_home_dir(path) {
            if let Some(rel_path) = relative_to_home(path) {
                let rel_str = rel_path.to_string_lossy();
                for protected in PROTECTED_PATHS {
                    if !protected.starts_with('/') && rel_str.starts_with(protected) {
                        return true;
                    }
                }
            }
        }

        false
    }

    /// Check if a path is a warning path
    fn is_warning_path(&self, path: &Path) -> bool {
        for warning in &self.warning_paths {
            if path.starts_with(warning) {
                return true;
            }
        }

        // Check glob patterns
        let path_str = path.to_string_lossy();
        for pattern in &self.glob_patterns {
            if pattern.matches(&path_str) {
                return true;
            }
        }

        // Check user warning paths
        if is_in_home_dir(path) {
            if let Some(rel_path) = relative_to_home(path) {
                let rel_str = rel_path.to_string_lossy();
                for warning in WARNING_PATHS {
                    if !warning.starts_with('/') && rel_str.starts_with(warning) {
                        return true;
                    }
                }
            }
        }

        false
    }

    /// Check if a path is a caution path
    fn is_caution_path(&self, path: &Path) -> bool {
        if is_in_home_dir(path) {
            if let Some(rel_path) = relative_to_home(path) {
                let rel_str = rel_path.to_string_lossy();
                for caution in CAUTION_PATHS {
                    if rel_str.starts_with(caution) {
                        return true;
                    }
                }
            }
        }
        false
    }

    /// Check if a path is safe
    fn is_safe_path(&self, path: &Path) -> bool {
        matches_any_path(path, SAFE_PATHS)
    }

    /// Classify based on path characteristics
    fn classify_by_characteristics(&self, path: &Path) -> SafetyLevel {
        let path_str = path.to_string_lossy().to_lowercase();

        // Developer caches - WARNING
        if path_str.contains("/deriveddata")
            || path_str.contains("/.gradle/")
            || path_str.contains("/.npm/")
            || path_str.contains("/.cargo/registry")
            || path_str.contains("/.pub-cache")
            || path_str.contains("/coresimulator/")
            || path_str.contains("/ios devicesupport")
        {
            return SafetyLevel::Warning;
        }

        // Browser caches - SAFE
        if path_str.contains("/chrome/")
            || path_str.contains("/firefox/")
            || path_str.contains("/safari/")
            || path_str.contains("/brave/")
        {
            return SafetyLevel::Safe;
        }

        // General caches - CAUTION
        if path_str.contains("/caches/") || path_str.contains("/cache/") {
            return SafetyLevel::Caution;
        }

        // Logs - CAUTION
        if path_str.contains("/logs/") || path_str.ends_with(".log") {
            return SafetyLevel::Caution;
        }

        // Temporary files - SAFE
        if path_str.contains("/tmp/")
            || path_str.contains("/temp/")
            || path_str.contains("/.tmp")
            || path_str.contains(".trash")
        {
            return SafetyLevel::Safe;
        }

        // Default to CAUTION for unknown paths
        SafetyLevel::Caution
    }

    /// Validate a batch of paths
    pub fn validate_batch(&self, paths: &[PathBuf]) -> Vec<ClassificationResult> {
        paths
            .iter()
            .map(|path| {
                let level = self.classify(path);
                ClassificationResult {
                    path: path.clone(),
                    level,
                    reason: self.get_classification_reason(path, level),
                    rule_name: None,
                }
            })
            .collect()
    }

    /// Get the reason for a classification
    fn get_classification_reason(&self, path: &Path, level: SafetyLevel) -> String {
        match level {
            SafetyLevel::Danger => {
                if self.is_protected(path) {
                    "Protected system or user path".to_string()
                } else {
                    "Critical path - deletion not allowed".to_string()
                }
            }
            SafetyLevel::Warning => "Requires significant time to rebuild/re-download".to_string(),
            SafetyLevel::Caution => "Can be deleted but may need rebuild".to_string(),
            SafetyLevel::Safe => "Safe to delete - auto-regenerates".to_string(),
        }
    }

    /// Validate a cleanup operation
    pub fn validate_cleanup(
        &self,
        path: &Path,
        max_allowed_level: SafetyLevel,
    ) -> Result<SafetyLevel, ValidationError> {
        // Check if path exists
        if !path.exists() {
            return Err(ValidationError::PathNotFound(
                path.to_string_lossy().to_string(),
            ));
        }

        let level = self.classify(path);

        // Check if deletion is allowed
        if level == SafetyLevel::Danger {
            return Err(ValidationError::ProtectedPath {
                path: path.to_string_lossy().to_string(),
                reason: "Path is marked as DANGER - deletion not allowed".to_string(),
            });
        }

        // Check if level exceeds allowed
        if level > max_allowed_level {
            return Err(ValidationError::SafetyLevelMismatch {
                path: path.to_string_lossy().to_string(),
                required: level,
                allowed: max_allowed_level,
            });
        }

        Ok(level)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_protected_system_paths() {
        let validator = SafetyValidator::new();

        assert_eq!(
            validator.classify(Path::new("/System/Library/Fonts")),
            SafetyLevel::Danger
        );
        assert_eq!(
            validator.classify(Path::new("/usr/bin/ls")),
            SafetyLevel::Danger
        );
        assert_eq!(
            validator.classify(Path::new("/bin/bash")),
            SafetyLevel::Danger
        );
    }

    #[test]
    fn test_developer_cache_warning() {
        let validator = SafetyValidator::new();

        let path = Path::new("/Users/test/Library/Developer/Xcode/DerivedData/Project");
        assert_eq!(validator.classify(path), SafetyLevel::Warning);
    }

    #[test]
    fn test_browser_cache_safe() {
        let validator = SafetyValidator::new();

        let path = Path::new("/Users/test/Library/Caches/Google/Chrome/Default/Cache");
        assert_eq!(validator.classify(path), SafetyLevel::Safe);
    }

    #[test]
    fn test_is_protected() {
        let validator = SafetyValidator::new();

        assert!(validator.is_protected(Path::new("/System/Library")));
        assert!(validator.is_protected(Path::new("/usr/bin")));
        assert!(!validator.is_protected(Path::new("/tmp")));
    }

    #[test]
    fn test_validate_cleanup_protected() {
        let validator = SafetyValidator::new();
        let result = validator.validate_cleanup(Path::new("/System"), SafetyLevel::Warning);
        assert!(matches!(result, Err(ValidationError::ProtectedPath { .. })));
    }
}
