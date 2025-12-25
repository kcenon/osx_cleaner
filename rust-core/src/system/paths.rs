// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Version-specific path resolution
//!
//! Handles macOS version differences in cache and system paths.

use super::version::{known_versions, Version};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Method for cleaning up a target
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(C)]
pub enum CleanupMethod {
    /// Direct file/folder deletion
    DirectDelete = 0,
    /// Use system command (e.g., xcrun simctl)
    SystemCommand = 1,
    /// Requires user interaction or confirmation
    Interactive = 2,
    /// Special handling required
    Special = 3,
}

/// A version-specific cleanup target
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpecialTarget {
    /// Name of the target
    pub name: String,
    /// Path to the target
    pub path: PathBuf,
    /// Minimum macOS version where this target applies
    pub min_version: Version,
    /// Maximum macOS version (None means no upper limit)
    pub max_version: Option<Version>,
    /// How to clean this target
    pub cleanup_method: CleanupMethod,
    /// Description for the user
    pub description: String,
}

impl SpecialTarget {
    /// Create a new special target
    pub fn new(
        name: impl Into<String>,
        path: impl Into<PathBuf>,
        min_version: Version,
        max_version: Option<Version>,
        cleanup_method: CleanupMethod,
        description: impl Into<String>,
    ) -> Self {
        Self {
            name: name.into(),
            path: path.into(),
            min_version,
            max_version,
            cleanup_method,
            description: description.into(),
        }
    }

    /// Check if this target applies to the given version
    pub fn applies_to(&self, version: &Version) -> bool {
        if version < &self.min_version {
            return false;
        }
        if let Some(max) = &self.max_version {
            if version > max {
                return false;
            }
        }
        true
    }
}

/// Version-specific paths container
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VersionPaths {
    /// Safari cache path (may include profile subdirectories on 14.x+)
    pub safari_cache: Vec<PathBuf>,
    /// System cache paths
    pub system_caches: Vec<PathBuf>,
    /// Special cleanup targets for this version
    pub special_targets: Vec<SpecialTarget>,
}

impl VersionPaths {
    /// Get version-specific paths for the given macOS version
    pub fn for_version(version: &Version) -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
        let mut safari_cache = Vec::new();
        let mut system_caches = Vec::new();
        let mut special_targets = Vec::new();

        // Safari cache paths - profile separation started in Sonoma (14.x)
        if version.is_at_least(14, 0) {
            // Sonoma+ uses profile-based Safari
            let safari_base = home.join("Library/Containers/com.apple.Safari/Data/Library/Caches");
            safari_cache.push(safari_base);

            // Also check for profile-specific caches
            let profiles_dir = home.join("Library/Safari/Profiles");
            if profiles_dir.exists() {
                if let Ok(entries) = std::fs::read_dir(&profiles_dir) {
                    for entry in entries.filter_map(|e| e.ok()) {
                        let profile_cache = entry.path().join("Caches");
                        if profile_cache.exists() {
                            safari_cache.push(profile_cache);
                        }
                    }
                }
            }
        } else {
            // Pre-Sonoma Safari
            safari_cache.push(home.join("Library/Caches/com.apple.Safari"));
            safari_cache.push(home.join("Library/Safari/LocalStorage"));
        }

        // System caches - consistent across versions
        system_caches.push(home.join("Library/Caches"));
        system_caches.push(PathBuf::from("/Library/Caches"));

        // Special targets based on version
        Self::add_version_specific_targets(version, &home, &mut special_targets);

        Self {
            safari_cache,
            system_caches,
            special_targets,
        }
    }

    fn add_version_specific_targets(
        version: &Version,
        home: &std::path::Path,
        targets: &mut Vec<SpecialTarget>,
    ) {
        // mediaanalysisd issue in macOS 15.1
        // This bug causes excessive disk usage in System Data
        if version.is_at_least(15, 1) {
            targets.push(SpecialTarget::new(
                "mediaanalysisd cache",
                home.join("Library/Containers/com.apple.mediaanalysisd"),
                known_versions::SEQUOIA_15_1,
                None,
                CleanupMethod::Special,
                "Fix for macOS 15.1 mediaanalysisd disk usage bug",
            ));

            targets.push(SpecialTarget::new(
                "photoanalysisd cache",
                home.join("Library/Containers/com.apple.photoanalysisd"),
                known_versions::SEQUOIA_15_1,
                None,
                CleanupMethod::DirectDelete,
                "Photo analysis cache (may cause high disk usage in 15.1)",
            ));
        }

        // Monterey introduced "System Data" category
        if version.is_at_least(12, 0) {
            targets.push(SpecialTarget::new(
                "Time Machine local snapshots",
                PathBuf::from("/Volumes/.timemachine"),
                known_versions::MONTEREY,
                None,
                CleanupMethod::SystemCommand,
                "Local Time Machine snapshots consuming System Data",
            ));
        }

        // Big Sur introduced Apple Silicon support
        if version.is_at_least(11, 0) {
            targets.push(SpecialTarget::new(
                "Rosetta 2 AOT cache",
                PathBuf::from("/var/db/oah"),
                known_versions::BIG_SUR,
                None,
                CleanupMethod::Special,
                "Rosetta 2 ahead-of-time translation cache (Apple Silicon only)",
            ));
        }

        // Developer caches - all versions
        targets.push(SpecialTarget::new(
            "Xcode DerivedData",
            home.join("Library/Developer/Xcode/DerivedData"),
            known_versions::CATALINA,
            None,
            CleanupMethod::DirectDelete,
            "Xcode build artifacts and indexes",
        ));

        targets.push(SpecialTarget::new(
            "iOS Device Support",
            home.join("Library/Developer/Xcode/iOS DeviceSupport"),
            known_versions::CATALINA,
            None,
            CleanupMethod::DirectDelete,
            "iOS device symbol files (re-downloadable)",
        ));

        targets.push(SpecialTarget::new(
            "watchOS Device Support",
            home.join("Library/Developer/Xcode/watchOS DeviceSupport"),
            known_versions::CATALINA,
            None,
            CleanupMethod::DirectDelete,
            "watchOS device symbol files (re-downloadable)",
        ));

        targets.push(SpecialTarget::new(
            "CoreSimulator Devices",
            home.join("Library/Developer/CoreSimulator/Devices"),
            known_versions::CATALINA,
            None,
            CleanupMethod::SystemCommand,
            "iOS Simulator devices (use xcrun simctl delete)",
        ));
    }

    /// Get all Safari cache paths
    pub fn safari_caches(&self) -> &[PathBuf] {
        &self.safari_cache
    }

    /// Get special targets for a specific version
    pub fn targets_for_version(&self, version: &Version) -> Vec<&SpecialTarget> {
        self.special_targets
            .iter()
            .filter(|t| t.applies_to(version))
            .collect()
    }

    /// Calculate total size of all special targets
    pub fn calculate_special_targets_size(&self) -> u64 {
        self.special_targets
            .iter()
            .filter(|t| t.path.exists())
            .map(|t| dir_size(&t.path))
            .sum()
    }
}

impl Default for VersionPaths {
    fn default() -> Self {
        let version = Version::detect().unwrap_or(known_versions::SEQUOIA);
        Self::for_version(&version)
    }
}

/// Calculate directory size recursively
fn dir_size(path: &std::path::Path) -> u64 {
    if !path.exists() {
        return 0;
    }

    walkdir::WalkDir::new(path)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter_map(|e| e.metadata().ok())
        .filter(|m| m.is_file())
        .map(|m| m.len())
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_special_target_applies_to() {
        let target = SpecialTarget::new(
            "test",
            "/test",
            Version::new(14, 0, 0),
            Some(Version::new(15, 0, 0)),
            CleanupMethod::DirectDelete,
            "Test target",
        );

        assert!(!target.applies_to(&Version::new(13, 0, 0)));
        assert!(target.applies_to(&Version::new(14, 0, 0)));
        assert!(target.applies_to(&Version::new(14, 5, 0)));
        assert!(target.applies_to(&Version::new(15, 0, 0)));
        assert!(!target.applies_to(&Version::new(15, 1, 0)));
    }

    #[test]
    fn test_version_paths_for_sonoma() {
        let paths = VersionPaths::for_version(&Version::new(14, 5, 0));
        assert!(!paths.safari_cache.is_empty());
        assert!(!paths.system_caches.is_empty());
    }

    #[test]
    fn test_version_paths_for_sequoia_15_1() {
        let paths = VersionPaths::for_version(&Version::new(15, 1, 0));
        let mediaanalysisd = paths
            .special_targets
            .iter()
            .find(|t| t.name == "mediaanalysisd cache");
        assert!(mediaanalysisd.is_some());
    }

    #[test]
    fn test_cleanup_method_variants() {
        assert_eq!(CleanupMethod::DirectDelete as u8, 0);
        assert_eq!(CleanupMethod::SystemCommand as u8, 1);
        assert_eq!(CleanupMethod::Interactive as u8, 2);
        assert_eq!(CleanupMethod::Special as u8, 3);
    }
}
