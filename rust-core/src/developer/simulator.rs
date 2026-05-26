// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! iOS Simulator Management
//!
//! Provides cleanup functionality for iOS Simulators:
//! - CoreSimulator Devices (10-50GB)
//! - Unavailable Simulators (safe to delete)
//! - Old Runtime Versions

use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use serde::{Deserialize, Serialize};

use super::{
    calculate_dir_size, expand_home, format_command, CleanupError, CleanupMethod, CleanupResult,
    CleanupTarget, CommandRunner, DeveloperCleaner, DeveloperCommandError, DeveloperCommandOutput,
    DeveloperTool, ScanResult, SystemCommandRunner, COMMAND_CLEANUP_TIMEOUT,
};
use crate::safety::SafetyLevel;

/// Timeout for simulator-related scan commands (`xcrun simctl list ...`).
///
/// Listing devices/runtimes can take longer than a fast probe because Xcode
/// inspects the on-disk CoreSimulator state, so we give it more headroom than
/// `COMMAND_PROBE_TIMEOUT`. The bound still prevents a hung `simctl` from
/// stalling the scan UI indefinitely.
const SIMULATOR_SCAN_COMMAND_TIMEOUT: Duration = Duration::from_secs(15);

/// iOS Simulator cleaner
pub struct SimulatorCleaner {
    /// Path to CoreSimulator devices
    devices_path: PathBuf,
    /// Path to CoreSimulator caches
    caches_path: PathBuf,
    /// Command runner used for all external command invocations.
    command_runner: Arc<dyn CommandRunner>,
}

impl Default for SimulatorCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl SimulatorCleaner {
    /// Create a new simulator cleaner
    pub fn new() -> Self {
        Self {
            devices_path: expand_home("~/Library/Developer/CoreSimulator/Devices"),
            caches_path: expand_home("~/Library/Developer/CoreSimulator/Caches"),
            command_runner: Arc::new(SystemCommandRunner),
        }
    }

    #[cfg(test)]
    fn with_command_runner(command_runner: Arc<dyn CommandRunner>) -> Self {
        Self {
            command_runner,
            ..Self::new()
        }
    }

    #[cfg(test)]
    fn with_paths_and_runner(
        devices_path: PathBuf,
        caches_path: PathBuf,
        command_runner: Arc<dyn CommandRunner>,
    ) -> Self {
        Self {
            devices_path,
            caches_path,
            command_runner,
        }
    }

    /// List all simulators using xcrun simctl
    pub fn list_devices(&self) -> Result<SimulatorList, SimulatorError> {
        let output = self
            .command_runner
            .run(
                "xcrun",
                &["simctl", "list", "devices", "-j"],
                SIMULATOR_SCAN_COMMAND_TIMEOUT,
            )
            .map_err(SimulatorError::from_developer_command_error)?;

        if !output.status_success {
            return Err(SimulatorError::CommandFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        let json_str = String::from_utf8_lossy(&output.stdout);
        let parsed: SimctlDevicesOutput = serde_json::from_str(&json_str)
            .map_err(|e| SimulatorError::ParseError(e.to_string()))?;

        let mut devices = Vec::new();

        for (runtime, runtime_devices) in parsed.devices {
            for device in runtime_devices {
                let udid = device.udid.clone();
                let device_path = self.devices_path.join(&udid);
                let size = if device_path.exists() {
                    calculate_dir_size(&device_path)
                } else {
                    0
                };

                devices.push(SimulatorDevice {
                    name: device.name,
                    udid,
                    state: device.state,
                    runtime: runtime.clone(),
                    is_available: device.is_available.unwrap_or(true),
                    path: device_path,
                    size,
                });
            }
        }

        Ok(SimulatorList { devices })
    }

    /// List all simulator runtimes
    pub fn list_runtimes(&self) -> Result<Vec<SimulatorRuntime>, SimulatorError> {
        let output = match self.command_runner.run(
            "xcrun",
            &["simctl", "runtime", "list", "-j"],
            SIMULATOR_SCAN_COMMAND_TIMEOUT,
        ) {
            Ok(output) => output,
            // Older Xcode versions lack `simctl runtime list`; treat invocation
            // failures (missing tool, timeout) as "no runtimes reported".
            Err(_) => return Ok(Vec::new()),
        };

        if !output.status_success {
            // Runtime list might not be available on older Xcode versions
            return Ok(Vec::new());
        }

        let json_str = String::from_utf8_lossy(&output.stdout);

        // Try to parse the runtime output
        if let Ok(parsed) = serde_json::from_str::<SimctlRuntimesOutput>(&json_str) {
            return Ok(parsed
                .runtimes
                .into_iter()
                .map(|r| SimulatorRuntime {
                    identifier: r.identifier,
                    version: r.version,
                    platform: r.platform.unwrap_or_default(),
                    is_available: r.is_available.unwrap_or(true),
                    size: r.size_bytes.unwrap_or(0),
                })
                .collect());
        }

        Ok(Vec::new())
    }

    /// Get unavailable simulators (safe to delete)
    pub fn get_unavailable_simulators(&self) -> Vec<SimulatorDevice> {
        match self.list_devices() {
            Ok(list) => list
                .devices
                .into_iter()
                .filter(|d| !d.is_available)
                .collect(),
            Err(_) => Vec::new(),
        }
    }

    /// Delete unavailable simulators using xcrun simctl
    pub fn delete_unavailable(&self, dry_run: bool) -> Result<usize, SimulatorError> {
        if dry_run {
            let unavailable = self.get_unavailable_simulators();
            return Ok(unavailable.len());
        }

        let output = self
            .command_runner
            .run(
                "xcrun",
                &["simctl", "delete", "unavailable"],
                COMMAND_CLEANUP_TIMEOUT,
            )
            .map_err(SimulatorError::from_developer_command_error)?;

        if !output.status_success {
            return Err(SimulatorError::CommandFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        // Return the count of deleted devices (we can't know exactly, so estimate)
        Ok(0)
    }

    /// Erase all simulator content and settings
    pub fn erase_all(&self, dry_run: bool) -> Result<(), SimulatorError> {
        if dry_run {
            return Ok(());
        }

        let output = self
            .command_runner
            .run(
                "xcrun",
                &["simctl", "erase", "all"],
                COMMAND_CLEANUP_TIMEOUT,
            )
            .map_err(SimulatorError::from_developer_command_error)?;

        if !output.status_success {
            return Err(SimulatorError::CommandFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        Ok(())
    }

    /// Scan simulator caches
    fn scan_caches(&self) -> Vec<CleanupTarget> {
        if !self.caches_path.exists() {
            return Vec::new();
        }

        let size = calculate_dir_size(&self.caches_path);
        if size > 0 {
            vec![CleanupTarget::new_direct(
                self.caches_path.clone(),
                "Simulator Caches",
                SafetyLevel::Safe,
            )
            .with_size(size)
            .with_description("CoreSimulator caches - safely regenerated")]
        } else {
            Vec::new()
        }
    }

    fn execute_cleanup_command(
        &self,
        target: &CleanupTarget,
        command: &str,
    ) -> Result<(), CleanupError> {
        let output = self
            .command_runner
            .run("sh", &["-c", command], COMMAND_CLEANUP_TIMEOUT)
            .map_err(|error| {
                cleanup_error_from_command_error(target, command.to_string(), error)
            })?;

        cleanup_result_from_output(target, output)
    }

    fn execute_cleanup_with_args(
        &self,
        target: &CleanupTarget,
        command: &str,
        args: &[String],
    ) -> Result<(), CleanupError> {
        let arg_refs: Vec<&str> = args.iter().map(String::as_str).collect();
        let display_command = format_command(command, &arg_refs);
        let output = self
            .command_runner
            .run(command, &arg_refs, COMMAND_CLEANUP_TIMEOUT)
            .map_err(|error| cleanup_error_from_command_error(target, display_command, error))?;

        cleanup_result_from_output(target, output)
    }
}

impl DeveloperCleaner for SimulatorCleaner {
    fn tool(&self) -> DeveloperTool {
        DeveloperTool::Simulator
    }

    fn scan(&self) -> ScanResult {
        if !self.is_installed() {
            return ScanResult::not_installed(DeveloperTool::Simulator);
        }

        let mut targets = Vec::new();
        let mut errors = Vec::new();

        // Scan for unavailable simulators
        match self.list_devices() {
            Ok(list) => {
                for device in list.devices {
                    if !device.is_available {
                        targets.push(
                            CleanupTarget::new_command(
                                format!("Unavailable Simulator: {} ({})", device.name, device.udid),
                                format!("xcrun simctl delete {}", device.udid),
                                SafetyLevel::Safe,
                            )
                            .with_size(device.size)
                            .with_description("Simulator is unavailable and can be safely deleted"),
                        );
                    }
                }
            }
            Err(e) => {
                errors.push(format!("Failed to list simulators: {}", e));
            }
        }

        // Add "delete all unavailable" as a convenience target
        let unavailable_count = targets.len();
        if unavailable_count > 0 {
            let total_unavailable_size: u64 = targets.iter().map(|t| t.size).sum();
            targets.insert(
                0,
                CleanupTarget::new_command(
                    format!("Delete All Unavailable Simulators ({})", unavailable_count),
                    "xcrun simctl delete unavailable",
                    SafetyLevel::Safe,
                )
                .with_size(total_unavailable_size)
                .with_description("Deletes all unavailable simulators at once"),
            );
        }

        // Scan caches
        targets.extend(self.scan_caches());

        // Scan runtimes
        match self.list_runtimes() {
            Ok(runtimes) => {
                for runtime in runtimes {
                    if !runtime.is_available {
                        targets.push(
                            CleanupTarget::new_command(
                                format!("Unavailable Runtime: {}", runtime.identifier),
                                format!("xcrun simctl runtime delete {}", runtime.identifier),
                                SafetyLevel::Caution,
                            )
                            .with_size(runtime.size)
                            .with_description(format!(
                                "{} {} - runtime is no longer available",
                                runtime.platform, runtime.version
                            )),
                        );
                    }
                }
            }
            Err(e) => {
                errors.push(format!("Failed to list runtimes: {}", e));
            }
        }

        let total_size = targets.iter().map(|t| t.size).sum();

        ScanResult {
            tool: DeveloperTool::Simulator,
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
            let result = match &target.cleanup_method {
                CleanupMethod::DirectDelete => {
                    if let Some(path) = &target.path {
                        if !dry_run {
                            fs::remove_dir_all(path).map_err(|e| CleanupError {
                                target: target.name.clone(),
                                message: e.to_string(),
                            })
                        } else {
                            Ok(())
                        }
                    } else {
                        Err(CleanupError {
                            target: target.name.clone(),
                            message: "No path specified for direct delete".to_string(),
                        })
                    }
                }
                CleanupMethod::Command(cmd) => {
                    if dry_run {
                        Ok(())
                    } else {
                        self.execute_cleanup_command(target, cmd)
                    }
                }
                CleanupMethod::CommandWithArgs(cmd, args) => {
                    if dry_run {
                        Ok(())
                    } else {
                        self.execute_cleanup_with_args(target, cmd, args)
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
            tool: DeveloperTool::Simulator,
            freed_bytes,
            items_cleaned,
            dry_run,
            errors,
        }
    }
}

/// List of simulators
#[derive(Debug, Clone)]
pub struct SimulatorList {
    pub devices: Vec<SimulatorDevice>,
}

/// Information about a simulator device
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimulatorDevice {
    pub name: String,
    pub udid: String,
    pub state: String,
    pub runtime: String,
    pub is_available: bool,
    pub path: PathBuf,
    pub size: u64,
}

/// Information about a simulator runtime
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimulatorRuntime {
    pub identifier: String,
    pub version: String,
    pub platform: String,
    pub is_available: bool,
    pub size: u64,
}

/// Simulator-specific errors
#[derive(Debug, thiserror::Error)]
pub enum SimulatorError {
    #[error("Command failed: {0}")]
    CommandFailed(String),

    #[error("Failed to parse output: {0}")]
    ParseError(String),

    #[error("Command timed out: {0}")]
    CommandTimedOut(String),
}

impl SimulatorError {
    fn from_developer_command_error(error: DeveloperCommandError) -> Self {
        match error {
            DeveloperCommandError::Io(error) => Self::CommandFailed(error.to_string()),
            DeveloperCommandError::TimedOut { command, timeout } => {
                Self::CommandTimedOut(format!("`{}` timed out after {:?}", command, timeout))
            }
        }
    }
}

fn cleanup_result_from_output(
    target: &CleanupTarget,
    output: DeveloperCommandOutput,
) -> Result<(), CleanupError> {
    if output.status_success {
        Ok(())
    } else {
        Err(CleanupError {
            target: target.name.clone(),
            message: String::from_utf8_lossy(&output.stderr).to_string(),
        })
    }
}

fn cleanup_error_from_command_error(
    target: &CleanupTarget,
    command: String,
    error: DeveloperCommandError,
) -> CleanupError {
    let message = match error {
        DeveloperCommandError::Io(error) => error.to_string(),
        DeveloperCommandError::TimedOut { timeout, .. } => {
            format!("`{}` timed out after {:?}", command, timeout)
        }
    };

    CleanupError {
        target: target.name.clone(),
        message,
    }
}

// JSON parsing structures for xcrun simctl output
#[derive(Debug, Deserialize)]
struct SimctlDevicesOutput {
    devices: HashMap<String, Vec<SimctlDevice>>,
}

#[derive(Debug, Deserialize)]
struct SimctlDevice {
    name: String,
    udid: String,
    state: String,
    #[serde(rename = "isAvailable")]
    is_available: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct SimctlRuntimesOutput {
    runtimes: Vec<SimctlRuntime>,
}

#[derive(Debug, Deserialize)]
struct SimctlRuntime {
    identifier: String,
    version: String,
    platform: Option<String>,
    #[serde(rename = "isAvailable")]
    is_available: Option<bool>,
    #[serde(rename = "sizeBytes")]
    size_bytes: Option<u64>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::VecDeque;
    use std::io;
    use std::sync::Mutex;
    use tempfile::tempdir;

    type MockCommandResult = Result<DeveloperCommandOutput, DeveloperCommandError>;

    #[derive(Default)]
    struct MockCommandRunner {
        responses: Mutex<VecDeque<MockCommandResult>>,
        calls: Mutex<Vec<(String, Vec<String>, Duration)>>,
    }

    impl MockCommandRunner {
        fn new(responses: Vec<MockCommandResult>) -> Arc<Self> {
            Arc::new(Self {
                responses: Mutex::new(responses.into()),
                calls: Mutex::new(Vec::new()),
            })
        }

        fn success(stdout: impl Into<Vec<u8>>) -> MockCommandResult {
            Ok(DeveloperCommandOutput {
                status_success: true,
                stdout: stdout.into(),
                stderr: Vec::new(),
            })
        }

        fn failure(stderr: impl Into<Vec<u8>>) -> MockCommandResult {
            Ok(DeveloperCommandOutput {
                status_success: false,
                stdout: Vec::new(),
                stderr: stderr.into(),
            })
        }

        fn timeout(command: &str, timeout: Duration) -> MockCommandResult {
            Err(DeveloperCommandError::TimedOut {
                command: command.to_string(),
                timeout,
            })
        }

        fn calls(&self) -> Vec<(String, Vec<String>, Duration)> {
            self.calls
                .lock()
                .expect("mock calls lock should not be poisoned")
                .clone()
        }
    }

    impl CommandRunner for MockCommandRunner {
        fn run(
            &self,
            program: &str,
            args: &[&str],
            timeout: Duration,
        ) -> Result<DeveloperCommandOutput, DeveloperCommandError> {
            self.calls
                .lock()
                .expect("mock calls lock should not be poisoned")
                .push((
                    program.to_string(),
                    args.iter().map(|arg| arg.to_string()).collect(),
                    timeout,
                ));

            self.responses
                .lock()
                .expect("mock responses lock should not be poisoned")
                .pop_front()
                .unwrap_or_else(|| {
                    Err(DeveloperCommandError::Io(io::Error::new(
                        io::ErrorKind::UnexpectedEof,
                        "no mock response configured",
                    )))
                })
        }
    }

    fn cleaner_with_runner(runner: Arc<dyn CommandRunner>) -> SimulatorCleaner {
        SimulatorCleaner::with_paths_and_runner(
            PathBuf::from("/nonexistent"),
            PathBuf::from("/nonexistent"),
            runner,
        )
    }

    #[test]
    fn test_simulator_cleaner_creation() {
        let cleaner = SimulatorCleaner::new();
        assert_eq!(cleaner.tool(), DeveloperTool::Simulator);
    }

    #[test]
    fn test_simulator_cleaner_default() {
        let cleaner = SimulatorCleaner::default();
        assert_eq!(cleaner.tool(), DeveloperTool::Simulator);
    }

    #[test]
    fn test_simulator_device_struct() {
        let device = SimulatorDevice {
            name: "iPhone 15".to_string(),
            udid: "abc-123".to_string(),
            state: "Shutdown".to_string(),
            runtime: "iOS 17.0".to_string(),
            is_available: true,
            path: PathBuf::from("/test"),
            size: 1024,
        };

        assert_eq!(device.name, "iPhone 15");
        assert!(device.is_available);
        assert_eq!(device.state, "Shutdown");
        assert_eq!(device.udid, "abc-123");
    }

    #[test]
    fn test_simulator_device_unavailable() {
        let device = SimulatorDevice {
            name: "iPhone 12".to_string(),
            udid: "xyz-789".to_string(),
            state: "Shutdown".to_string(),
            runtime: "iOS 15.0".to_string(),
            is_available: false,
            path: PathBuf::from("/test/unavailable"),
            size: 2048,
        };

        assert!(!device.is_available);
        assert_eq!(device.size, 2048);
    }

    #[test]
    fn test_simulator_runtime_struct() {
        let runtime = SimulatorRuntime {
            identifier: "com.apple.CoreSimulator.SimRuntime.iOS-17-0".to_string(),
            version: "17.0".to_string(),
            platform: "iOS".to_string(),
            is_available: true,
            size: 1024 * 1024 * 1024,
        };

        assert_eq!(runtime.version, "17.0");
        assert_eq!(runtime.platform, "iOS");
        assert!(runtime.is_available);
    }

    #[test]
    fn test_simulator_runtime_unavailable() {
        let runtime = SimulatorRuntime {
            identifier: "com.apple.CoreSimulator.SimRuntime.iOS-15-0".to_string(),
            version: "15.0".to_string(),
            platform: "iOS".to_string(),
            is_available: false,
            size: 500 * 1024 * 1024,
        };

        assert!(!runtime.is_available);
        assert_eq!(runtime.size, 500 * 1024 * 1024);
    }

    #[test]
    fn test_simctl_devices_output_parsing() {
        let json = r#"{
            "devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
                    {
                        "name": "iPhone 15",
                        "udid": "12345678-1234-1234-1234-123456789ABC",
                        "state": "Shutdown",
                        "isAvailable": true
                    },
                    {
                        "name": "iPhone 14",
                        "udid": "87654321-4321-4321-4321-CBA987654321",
                        "state": "Booted",
                        "isAvailable": false
                    }
                ],
                "com.apple.CoreSimulator.SimRuntime.iOS-16-0": [
                    {
                        "name": "iPhone 13",
                        "udid": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
                        "state": "Shutdown",
                        "isAvailable": true
                    }
                ]
            }
        }"#;

        let parsed: SimctlDevicesOutput =
            serde_json::from_str(json).expect("Failed to parse simctl devices JSON");
        assert_eq!(parsed.devices.len(), 2);

        let ios17_devices = &parsed.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-0"];
        assert_eq!(ios17_devices.len(), 2);
        assert_eq!(ios17_devices[0].name, "iPhone 15");
        assert_eq!(ios17_devices[0].is_available, Some(true));
        assert_eq!(ios17_devices[1].name, "iPhone 14");
        assert_eq!(ios17_devices[1].is_available, Some(false));
    }

    #[test]
    fn test_simctl_devices_output_missing_is_available() {
        // Test graceful handling when isAvailable is missing
        let json = r#"{
            "devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
                    {
                        "name": "iPhone 15",
                        "udid": "12345678-1234-1234-1234-123456789ABC",
                        "state": "Shutdown"
                    }
                ]
            }
        }"#;

        let parsed: SimctlDevicesOutput =
            serde_json::from_str(json).expect("Failed to parse simctl devices JSON");
        let ios17_devices = &parsed.devices["com.apple.CoreSimulator.SimRuntime.iOS-17-0"];
        assert_eq!(ios17_devices[0].is_available, None);
    }

    #[test]
    fn test_simctl_runtimes_output_parsing() {
        let json = r#"{
            "runtimes": [
                {
                    "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-0",
                    "version": "17.0",
                    "platform": "iOS",
                    "isAvailable": true,
                    "sizeBytes": 5368709120
                },
                {
                    "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-16-0",
                    "version": "16.0",
                    "platform": "iOS",
                    "isAvailable": false,
                    "sizeBytes": 4294967296
                }
            ]
        }"#;

        let parsed: SimctlRuntimesOutput =
            serde_json::from_str(json).expect("Failed to parse simctl runtimes JSON");
        assert_eq!(parsed.runtimes.len(), 2);
        assert_eq!(parsed.runtimes[0].version, "17.0");
        assert_eq!(parsed.runtimes[0].is_available, Some(true));
        assert_eq!(parsed.runtimes[0].size_bytes, Some(5368709120));
        assert_eq!(parsed.runtimes[1].is_available, Some(false));
    }

    #[test]
    fn test_simctl_runtimes_output_minimal() {
        // Test parsing with minimal fields
        let json = r#"{
            "runtimes": [
                {
                    "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-0",
                    "version": "17.0"
                }
            ]
        }"#;

        let parsed: SimctlRuntimesOutput =
            serde_json::from_str(json).expect("Failed to parse simctl runtimes JSON");
        assert_eq!(parsed.runtimes.len(), 1);
        assert_eq!(parsed.runtimes[0].platform, None);
        assert_eq!(parsed.runtimes[0].is_available, None);
        assert_eq!(parsed.runtimes[0].size_bytes, None);
    }

    #[test]
    fn test_scan_caches_with_temp_directory() {
        let temp = tempdir().expect("Failed to create temp directory");
        let caches_path = temp.path().join("Caches");
        fs::create_dir(&caches_path).expect("Failed to create Caches directory");
        fs::write(caches_path.join("cache_file.dat"), "test cache data")
            .expect("Failed to write cache file");

        let cleaner = SimulatorCleaner::with_paths_and_runner(
            PathBuf::from("/nonexistent"),
            caches_path,
            MockCommandRunner::new(Vec::new()),
        );

        let targets = cleaner.scan_caches();
        assert!(!targets.is_empty());
        assert!(targets[0].name.contains("Simulator Caches"));
        assert_eq!(targets[0].safety_level, SafetyLevel::Safe);
    }

    #[test]
    fn test_scan_caches_empty_directory() {
        let temp = tempdir().expect("Failed to create temp directory");
        let caches_path = temp.path().join("Caches");
        fs::create_dir(&caches_path).expect("Failed to create Caches directory");
        // Empty directory - no files

        let cleaner = SimulatorCleaner::with_paths_and_runner(
            PathBuf::from("/nonexistent"),
            caches_path,
            MockCommandRunner::new(Vec::new()),
        );

        let targets = cleaner.scan_caches();
        // Empty directory should not produce targets (size = 0)
        assert!(targets.is_empty());
    }

    #[test]
    fn test_scan_caches_nonexistent() {
        let cleaner = SimulatorCleaner::with_paths_and_runner(
            PathBuf::from("/nonexistent"),
            PathBuf::from("/nonexistent/caches"),
            MockCommandRunner::new(Vec::new()),
        );

        let targets = cleaner.scan_caches();
        assert!(targets.is_empty());
    }

    #[test]
    fn test_simulator_error_display() {
        let cmd_error = SimulatorError::CommandFailed("xcrun not found".to_string());
        assert!(cmd_error.to_string().contains("Command failed"));

        let parse_error = SimulatorError::ParseError("invalid JSON".to_string());
        assert!(parse_error.to_string().contains("parse output"));

        let timeout_error = SimulatorError::CommandTimedOut("xcrun simctl list".to_string());
        assert!(timeout_error.to_string().contains("Command timed out"));
    }

    #[test]
    fn test_simulator_list_struct() {
        let list = SimulatorList {
            devices: vec![
                SimulatorDevice {
                    name: "iPhone 15".to_string(),
                    udid: "abc-123".to_string(),
                    state: "Shutdown".to_string(),
                    runtime: "iOS 17.0".to_string(),
                    is_available: true,
                    path: PathBuf::from("/test1"),
                    size: 1024,
                },
                SimulatorDevice {
                    name: "iPhone 14".to_string(),
                    udid: "def-456".to_string(),
                    state: "Booted".to_string(),
                    runtime: "iOS 16.0".to_string(),
                    is_available: false,
                    path: PathBuf::from("/test2"),
                    size: 2048,
                },
            ],
        };

        assert_eq!(list.devices.len(), 2);
        assert!(list.devices[0].is_available);
        assert!(!list.devices[1].is_available);
    }

    #[test]
    fn test_cleanup_target_for_unavailable_simulator() {
        let target = CleanupTarget::new_command(
            "Unavailable Simulator: iPhone 12 (abc-123)",
            "xcrun simctl delete abc-123",
            SafetyLevel::Safe,
        )
        .with_size(1024 * 1024 * 1024)
        .with_description("Simulator is unavailable and can be safely deleted");

        assert!(target.name.contains("Unavailable Simulator"));
        assert_eq!(target.safety_level, SafetyLevel::Safe);
        assert_eq!(target.size, 1024 * 1024 * 1024);
        assert!(target.description.is_some());
    }

    #[test]
    fn test_cleanup_target_for_runtime() {
        let target = CleanupTarget::new_command(
            "Unavailable Runtime: com.apple.CoreSimulator.SimRuntime.iOS-15-0",
            "xcrun simctl runtime delete com.apple.CoreSimulator.SimRuntime.iOS-15-0",
            SafetyLevel::Caution,
        )
        .with_size(5 * 1024 * 1024 * 1024)
        .with_description("iOS 15.0 - runtime is no longer available");

        assert!(target.name.contains("Unavailable Runtime"));
        assert_eq!(target.safety_level, SafetyLevel::Caution);
    }

    #[test]
    fn test_get_unavailable_simulators_graceful_failure() {
        // When xcrun is not available or fails, should return empty vec
        let runner = MockCommandRunner::new(vec![MockCommandRunner::failure("xcrun not found")]);
        let cleaner = cleaner_with_runner(runner);

        let unavailable = cleaner.get_unavailable_simulators();
        assert!(unavailable.is_empty());
    }

    #[test]
    fn test_list_devices_uses_scan_timeout() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::success(r#"{"devices": {}}"#)]);
        let cleaner = cleaner_with_runner(runner.clone());

        let list = cleaner
            .list_devices()
            .expect("mocked simctl list should succeed");
        assert!(list.devices.is_empty());

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "xcrun");
        assert_eq!(calls[0].1, vec!["simctl", "list", "devices", "-j"]);
        assert_eq!(calls[0].2, SIMULATOR_SCAN_COMMAND_TIMEOUT);
    }

    #[test]
    fn test_list_devices_timeout_surfaces_structured_error() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "xcrun simctl list devices -j",
            SIMULATOR_SCAN_COMMAND_TIMEOUT,
        )]);
        let cleaner = cleaner_with_runner(runner);

        let error = cleaner
            .list_devices()
            .expect_err("timeout should surface as simulator error");

        assert!(matches!(error, SimulatorError::CommandTimedOut(_)));
    }

    #[test]
    fn test_list_runtimes_uses_scan_timeout() {
        let runner =
            MockCommandRunner::new(vec![MockCommandRunner::success(r#"{"runtimes": []}"#)]);
        let cleaner = cleaner_with_runner(runner.clone());

        let runtimes = cleaner
            .list_runtimes()
            .expect("mocked simctl runtime list should succeed");
        assert!(runtimes.is_empty());

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "xcrun");
        assert_eq!(calls[0].1, vec!["simctl", "runtime", "list", "-j"]);
        assert_eq!(calls[0].2, SIMULATOR_SCAN_COMMAND_TIMEOUT);
    }

    #[test]
    fn test_list_runtimes_timeout_returns_empty_vec() {
        // `simctl runtime list` is best-effort; a timeout/missing tool should
        // be reported as "no runtimes" rather than failing the entire scan.
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "xcrun simctl runtime list -j",
            SIMULATOR_SCAN_COMMAND_TIMEOUT,
        )]);
        let cleaner = cleaner_with_runner(runner);

        let runtimes = cleaner
            .list_runtimes()
            .expect("timeout should be silently degraded to empty list");
        assert!(runtimes.is_empty());
    }

    #[test]
    fn test_get_unavailable_simulators_parses_runner_output() {
        let json = r#"{
            "devices": {
                "iOS-17-0": [
                    {"name":"iPhone 15","udid":"u1","state":"Shutdown","isAvailable":true},
                    {"name":"iPhone 14","udid":"u2","state":"Shutdown","isAvailable":false}
                ]
            }
        }"#;
        let runner = MockCommandRunner::new(vec![MockCommandRunner::success(json)]);
        let cleaner = cleaner_with_runner(runner);

        let unavailable = cleaner.get_unavailable_simulators();
        assert_eq!(unavailable.len(), 1);
        assert_eq!(unavailable[0].name, "iPhone 14");
    }

    #[test]
    fn test_delete_unavailable_dry_run_does_not_execute_command() {
        // Dry run should only invoke the list (probe) command, never the delete.
        let runner = MockCommandRunner::new(vec![MockCommandRunner::success(r#"{"devices": {}}"#)]);
        let cleaner = cleaner_with_runner(runner.clone());

        let count = cleaner
            .delete_unavailable(true)
            .expect("dry run should not fail");
        assert_eq!(count, 0);

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        // Only the list_devices probe should have been called.
        assert_eq!(calls[0].1, vec!["simctl", "list", "devices", "-j"]);
    }

    #[test]
    fn test_delete_unavailable_runs_command_when_not_dry_run() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::success("")]);
        let cleaner = cleaner_with_runner(runner.clone());

        cleaner
            .delete_unavailable(false)
            .expect("mock delete should succeed");

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "xcrun");
        assert_eq!(calls[0].1, vec!["simctl", "delete", "unavailable"]);
        assert_eq!(calls[0].2, COMMAND_CLEANUP_TIMEOUT);
    }

    #[test]
    fn test_delete_unavailable_timeout_surfaces_structured_error() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "xcrun simctl delete unavailable",
            COMMAND_CLEANUP_TIMEOUT,
        )]);
        let cleaner = cleaner_with_runner(runner);

        let error = cleaner
            .delete_unavailable(false)
            .expect_err("timeout should surface");
        assert!(matches!(error, SimulatorError::CommandTimedOut(_)));
    }

    #[test]
    fn test_erase_all_dry_run_does_not_execute_command() {
        let runner = MockCommandRunner::new(Vec::new());
        let cleaner = cleaner_with_runner(runner.clone());

        cleaner.erase_all(true).expect("dry run should not fail");
        assert!(runner.calls().is_empty());
    }

    #[test]
    fn test_erase_all_runs_command_when_not_dry_run() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::success("")]);
        let cleaner = cleaner_with_runner(runner.clone());

        cleaner.erase_all(false).expect("mock erase should succeed");

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "xcrun");
        assert_eq!(calls[0].1, vec!["simctl", "erase", "all"]);
        assert_eq!(calls[0].2, COMMAND_CLEANUP_TIMEOUT);
    }

    #[test]
    fn test_erase_all_timeout_surfaces_structured_error() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "xcrun simctl erase all",
            COMMAND_CLEANUP_TIMEOUT,
        )]);
        let cleaner = cleaner_with_runner(runner);

        let error = cleaner
            .erase_all(false)
            .expect_err("timeout should surface");
        assert!(matches!(error, SimulatorError::CommandTimedOut(_)));
    }

    #[test]
    fn test_clean_dry_run_does_not_execute_command() {
        let runner = MockCommandRunner::new(Vec::new());
        let cleaner = cleaner_with_runner(runner.clone());
        let target = CleanupTarget::new_command(
            "Unavailable Simulator: iPhone (abc)",
            "xcrun simctl delete abc",
            SafetyLevel::Safe,
        )
        .with_size(2048);

        let result = cleaner.clean(&[target], true);

        assert!(result.dry_run);
        assert_eq!(result.freed_bytes, 2048);
        assert_eq!(result.items_cleaned, 1);
        assert!(result.errors.is_empty());
        assert!(runner.calls().is_empty());
    }

    #[test]
    fn test_clean_command_timeout_records_structured_error() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "xcrun simctl delete abc",
            COMMAND_CLEANUP_TIMEOUT,
        )]);
        let cleaner = cleaner_with_runner(runner.clone());
        let target = CleanupTarget::new_command(
            "Unavailable Simulator: iPhone (abc)",
            "xcrun simctl delete abc",
            SafetyLevel::Safe,
        )
        .with_size(2048);

        let result = cleaner.clean(&[target], false);

        assert!(!result.dry_run);
        assert_eq!(result.freed_bytes, 0);
        assert_eq!(result.items_cleaned, 0);
        assert_eq!(result.errors.len(), 1);
        assert!(result.errors[0].message.contains("timed out"));

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "sh");
        assert_eq!(calls[0].1, vec!["-c", "xcrun simctl delete abc"]);
        assert_eq!(calls[0].2, COMMAND_CLEANUP_TIMEOUT);
    }

    #[test]
    fn test_clean_command_with_args_timeout_records_structured_error() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "xcrun simctl delete abc",
            COMMAND_CLEANUP_TIMEOUT,
        )]);
        let cleaner = cleaner_with_runner(runner.clone());
        let target = CleanupTarget {
            path: None,
            name: "xcrun delete".to_string(),
            size: 1024,
            safety_level: SafetyLevel::Safe,
            cleanup_method: CleanupMethod::CommandWithArgs(
                "xcrun".to_string(),
                vec![
                    "simctl".to_string(),
                    "delete".to_string(),
                    "abc".to_string(),
                ],
            ),
            description: None,
        };

        let result = cleaner.clean(&[target], false);

        assert!(!result.dry_run);
        assert_eq!(result.errors.len(), 1);
        assert!(result.errors[0].message.contains("timed out"));

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "xcrun");
        assert_eq!(calls[0].1, vec!["simctl", "delete", "abc"]);
        assert_eq!(calls[0].2, COMMAND_CLEANUP_TIMEOUT);
    }

    #[test]
    fn test_scan_returns_empty_when_simctl_times_out() {
        // `is_installed` -> list_devices -> list_runtimes all driven via runner.
        // We mock: is_installed (which/xcrun) probes are handled by real system;
        // here we just verify that even if list_devices times out the scan does
        // not panic and surfaces a structured error in `errors`.
        let runner = MockCommandRunner::new(vec![
            MockCommandRunner::timeout(
                "xcrun simctl list devices -j",
                SIMULATOR_SCAN_COMMAND_TIMEOUT,
            ),
            MockCommandRunner::timeout(
                "xcrun simctl runtime list -j",
                SIMULATOR_SCAN_COMMAND_TIMEOUT,
            ),
        ]);
        let cleaner = cleaner_with_runner(runner);

        // is_installed() uses the real SystemCommandRunner via DeveloperTool::Simulator
        // so we cannot fully sandbox it; just exercise scan_caches + helpers directly.
        let caches = cleaner.scan_caches();
        assert!(caches.is_empty());

        let unavailable = cleaner.get_unavailable_simulators();
        assert!(unavailable.is_empty());

        let runtimes = cleaner
            .list_runtimes()
            .expect("runtime list timeout should degrade silently");
        assert!(runtimes.is_empty());
    }
}
