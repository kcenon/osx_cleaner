// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Package Manager Cache Management
//!
//! Provides cleanup functionality for various package manager caches:
//! - CocoaPods (1-10GB)
//! - Swift Package Manager (0.5-5GB)
//! - Carthage (0.5-5GB)
//! - npm (1-20GB)
//! - yarn (1-10GB)
//! - pnpm (1-10GB)
//! - pip (0.5-5GB)
//! - Homebrew (1-10GB)
//! - Cargo/Rust (0.5-5GB)
//! - Gradle (1-10GB)
//! - Maven (0.5-5GB)

use std::fs;
use std::path::PathBuf;
use std::process::Command;

use super::{
    calculate_dir_size, expand_home, CleanupError, CleanupMethod, CleanupResult, CleanupTarget,
    DeveloperCleaner, DeveloperTool, ScanResult,
};
use crate::safety::SafetyLevel;

/// Package manager cache cleaner
pub struct PackageManagerCleaner {
    /// List of package manager configurations
    managers: Vec<PackageManager>,
}

impl Default for PackageManagerCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl PackageManagerCleaner {
    /// Create a new package manager cleaner
    pub fn new() -> Self {
        Self {
            managers: vec![
                // CocoaPods
                PackageManager {
                    tool: DeveloperTool::CocoaPods,
                    cache_paths: vec![expand_home("~/Library/Caches/CocoaPods")],
                    cleanup_command: Some("pod cache clean --all".to_string()),
                    detect_command: Some("pod".to_string()),
                },
                // Swift Package Manager
                PackageManager {
                    tool: DeveloperTool::SwiftPackageManager,
                    cache_paths: vec![
                        expand_home("~/Library/Caches/org.swift.swiftpm"),
                        expand_home("~/Library/Developer/Xcode/DerivedData/*/SourcePackages"),
                    ],
                    cleanup_command: None, // Direct deletion
                    detect_command: Some("swift".to_string()),
                },
                // Carthage
                PackageManager {
                    tool: DeveloperTool::Carthage,
                    cache_paths: vec![expand_home("~/Library/Caches/org.carthage.CarthageKit")],
                    cleanup_command: None, // Direct deletion
                    detect_command: Some("carthage".to_string()),
                },
                // npm
                PackageManager {
                    tool: DeveloperTool::Npm,
                    cache_paths: vec![expand_home("~/.npm")],
                    cleanup_command: Some("npm cache clean --force".to_string()),
                    detect_command: Some("npm".to_string()),
                },
                // yarn
                PackageManager {
                    tool: DeveloperTool::Yarn,
                    cache_paths: vec![expand_home("~/Library/Caches/Yarn")],
                    cleanup_command: Some("yarn cache clean".to_string()),
                    detect_command: Some("yarn".to_string()),
                },
                // pnpm
                PackageManager {
                    tool: DeveloperTool::Pnpm,
                    cache_paths: vec![], // Dynamic path from pnpm store path
                    cleanup_command: Some("pnpm store prune".to_string()),
                    detect_command: Some("pnpm".to_string()),
                },
                // pip
                PackageManager {
                    tool: DeveloperTool::Pip,
                    cache_paths: vec![expand_home("~/Library/Caches/pip")],
                    cleanup_command: Some("pip3 cache purge".to_string()),
                    detect_command: Some("pip3".to_string()),
                },
                // Homebrew
                PackageManager {
                    tool: DeveloperTool::Homebrew,
                    cache_paths: vec![], // Dynamic path from brew --cache
                    cleanup_command: Some("brew cleanup -s".to_string()),
                    detect_command: Some("brew".to_string()),
                },
                // Cargo/Rust
                PackageManager {
                    tool: DeveloperTool::Cargo,
                    cache_paths: vec![
                        expand_home("~/.cargo/registry/cache"),
                        expand_home("~/.cargo/registry/src"),
                        expand_home("~/.cargo/git/db"),
                    ],
                    cleanup_command: None, // Direct deletion
                    detect_command: Some("cargo".to_string()),
                },
                // Gradle
                PackageManager {
                    tool: DeveloperTool::Gradle,
                    cache_paths: vec![
                        expand_home("~/.gradle/caches"),
                        expand_home("~/.gradle/wrapper/dists"),
                    ],
                    cleanup_command: None, // Direct deletion
                    detect_command: Some("gradle".to_string()),
                },
                // Maven
                PackageManager {
                    tool: DeveloperTool::Maven,
                    cache_paths: vec![expand_home("~/.m2/repository")],
                    cleanup_command: None, // Direct deletion
                    detect_command: Some("mvn".to_string()),
                },
            ],
        }
    }

    /// Get Homebrew cache path
    fn get_homebrew_cache_path() -> Option<PathBuf> {
        Command::new("brew")
            .arg("--cache")
            .output()
            .ok()
            .filter(|o| o.status.success())
            .map(|o| PathBuf::from(String::from_utf8_lossy(&o.stdout).trim()))
    }

    /// Get pnpm store path
    fn get_pnpm_store_path() -> Option<PathBuf> {
        Command::new("pnpm")
            .args(["store", "path"])
            .output()
            .ok()
            .filter(|o| o.status.success())
            .map(|o| PathBuf::from(String::from_utf8_lossy(&o.stdout).trim()))
    }

    /// Scan a specific package manager
    fn scan_manager(&self, manager: &PackageManager) -> Vec<CleanupTarget> {
        if !manager.tool.is_installed() {
            return Vec::new();
        }

        let mut targets = Vec::new();

        // Handle special cases for dynamic paths
        let cache_paths: Vec<PathBuf> = match manager.tool {
            DeveloperTool::Homebrew => {
                if let Some(path) = Self::get_homebrew_cache_path() {
                    vec![path]
                } else {
                    manager.cache_paths.clone()
                }
            }
            DeveloperTool::Pnpm => {
                if let Some(path) = Self::get_pnpm_store_path() {
                    vec![path]
                } else {
                    manager.cache_paths.clone()
                }
            }
            _ => manager.cache_paths.clone(),
        };

        for cache_path in cache_paths {
            // Handle glob patterns
            if cache_path.to_string_lossy().contains('*') {
                if let Some(parent) = cache_path.parent() {
                    if parent.exists() {
                        if let Ok(entries) = fs::read_dir(parent) {
                            for entry in entries.filter_map(|e| e.ok()) {
                                let path = entry.path();
                                if path.is_dir() {
                                    // Check if this matches the pattern
                                    let pattern = cache_path
                                        .file_name()
                                        .and_then(|n| n.to_str())
                                        .unwrap_or("*");

                                    let name = entry.file_name().to_string_lossy().to_string();

                                    if pattern == "*" || glob_match(pattern, &name) {
                                        let size = calculate_dir_size(&path);
                                        if size > 0 {
                                            targets.push(self.create_target(
                                                manager,
                                                path,
                                                format!(
                                                    "{}: {}",
                                                    manager.tool.display_name(),
                                                    name
                                                ),
                                                size,
                                            ));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if cache_path.exists() {
                let size = calculate_dir_size(&cache_path);
                if size > 0 {
                    targets.push(self.create_target(
                        manager,
                        cache_path.clone(),
                        format!("{} Cache", manager.tool.display_name()),
                        size,
                    ));
                }
            }
        }

        targets
    }

    /// Create a cleanup target for a package manager
    fn create_target(
        &self,
        manager: &PackageManager,
        path: PathBuf,
        name: String,
        size: u64,
    ) -> CleanupTarget {
        let cleanup_method = if let Some(ref cmd) = manager.cleanup_command {
            CleanupMethod::Command(cmd.clone())
        } else {
            CleanupMethod::DirectDelete
        };

        CleanupTarget {
            path: Some(path),
            name,
            size,
            safety_level: SafetyLevel::Safe,
            cleanup_method,
            description: Some(format!(
                "{} cache - safely regenerated when needed",
                manager.tool.display_name()
            )),
        }
    }
}

impl DeveloperCleaner for PackageManagerCleaner {
    fn tool(&self) -> DeveloperTool {
        // This cleaner handles multiple tools, return a representative one
        DeveloperTool::Npm
    }

    fn is_installed(&self) -> bool {
        // At least one package manager should be installed
        self.managers.iter().any(|m| m.tool.is_installed())
    }

    fn scan(&self) -> ScanResult {
        let mut targets = Vec::new();
        let mut errors = Vec::new();

        for manager in &self.managers {
            if manager.tool.is_installed() {
                targets.extend(self.scan_manager(manager));
            }
        }

        // Check for potential issues
        if targets.is_empty() && self.is_installed() {
            errors.push("No package manager caches found - they may already be clean".to_string());
        }

        let total_size = targets.iter().map(|t| t.size).sum();

        ScanResult {
            tool: DeveloperTool::Npm, // Representative
            installed: self.is_installed(),
            total_size,
            targets,
            errors,
        }
    }

    fn clean(&self, targets: &[CleanupTarget], dry_run: bool) -> CleanupResult {
        let mut freed_bytes = 0u64;
        let mut items_cleaned = 0usize;
        let mut errors = Vec::new();

        for target in targets {
            let result = match &target.cleanup_method {
                CleanupMethod::DirectDelete => {
                    if let Some(path) = &target.path {
                        if !dry_run {
                            if path.is_dir() {
                                fs::remove_dir_all(path)
                            } else {
                                fs::remove_file(path)
                            }
                            .map_err(|e| CleanupError {
                                target: target.name.clone(),
                                message: e.to_string(),
                            })
                        } else {
                            Ok(())
                        }
                    } else {
                        Err(CleanupError {
                            target: target.name.clone(),
                            message: "No path specified".to_string(),
                        })
                    }
                }
                CleanupMethod::Command(cmd) => {
                    if !dry_run {
                        Command::new("sh")
                            .args(["-c", cmd])
                            .output()
                            .map_err(|e| CleanupError {
                                target: target.name.clone(),
                                message: e.to_string(),
                            })
                            .and_then(|o| {
                                if o.status.success() {
                                    Ok(())
                                } else {
                                    Err(CleanupError {
                                        target: target.name.clone(),
                                        message: String::from_utf8_lossy(&o.stderr).to_string(),
                                    })
                                }
                            })
                    } else {
                        Ok(())
                    }
                }
                CleanupMethod::CommandWithArgs(cmd, args) => {
                    if !dry_run {
                        Command::new(cmd)
                            .args(args)
                            .output()
                            .map_err(|e| CleanupError {
                                target: target.name.clone(),
                                message: e.to_string(),
                            })
                            .and_then(|o| {
                                if o.status.success() {
                                    Ok(())
                                } else {
                                    Err(CleanupError {
                                        target: target.name.clone(),
                                        message: String::from_utf8_lossy(&o.stderr).to_string(),
                                    })
                                }
                            })
                    } else {
                        Ok(())
                    }
                }
            };

            match result {
                Ok(()) => {
                    freed_bytes += target.size;
                    items_cleaned += 1;
                    log::info!(
                        "{}Cleaned: {} ({} bytes)",
                        if dry_run { "[DRY RUN] " } else { "" },
                        target.name,
                        target.size
                    );
                }
                Err(e) => {
                    log::warn!("Failed to clean {}: {}", target.name, e.message);
                    errors.push(e);
                }
            }
        }

        CleanupResult {
            tool: DeveloperTool::Npm,
            freed_bytes,
            items_cleaned,
            dry_run,
            errors,
        }
    }
}

/// Configuration for a package manager
struct PackageManager {
    tool: DeveloperTool,
    cache_paths: Vec<PathBuf>,
    cleanup_command: Option<String>,
    #[allow(dead_code)]
    detect_command: Option<String>,
}

/// Simple glob matching (only handles * wildcards)
fn glob_match(pattern: &str, name: &str) -> bool {
    if pattern == "*" {
        return true;
    }

    let parts: Vec<&str> = pattern.split('*').collect();

    if parts.len() == 1 {
        return pattern == name;
    }

    let mut pos = 0;
    for (i, part) in parts.iter().enumerate() {
        if part.is_empty() {
            continue;
        }

        if let Some(idx) = name[pos..].find(part) {
            if i == 0 && idx != 0 {
                return false; // First part must match at start
            }
            pos += idx + part.len();
        } else {
            return false;
        }
    }

    // If pattern ends with *, any suffix is ok
    // If not, name must end at pos
    pattern.ends_with('*') || pos == name.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_package_manager_cleaner_creation() {
        let cleaner = PackageManagerCleaner::new();
        assert!(!cleaner.managers.is_empty());
    }

    #[test]
    fn test_glob_match() {
        assert!(glob_match("*", "anything"));
        assert!(glob_match("test*", "testing"));
        assert!(glob_match("*test", "mytest"));
        assert!(glob_match("*test*", "mytesting"));
        assert!(!glob_match("test*", "nottest"));
        assert!(!glob_match("test", "testing"));
    }

    #[test]
    fn test_manager_has_all_expected_tools() {
        let cleaner = PackageManagerCleaner::new();
        let tools: Vec<_> = cleaner.managers.iter().map(|m| m.tool).collect();

        assert!(tools.contains(&DeveloperTool::CocoaPods));
        assert!(tools.contains(&DeveloperTool::Npm));
        assert!(tools.contains(&DeveloperTool::Homebrew));
        assert!(tools.contains(&DeveloperTool::Cargo));
    }

    // AC-04: Detect installed package managers
    #[test]
    fn test_all_package_managers_have_detection() {
        let cleaner = PackageManagerCleaner::new();

        // Verify each manager can be detected without panicking
        for manager in &cleaner.managers {
            // This should not panic regardless of installation status
            let _installed = manager.tool.is_installed();
        }
    }

    // AC-04: Comprehensive tool detection test
    #[test]
    fn test_detect_all_supported_package_managers() {
        let cleaner = PackageManagerCleaner::new();
        let tools: Vec<_> = cleaner.managers.iter().map(|m| m.tool).collect();

        // Verify all required package managers from issue #35 are included
        let required_tools = [
            DeveloperTool::CocoaPods,
            DeveloperTool::SwiftPackageManager,
            DeveloperTool::Carthage,
            DeveloperTool::Npm,
            DeveloperTool::Yarn,
            DeveloperTool::Pnpm,
            DeveloperTool::Pip,
            DeveloperTool::Homebrew,
            DeveloperTool::Cargo,
            DeveloperTool::Gradle,
        ];

        for tool in required_tools {
            assert!(tools.contains(&tool), "Missing required tool: {:?}", tool);
        }
    }

    // AC-09: Handle missing tools gracefully
    #[test]
    fn test_scan_handles_missing_tools_gracefully() {
        let cleaner = PackageManagerCleaner::new();

        // Scan should complete without panicking even if some tools are not installed
        let result = cleaner.scan();

        // Result should be valid regardless of which tools are installed
        assert!(result.targets.len() <= 1000); // Reasonable upper bound
        assert!(result.errors.len() <= 100); // Reasonable upper bound
    }

    // AC-09: Clean handles missing tools gracefully
    #[test]
    fn test_clean_dry_run_handles_empty_targets() {
        let cleaner = PackageManagerCleaner::new();

        // Clean with empty targets should not panic
        let result = cleaner.clean(&[], true);

        assert_eq!(result.freed_bytes, 0);
        assert_eq!(result.items_cleaned, 0);
        assert!(result.dry_run);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_scan_returns_valid_result_structure() {
        let cleaner = PackageManagerCleaner::new();
        let result = cleaner.scan();

        // Verify result structure
        assert_eq!(result.tool, DeveloperTool::Npm); // Representative tool

        // total_size should match sum of target sizes
        let calculated_total: u64 = result.targets.iter().map(|t| t.size).sum();
        assert_eq!(result.total_size, calculated_total);
    }

    #[test]
    fn test_cleanup_target_has_valid_method() {
        let cleaner = PackageManagerCleaner::new();

        for manager in &cleaner.managers {
            // Create a mock target
            if !manager.cache_paths.is_empty() {
                let path = manager.cache_paths[0].clone();
                let target = cleaner.create_target(manager, path, "Test Target".to_string(), 1024);

                // Verify cleanup method matches configuration
                match (&manager.cleanup_command, &target.cleanup_method) {
                    (Some(cmd), CleanupMethod::Command(target_cmd)) => {
                        assert_eq!(cmd, target_cmd);
                    }
                    (None, CleanupMethod::DirectDelete) => {
                        // Expected for direct deletion tools
                    }
                    _ => panic!("Unexpected cleanup method mismatch"),
                }
            }
        }
    }

    #[test]
    fn test_cache_paths_are_expanded() {
        let cleaner = PackageManagerCleaner::new();

        for manager in &cleaner.managers {
            for path in &manager.cache_paths {
                // Paths should not contain ~ after expansion
                let path_str = path.to_string_lossy();
                assert!(
                    !path_str.starts_with("~/"),
                    "Path not expanded: {}",
                    path_str
                );
            }
        }
    }

    #[test]
    fn test_is_installed_returns_boolean() {
        let cleaner = PackageManagerCleaner::new();

        // is_installed should return true if at least one manager is installed
        // This test just ensures no panic occurs
        let _is_installed = cleaner.is_installed();
    }

    #[test]
    fn test_scan_manager_with_nonexistent_path() {
        let manager = PackageManager {
            tool: DeveloperTool::Npm,
            cache_paths: vec![PathBuf::from("/nonexistent/path/that/does/not/exist")],
            cleanup_command: Some("npm cache clean --force".to_string()),
            detect_command: Some("npm".to_string()),
        };

        let cleaner = PackageManagerCleaner::new();

        // Scanning a nonexistent path should return empty, not panic
        let targets = cleaner.scan_manager(&manager);
        assert!(targets.is_empty());
    }

    #[test]
    fn test_homebrew_cache_path_detection() {
        // This should not panic even if Homebrew is not installed
        let path = PackageManagerCleaner::get_homebrew_cache_path();
        // path is Option<PathBuf>, either Some or None is valid
        if let Some(p) = path {
            assert!(!p.to_string_lossy().is_empty());
        }
    }

    #[test]
    fn test_pnpm_store_path_detection() {
        // This should not panic even if pnpm is not installed
        let path = PackageManagerCleaner::get_pnpm_store_path();
        // path is Option<PathBuf>, either Some or None is valid
        if let Some(p) = path {
            assert!(!p.to_string_lossy().is_empty());
        }
    }
}
