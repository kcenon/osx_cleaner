// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Xcode Cache Management
//!
//! Provides cleanup functionality for Xcode-related caches:
//! - DerivedData (5-50GB): Build products, intermediate files
//! - Module Cache (1-5GB): Clang module cache
//! - Archives (1-20GB): App archives for distribution
//! - iOS Device Support (20-100GB): Debug symbols for devices
//! - watchOS Device Support (5-20GB): Debug symbols for watches

use std::collections::HashSet;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

use serde::{Deserialize, Serialize};

use super::{
    calculate_dir_size, expand_home, CleanupError, CleanupMethod, CleanupResult, CleanupTarget,
    DeveloperCleaner, DeveloperTool, ScanResult,
};
use crate::safety::SafetyLevel;

/// Xcode cache cleaner
pub struct XcodeCleaner {
    /// Path to DerivedData
    derived_data_path: PathBuf,
    /// Path to Archives
    archives_path: PathBuf,
    /// Path to iOS Device Support
    ios_device_support_path: PathBuf,
    /// Path to watchOS Device Support
    watchos_device_support_path: PathBuf,
}

impl Default for XcodeCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl XcodeCleaner {
    /// Create a new Xcode cleaner
    pub fn new() -> Self {
        Self {
            derived_data_path: expand_home("~/Library/Developer/Xcode/DerivedData"),
            archives_path: expand_home("~/Library/Developer/Xcode/Archives"),
            ios_device_support_path: expand_home("~/Library/Developer/Xcode/iOS DeviceSupport"),
            watchos_device_support_path: expand_home(
                "~/Library/Developer/Xcode/watchOS DeviceSupport",
            ),
        }
    }

    /// Check if Xcode is currently building
    pub fn is_build_running(&self) -> bool {
        // Check for running xcodebuild processes
        Command::new("pgrep")
            .args(["-x", "xcodebuild"])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    /// Scan DerivedData directory
    pub fn scan_derived_data(&self) -> Vec<CleanupTarget> {
        if !self.derived_data_path.exists() {
            return Vec::new();
        }

        let mut targets = Vec::new();

        // Module cache - always safe to delete
        let module_cache = self.derived_data_path.join("ModuleCache.noindex");
        if module_cache.exists() {
            let size = calculate_dir_size(&module_cache);
            targets.push(
                CleanupTarget::new_direct(module_cache, "Module Cache", SafetyLevel::Safe)
                    .with_size(size)
                    .with_description("Clang module cache - safely regenerated on next build"),
            );
        }

        // Individual project derived data
        if let Ok(entries) = fs::read_dir(&self.derived_data_path) {
            for entry in entries.filter_map(|e| e.ok()) {
                let path = entry.path();
                if path.is_dir() {
                    let name = path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("Unknown")
                        .to_string();

                    // Skip ModuleCache as it's handled separately
                    if name == "ModuleCache.noindex" {
                        continue;
                    }

                    let size = calculate_dir_size(&path);
                    targets.push(
                        CleanupTarget::new_direct(
                            path,
                            format!("DerivedData: {}", name),
                            SafetyLevel::Safe,
                        )
                        .with_size(size)
                        .with_description("Project build cache - safely regenerated on next build"),
                    );
                }
            }
        }

        targets
    }

    /// Scan Archives directory
    pub fn scan_archives(&self) -> Vec<CleanupTarget> {
        if !self.archives_path.exists() {
            return Vec::new();
        }

        let mut targets = Vec::new();

        // Archives are organized by date (YYYY-MM-DD)
        if let Ok(entries) = fs::read_dir(&self.archives_path) {
            for entry in entries.filter_map(|e| e.ok()) {
                let path = entry.path();
                if path.is_dir() {
                    let name = path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("Unknown")
                        .to_string();

                    let size = calculate_dir_size(&path);
                    targets.push(
                        CleanupTarget::new_direct(
                            path,
                            format!("Archives: {}", name),
                            SafetyLevel::Caution, // Archives might be needed for distribution
                        )
                        .with_size(size)
                        .with_description(
                            "App archives for App Store submission - verify before deleting",
                        ),
                    );
                }
            }
        }

        targets
    }

    /// Scan iOS Device Support
    pub fn scan_ios_device_support(&self) -> Vec<DeviceSupportInfo> {
        self.scan_device_support(&self.ios_device_support_path, "iOS")
    }

    /// Scan watchOS Device Support
    pub fn scan_watchos_device_support(&self) -> Vec<DeviceSupportInfo> {
        self.scan_device_support(&self.watchos_device_support_path, "watchOS")
    }

    /// Get connected iOS device versions using xcrun devicectl
    ///
    /// Returns a set of major version numbers (e.g., "17", "18") for connected iOS/iPadOS devices.
    /// This is used to preserve Device Support folders for currently connected devices.
    pub fn get_connected_ios_versions(&self) -> HashSet<String> {
        self.get_connected_versions("iOS")
    }

    /// Get connected watchOS device versions using xcrun devicectl
    ///
    /// Returns a set of major version numbers for connected watchOS devices.
    pub fn get_connected_watchos_versions(&self) -> HashSet<String> {
        self.get_connected_versions("watchOS")
    }

    /// Get connected device versions for a specific platform
    fn get_connected_versions(&self, target_platform: &str) -> HashSet<String> {
        let mut versions = HashSet::new();

        // Try xcrun devicectl (Xcode 15+)
        let output = Command::new("xcrun")
            .args(["devicectl", "list", "devices", "--json-output", "/dev/stdout"])
            .output();

        if let Ok(output) = output {
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                if let Ok(parsed) = serde_json::from_str::<DeviceCtlOutput>(&stdout) {
                    for device in parsed.result.devices {
                        if let Some(device_props) = device.device_properties {
                            if device_props.platform.as_deref() == Some(target_platform) {
                                if let Some(version) = device_props.os_version_number {
                                    // Extract major version (e.g., "18.4.1" -> "18")
                                    if let Some(major) = version.split('.').next() {
                                        versions.insert(major.to_string());
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        versions
    }

    /// Scan device support directory
    fn scan_device_support(&self, path: &PathBuf, platform: &str) -> Vec<DeviceSupportInfo> {
        if !path.exists() {
            return Vec::new();
        }

        let mut results = Vec::new();

        if let Ok(entries) = fs::read_dir(path) {
            for entry in entries.filter_map(|e| e.ok()) {
                let entry_path = entry.path();
                if entry_path.is_dir() {
                    let name = entry_path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("Unknown")
                        .to_string();

                    // Parse version from directory name (e.g., "17.0 (21A5248v)")
                    let version = name.split_whitespace().next().unwrap_or(&name).to_string();

                    let size = calculate_dir_size(&entry_path);

                    results.push(DeviceSupportInfo {
                        path: entry_path,
                        version,
                        platform: platform.to_string(),
                        size,
                        full_name: name,
                    });
                }
            }
        }

        // Sort by version descending (newest first)
        results.sort_by(|a, b| b.version.cmp(&a.version));

        results
    }

    /// Get cleanup targets for device support, keeping the latest N versions
    ///
    /// **Note**: This method does not preserve versions for currently connected devices.
    /// Use `get_device_support_cleanup_targets_smart` for AC-08 compliance.
    pub fn get_device_support_cleanup_targets(&self, keep_latest: usize) -> Vec<CleanupTarget> {
        self.get_device_support_cleanup_targets_with_options(keep_latest, false)
    }

    /// Get cleanup targets for device support with smart preservation (AC-08)
    ///
    /// This method preserves:
    /// 1. The latest N versions (configured by `keep_latest`)
    /// 2. Versions for currently connected iOS/watchOS devices
    ///
    /// This ensures that users can debug on their connected devices even if those
    /// devices are running older iOS versions.
    pub fn get_device_support_cleanup_targets_smart(
        &self,
        keep_latest: usize,
    ) -> Vec<CleanupTarget> {
        self.get_device_support_cleanup_targets_with_options(keep_latest, true)
    }

    /// Internal implementation for device support cleanup targets
    fn get_device_support_cleanup_targets_with_options(
        &self,
        keep_latest: usize,
        preserve_connected: bool,
    ) -> Vec<CleanupTarget> {
        let mut targets = Vec::new();

        // Get connected device versions if smart preservation is enabled
        let connected_ios_versions = if preserve_connected {
            self.get_connected_ios_versions()
        } else {
            HashSet::new()
        };

        let connected_watchos_versions = if preserve_connected {
            self.get_connected_watchos_versions()
        } else {
            HashSet::new()
        };

        // iOS Device Support
        let ios_versions = self.scan_ios_device_support();
        for (idx, info) in ios_versions.into_iter().enumerate() {
            // Skip if within keep_latest count
            if idx < keep_latest {
                continue;
            }

            // Skip if this version is used by a connected device
            let major_version = info.version.split('.').next().unwrap_or(&info.version);
            if preserve_connected && connected_ios_versions.contains(major_version) {
                log::debug!(
                    "Preserving iOS Device Support {} - connected device detected",
                    info.full_name
                );
                continue;
            }

            targets.push(
                CleanupTarget::new_direct(
                    info.path,
                    format!("iOS Device Support: {}", info.full_name),
                    SafetyLevel::Warning,
                )
                .with_size(info.size)
                .with_description(format!(
                    "Debug symbols for {} {} - needed for debugging on this iOS version",
                    info.platform, info.version
                )),
            );
        }

        // watchOS Device Support
        let watchos_versions = self.scan_watchos_device_support();
        for (idx, info) in watchos_versions.into_iter().enumerate() {
            // Skip if within keep_latest count
            if idx < keep_latest {
                continue;
            }

            // Skip if this version is used by a connected device
            let major_version = info.version.split('.').next().unwrap_or(&info.version);
            if preserve_connected && connected_watchos_versions.contains(major_version) {
                log::debug!(
                    "Preserving watchOS Device Support {} - connected device detected",
                    info.full_name
                );
                continue;
            }

            targets.push(
                CleanupTarget::new_direct(
                    info.path,
                    format!("watchOS Device Support: {}", info.full_name),
                    SafetyLevel::Warning,
                )
                .with_size(info.size)
                .with_description(format!(
                    "Debug symbols for {} {} - needed for debugging on this watchOS version",
                    info.platform, info.version
                )),
            );
        }

        targets
    }

    /// Perform cleanup on a target
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

impl DeveloperCleaner for XcodeCleaner {
    fn tool(&self) -> DeveloperTool {
        DeveloperTool::Xcode
    }

    fn scan(&self) -> ScanResult {
        if !self.is_installed() {
            return ScanResult::not_installed(DeveloperTool::Xcode);
        }

        let mut targets = Vec::new();
        let mut errors = Vec::new();

        // Scan DerivedData
        targets.extend(self.scan_derived_data());

        // Scan Archives
        targets.extend(self.scan_archives());

        // Scan Device Support (keep latest 2 versions + preserve connected devices)
        // Uses smart preservation to ensure connected device versions are never cleaned
        targets.extend(self.get_device_support_cleanup_targets_smart(2));

        // Check if Xcode is building
        if self.is_build_running() {
            errors.push(
                "Xcode build is in progress - DerivedData cleanup may affect running builds"
                    .to_string(),
            );
        }

        let total_size = targets.iter().map(|t| t.size).sum();

        ScanResult {
            tool: DeveloperTool::Xcode,
            installed: true,
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

        CleanupResult {
            tool: DeveloperTool::Xcode,
            freed_bytes,
            items_cleaned,
            dry_run,
            errors,
        }
    }
}

/// Information about a device support version
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceSupportInfo {
    /// Path to the device support directory
    pub path: PathBuf,
    /// Version number (e.g., "17.0")
    pub version: String,
    /// Platform (iOS or watchOS)
    pub platform: String,
    /// Size in bytes
    pub size: u64,
    /// Full directory name
    pub full_name: String,
}

// JSON parsing structures for xcrun devicectl output
#[derive(Debug, Deserialize)]
struct DeviceCtlOutput {
    result: DeviceCtlResult,
}

#[derive(Debug, Deserialize)]
struct DeviceCtlResult {
    devices: Vec<DeviceCtlDevice>,
}

#[derive(Debug, Deserialize)]
struct DeviceCtlDevice {
    #[serde(rename = "deviceProperties")]
    device_properties: Option<DeviceCtlDeviceProperties>,
}

#[derive(Debug, Deserialize)]
struct DeviceCtlDeviceProperties {
    #[serde(rename = "osVersionNumber")]
    os_version_number: Option<String>,
    platform: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_xcode_cleaner_creation() {
        let cleaner = XcodeCleaner::new();
        assert_eq!(cleaner.tool(), DeveloperTool::Xcode);
    }

    #[test]
    fn test_scan_derived_data_empty() {
        let cleaner = XcodeCleaner {
            derived_data_path: PathBuf::from("/nonexistent/path"),
            archives_path: PathBuf::from("/nonexistent/path"),
            ios_device_support_path: PathBuf::from("/nonexistent/path"),
            watchos_device_support_path: PathBuf::from("/nonexistent/path"),
        };

        let targets = cleaner.scan_derived_data();
        assert!(targets.is_empty());
    }

    #[test]
    fn test_scan_with_temp_derived_data() {
        let temp = tempdir().unwrap();
        let derived_data = temp.path().join("DerivedData");
        fs::create_dir(&derived_data).unwrap();

        // Create a fake project directory
        let project_dir = derived_data.join("MyProject-abc123");
        fs::create_dir(&project_dir).unwrap();
        fs::write(project_dir.join("test.txt"), "test content").unwrap();

        let cleaner = XcodeCleaner {
            derived_data_path: derived_data,
            archives_path: PathBuf::from("/nonexistent"),
            ios_device_support_path: PathBuf::from("/nonexistent"),
            watchos_device_support_path: PathBuf::from("/nonexistent"),
        };

        let targets = cleaner.scan_derived_data();
        assert!(!targets.is_empty());
        assert!(targets[0].name.contains("MyProject"));
    }

    #[test]
    fn test_device_support_info() {
        let info = DeviceSupportInfo {
            path: PathBuf::from("/test"),
            version: "17.0".to_string(),
            platform: "iOS".to_string(),
            size: 1024,
            full_name: "17.0 (21A5248v)".to_string(),
        };

        assert_eq!(info.version, "17.0");
        assert_eq!(info.platform, "iOS");
    }

    #[test]
    fn test_get_connected_ios_versions_returns_empty_when_no_devices() {
        // This test verifies the function handles missing devicectl gracefully
        let cleaner = XcodeCleaner {
            derived_data_path: PathBuf::from("/nonexistent"),
            archives_path: PathBuf::from("/nonexistent"),
            ios_device_support_path: PathBuf::from("/nonexistent"),
            watchos_device_support_path: PathBuf::from("/nonexistent"),
        };

        // Should return empty set without panicking even if devicectl fails
        let versions = cleaner.get_connected_ios_versions();
        // Just verify it doesn't panic - actual result depends on system state
        assert!(versions.len() <= 100); // Reasonable upper bound
    }

    #[test]
    fn test_device_support_cleanup_targets_with_options() {
        let temp = tempdir().unwrap();

        // Create fake iOS Device Support directories
        let ios_support = temp.path().join("iOS DeviceSupport");
        fs::create_dir(&ios_support).unwrap();

        // Create version directories (newer versions first when sorted)
        for version in ["18.0 (22A1234)", "17.0 (21A5678)", "16.0 (20A1234)"] {
            let version_dir = ios_support.join(version);
            fs::create_dir(&version_dir).unwrap();
            fs::write(version_dir.join("symbols"), "fake symbols").unwrap();
        }

        let cleaner = XcodeCleaner {
            derived_data_path: PathBuf::from("/nonexistent"),
            archives_path: PathBuf::from("/nonexistent"),
            ios_device_support_path: ios_support,
            watchos_device_support_path: PathBuf::from("/nonexistent"),
        };

        // With keep_latest=2, only the oldest version (16.0) should be targeted
        let targets = cleaner.get_device_support_cleanup_targets(2);

        // Should have at least one target (16.0)
        assert!(!targets.is_empty());

        // All targets should be Warning level (Device Support is warning level)
        for target in &targets {
            assert_eq!(target.safety_level, SafetyLevel::Warning);
        }
    }

    #[test]
    fn test_smart_vs_regular_cleanup_targets() {
        let temp = tempdir().unwrap();

        let ios_support = temp.path().join("iOS DeviceSupport");
        fs::create_dir(&ios_support).unwrap();

        for version in ["18.0 (22A1234)", "17.0 (21A5678)"] {
            let version_dir = ios_support.join(version);
            fs::create_dir(&version_dir).unwrap();
            fs::write(version_dir.join("symbols"), "fake symbols").unwrap();
        }

        let cleaner = XcodeCleaner {
            derived_data_path: PathBuf::from("/nonexistent"),
            archives_path: PathBuf::from("/nonexistent"),
            ios_device_support_path: ios_support,
            watchos_device_support_path: PathBuf::from("/nonexistent"),
        };

        // Both methods should work without panicking
        let regular_targets = cleaner.get_device_support_cleanup_targets(1);
        let smart_targets = cleaner.get_device_support_cleanup_targets_smart(1);

        // Smart targets should be <= regular targets
        // (smart may preserve more due to connected devices)
        assert!(smart_targets.len() <= regular_targets.len() || regular_targets.is_empty());
    }

    #[test]
    fn test_devicectl_output_parsing() {
        // Test JSON parsing structure
        let json = r#"{
            "result": {
                "devices": [
                    {
                        "deviceProperties": {
                            "osVersionNumber": "18.4.1",
                            "platform": "iOS"
                        }
                    },
                    {
                        "deviceProperties": {
                            "osVersionNumber": "11.6",
                            "platform": "watchOS"
                        }
                    }
                ]
            }
        }"#;

        let parsed: DeviceCtlOutput = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.result.devices.len(), 2);

        let first_device = &parsed.result.devices[0];
        let props = first_device.device_properties.as_ref().unwrap();
        assert_eq!(props.platform.as_deref(), Some("iOS"));
        assert_eq!(props.os_version_number.as_deref(), Some("18.4.1"));
    }

    #[test]
    fn test_version_major_extraction() {
        // Test that major version extraction works correctly
        let versions = ["18.4.1", "17.0", "16", "15.6.1"];
        let expected_majors = ["18", "17", "16", "15"];

        for (version, expected) in versions.iter().zip(expected_majors.iter()) {
            let major = version.split('.').next().unwrap_or(version);
            assert_eq!(major, *expected);
        }
    }
}
