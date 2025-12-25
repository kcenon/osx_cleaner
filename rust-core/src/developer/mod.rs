// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Developer Tool Cache Management Module
//!
//! Provides cleanup functionality for developer tools including:
//! - Xcode (DerivedData, Device Support, Archives)
//! - iOS Simulators
//! - Package Managers (npm, yarn, pip, brew, etc.)
//! - Docker (images, containers, volumes, build cache)
//!
//! This module targets the largest space consumers on developer machines,
//! potentially saving 50-150GB of disk space.

pub mod docker;
pub mod packages;
pub mod simulator;
pub mod xcode;

use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;

use crate::safety::SafetyLevel;

// Re-export main types for convenience
pub use docker::DockerCleaner;
pub use packages::PackageManagerCleaner;
pub use simulator::SimulatorCleaner;
pub use xcode::XcodeCleaner;

/// Supported developer tools
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum DeveloperTool {
    Xcode,
    XcodeCommandLineTools,
    Simulator,
    CocoaPods,
    SwiftPackageManager,
    Carthage,
    Npm,
    Yarn,
    Pnpm,
    Pip,
    Homebrew,
    Cargo,
    Gradle,
    Maven,
    Docker,
}

impl DeveloperTool {
    /// Get the display name for this tool
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Xcode => "Xcode",
            Self::XcodeCommandLineTools => "Xcode Command Line Tools",
            Self::Simulator => "iOS Simulator",
            Self::CocoaPods => "CocoaPods",
            Self::SwiftPackageManager => "Swift Package Manager",
            Self::Carthage => "Carthage",
            Self::Npm => "npm",
            Self::Yarn => "Yarn",
            Self::Pnpm => "pnpm",
            Self::Pip => "pip",
            Self::Homebrew => "Homebrew",
            Self::Cargo => "Cargo (Rust)",
            Self::Gradle => "Gradle",
            Self::Maven => "Maven",
            Self::Docker => "Docker",
        }
    }

    /// Check if this tool is installed on the system
    pub fn is_installed(&self) -> bool {
        match self {
            Self::Xcode => is_xcode_installed(),
            Self::XcodeCommandLineTools => is_command_available("xcode-select"),
            Self::Simulator => is_command_available("xcrun") && is_xcode_installed(),
            Self::CocoaPods => is_command_available("pod"),
            Self::SwiftPackageManager => is_command_available("swift"),
            Self::Carthage => is_command_available("carthage"),
            Self::Npm => is_command_available("npm"),
            Self::Yarn => is_command_available("yarn"),
            Self::Pnpm => is_command_available("pnpm"),
            Self::Pip => is_command_available("pip3") || is_command_available("pip"),
            Self::Homebrew => is_command_available("brew"),
            Self::Cargo => is_command_available("cargo"),
            Self::Gradle => is_command_available("gradle") || gradle_wrapper_exists(),
            Self::Maven => is_command_available("mvn"),
            Self::Docker => is_docker_available(),
        }
    }
}

/// Method to clean up a target
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CleanupMethod {
    /// Direct file/directory deletion
    DirectDelete,
    /// Execute a shell command
    Command(String),
    /// Execute a command with arguments
    CommandWithArgs(String, Vec<String>),
}

/// A target for cleanup operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanupTarget {
    /// Path to the target (may be None for command-based cleanup)
    pub path: Option<PathBuf>,
    /// Display name for the target
    pub name: String,
    /// Calculated size in bytes
    pub size: u64,
    /// Safety level for this target
    pub safety_level: SafetyLevel,
    /// Method to clean up this target
    pub cleanup_method: CleanupMethod,
    /// Additional description or warning
    pub description: Option<String>,
}

impl CleanupTarget {
    /// Create a new cleanup target with direct deletion
    pub fn new_direct(path: PathBuf, name: impl Into<String>, safety_level: SafetyLevel) -> Self {
        Self {
            path: Some(path),
            name: name.into(),
            size: 0,
            safety_level,
            cleanup_method: CleanupMethod::DirectDelete,
            description: None,
        }
    }

    /// Create a new cleanup target with command execution
    pub fn new_command(
        name: impl Into<String>,
        command: impl Into<String>,
        safety_level: SafetyLevel,
    ) -> Self {
        Self {
            path: None,
            name: name.into(),
            size: 0,
            safety_level,
            cleanup_method: CleanupMethod::Command(command.into()),
            description: None,
        }
    }

    /// Set the size of this target
    pub fn with_size(mut self, size: u64) -> Self {
        self.size = size;
        self
    }

    /// Set a description for this target
    pub fn with_description(mut self, description: impl Into<String>) -> Self {
        self.description = Some(description.into());
        self
    }
}

/// Result of a scan operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanResult {
    /// Tool that was scanned
    pub tool: DeveloperTool,
    /// Whether the tool is installed
    pub installed: bool,
    /// Total size of cleanable items
    pub total_size: u64,
    /// Individual cleanup targets
    pub targets: Vec<CleanupTarget>,
    /// Errors encountered during scan
    pub errors: Vec<String>,
}

impl ScanResult {
    /// Create a new scan result for a tool that is not installed
    pub fn not_installed(tool: DeveloperTool) -> Self {
        Self {
            tool,
            installed: false,
            total_size: 0,
            targets: Vec::new(),
            errors: Vec::new(),
        }
    }
}

/// Result of a cleanup operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanupResult {
    /// Tool that was cleaned
    pub tool: DeveloperTool,
    /// Space freed in bytes
    pub freed_bytes: u64,
    /// Number of items cleaned
    pub items_cleaned: usize,
    /// Whether this was a dry run
    pub dry_run: bool,
    /// Errors encountered during cleanup
    pub errors: Vec<CleanupError>,
}

/// Error during cleanup operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanupError {
    /// Target that failed
    pub target: String,
    /// Error message
    pub message: String,
}

/// Trait for developer tool cleaners
pub trait DeveloperCleaner: Send + Sync {
    /// Get the tool this cleaner handles
    fn tool(&self) -> DeveloperTool;

    /// Check if the tool is installed
    fn is_installed(&self) -> bool {
        self.tool().is_installed()
    }

    /// Scan for cleanup targets
    fn scan(&self) -> ScanResult;

    /// Clean the specified targets
    fn clean(&self, targets: &[CleanupTarget], dry_run: bool) -> CleanupResult;
}

/// Master developer cleaner that aggregates all tool cleaners
pub struct DeveloperCleanerManager {
    xcode: XcodeCleaner,
    simulator: SimulatorCleaner,
    packages: PackageManagerCleaner,
    docker: DockerCleaner,
}

impl Default for DeveloperCleanerManager {
    fn default() -> Self {
        Self::new()
    }
}

impl DeveloperCleanerManager {
    /// Create a new developer cleaner manager
    pub fn new() -> Self {
        Self {
            xcode: XcodeCleaner::new(),
            simulator: SimulatorCleaner::new(),
            packages: PackageManagerCleaner::new(),
            docker: DockerCleaner::new(),
        }
    }

    /// Detect all installed developer tools
    pub fn detect_tools(&self) -> Vec<DeveloperTool> {
        [
            DeveloperTool::Xcode,
            DeveloperTool::XcodeCommandLineTools,
            DeveloperTool::Simulator,
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
            DeveloperTool::Maven,
            DeveloperTool::Docker,
        ]
        .into_iter()
        .filter(|t| t.is_installed())
        .collect()
    }

    /// Scan all installed tools for cleanup opportunities
    pub fn scan_all(&self) -> Vec<ScanResult> {
        let cleaners: Vec<&dyn DeveloperCleaner> =
            vec![&self.xcode, &self.simulator, &self.packages, &self.docker];

        cleaners.par_iter().map(|c| c.scan()).collect()
    }

    /// Get the Xcode cleaner
    pub fn xcode(&self) -> &XcodeCleaner {
        &self.xcode
    }

    /// Get the simulator cleaner
    pub fn simulator(&self) -> &SimulatorCleaner {
        &self.simulator
    }

    /// Get the package manager cleaner
    pub fn packages(&self) -> &PackageManagerCleaner {
        &self.packages
    }

    /// Get the Docker cleaner
    pub fn docker(&self) -> &DockerCleaner {
        &self.docker
    }
}

// Utility functions for tool detection

/// Check if a command is available in PATH
fn is_command_available(command: &str) -> bool {
    Command::new("which")
        .arg(command)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Check if Xcode is installed
fn is_xcode_installed() -> bool {
    std::path::Path::new("/Applications/Xcode.app").exists()
        || std::path::Path::new("/Applications/Xcode-beta.app").exists()
}

/// Check if gradle wrapper exists in common locations
fn gradle_wrapper_exists() -> bool {
    // Check home directory for .gradle
    if let Some(home) = dirs::home_dir() {
        return home.join(".gradle").exists();
    }
    false
}

/// Check if Docker is available and running
fn is_docker_available() -> bool {
    Command::new("docker")
        .arg("info")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Calculate the total size of a directory
pub fn calculate_dir_size(path: &std::path::Path) -> u64 {
    if !path.exists() {
        return 0;
    }

    walkdir::WalkDir::new(path)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .filter_map(|e| e.metadata().ok())
        .map(|m| m.len())
        .sum()
}

/// Calculate directory sizes in parallel
pub fn calculate_sizes_parallel(paths: &[PathBuf]) -> Vec<(PathBuf, u64)> {
    paths
        .par_iter()
        .map(|p| (p.clone(), calculate_dir_size(p)))
        .collect()
}

/// Format bytes as human-readable string
pub fn format_size(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;

    if bytes >= GB {
        format!("{:.2} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.2} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.2} KB", bytes as f64 / KB as f64)
    } else {
        format!("{} bytes", bytes)
    }
}

/// Expand ~ to home directory
pub fn expand_home(path: &str) -> PathBuf {
    if path.starts_with("~/") {
        if let Some(home) = dirs::home_dir() {
            return home.join(&path[2..]);
        }
    }
    PathBuf::from(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_size() {
        assert_eq!(format_size(500), "500 bytes");
        assert_eq!(format_size(1024), "1.00 KB");
        assert_eq!(format_size(1024 * 1024), "1.00 MB");
        assert_eq!(format_size(1024 * 1024 * 1024), "1.00 GB");
        assert_eq!(format_size(1536 * 1024 * 1024), "1.50 GB");
    }

    #[test]
    fn test_expand_home() {
        let path = expand_home("~/Library/Caches");
        assert!(path.to_string_lossy().contains("Library/Caches"));
        assert!(!path.to_string_lossy().starts_with("~"));
    }

    #[test]
    fn test_developer_tool_display_names() {
        assert_eq!(DeveloperTool::Xcode.display_name(), "Xcode");
        assert_eq!(DeveloperTool::Docker.display_name(), "Docker");
        assert_eq!(DeveloperTool::Npm.display_name(), "npm");
    }

    #[test]
    fn test_cleanup_target_builder() {
        let target =
            CleanupTarget::new_direct(PathBuf::from("/tmp/test"), "Test Target", SafetyLevel::Safe)
                .with_size(1024)
                .with_description("A test target");

        assert_eq!(target.name, "Test Target");
        assert_eq!(target.size, 1024);
        assert!(target.description.is_some());
    }

    #[test]
    fn test_scan_result_not_installed() {
        let result = ScanResult::not_installed(DeveloperTool::Docker);
        assert!(!result.installed);
        assert_eq!(result.total_size, 0);
        assert!(result.targets.is_empty());
    }
}
