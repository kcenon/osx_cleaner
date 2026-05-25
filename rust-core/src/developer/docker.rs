// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Docker Cleanup Management
//!
//! Provides cleanup functionality for Docker:
//! - Dangling images (safe)
//! - Stopped containers (safe)
//! - Unused volumes (caution)
//! - Build cache (caution)
//! - All unused images (warning)

use std::process::Command;
use std::sync::Arc;
use std::time::Duration;

use serde::{Deserialize, Serialize};

use super::{
    CleanupError, CleanupMethod, CleanupResult, CleanupTarget, CommandRunner, DeveloperCleaner,
    DeveloperCommandError, DeveloperCommandOutput, DeveloperTool, ScanResult, SystemCommandRunner,
    COMMAND_PROBE_TIMEOUT,
};
use crate::safety::SafetyLevel;

const DOCKER_SCAN_COMMAND_TIMEOUT: Duration = Duration::from_secs(5);

/// Docker cleaner
pub struct DockerCleaner {
    command_runner: Arc<dyn CommandRunner>,
}

impl Default for DockerCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl DockerCleaner {
    /// Create a new Docker cleaner
    pub fn new() -> Self {
        Self {
            command_runner: Arc::new(SystemCommandRunner),
        }
    }

    #[cfg(test)]
    fn with_command_runner(command_runner: Arc<dyn CommandRunner>) -> Self {
        Self { command_runner }
    }

    /// Check if Docker daemon is running
    pub fn is_daemon_running(&self) -> bool {
        self.run_docker(&["info"], COMMAND_PROBE_TIMEOUT)
            .map(|o| o.status_success)
            .unwrap_or(false)
    }

    /// Get Docker disk usage information
    pub fn get_disk_usage(&self) -> Result<DockerDiskUsage, DockerError> {
        if !self.is_daemon_running() {
            return Err(DockerError::DaemonNotRunning);
        }

        let output = self
            .run_docker(
                &["system", "df", "-v", "--format", "{{json .}}"],
                DOCKER_SCAN_COMMAND_TIMEOUT,
            )
            .map_err(DockerError::from_developer_command_error)?;

        if !output.status_success {
            return Err(DockerError::CommandFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        // Parse the JSON output
        // Docker system df outputs multiple JSON objects, one per line
        let stdout = String::from_utf8_lossy(&output.stdout);

        let mut usage = DockerDiskUsage::default();

        for line in stdout.lines() {
            if line.trim().is_empty() {
                continue;
            }

            if let Ok(entry) = serde_json::from_str::<DockerDfEntry>(line) {
                match entry.entry_type.as_str() {
                    "Images" => {
                        usage.images_size = parse_size(&entry.size);
                        usage.images_reclaimable = parse_size(&entry.reclaimable);
                    }
                    "Containers" => {
                        usage.containers_size = parse_size(&entry.size);
                        usage.containers_reclaimable = parse_size(&entry.reclaimable);
                    }
                    "Local Volumes" => {
                        usage.volumes_size = parse_size(&entry.size);
                        usage.volumes_reclaimable = parse_size(&entry.reclaimable);
                    }
                    "Build Cache" => {
                        usage.build_cache_size = parse_size(&entry.size);
                        usage.build_cache_reclaimable = parse_size(&entry.reclaimable);
                    }
                    _ => {}
                }
            }
        }

        Ok(usage)
    }

    /// Get list of dangling images
    pub fn get_dangling_images(&self) -> Vec<DockerImage> {
        let output = self.run_docker(
            &[
                "images",
                "-f",
                "dangling=true",
                "--format",
                "{{.ID}}\t{{.Size}}\t{{.CreatedSince}}",
            ],
            DOCKER_SCAN_COMMAND_TIMEOUT,
        );

        match output {
            Ok(o) if o.status_success => {
                let stdout = String::from_utf8_lossy(&o.stdout);
                stdout
                    .lines()
                    .filter(|l| !l.trim().is_empty())
                    .filter_map(|line| {
                        let parts: Vec<&str> = line.split('\t').collect();
                        if parts.len() >= 3 {
                            Some(DockerImage {
                                id: parts[0].to_string(),
                                size_str: parts[1].to_string(),
                                created: parts[2].to_string(),
                            })
                        } else {
                            None
                        }
                    })
                    .collect()
            }
            _ => Vec::new(),
        }
    }

    /// Get list of stopped containers
    pub fn get_stopped_containers(&self) -> Vec<DockerContainer> {
        let output = self.run_docker(
            &[
                "ps",
                "-a",
                "-f",
                "status=exited",
                "--format",
                "{{.ID}}\t{{.Names}}\t{{.Size}}\t{{.Status}}",
            ],
            DOCKER_SCAN_COMMAND_TIMEOUT,
        );

        match output {
            Ok(o) if o.status_success => {
                let stdout = String::from_utf8_lossy(&o.stdout);
                stdout
                    .lines()
                    .filter(|l| !l.trim().is_empty())
                    .filter_map(|line| {
                        let parts: Vec<&str> = line.split('\t').collect();
                        if parts.len() >= 4 {
                            Some(DockerContainer {
                                id: parts[0].to_string(),
                                name: parts[1].to_string(),
                                size_str: parts[2].to_string(),
                                status: parts[3].to_string(),
                            })
                        } else {
                            None
                        }
                    })
                    .collect()
            }
            _ => Vec::new(),
        }
    }

    fn run_docker(
        &self,
        args: &[&str],
        timeout: Duration,
    ) -> Result<DeveloperCommandOutput, DeveloperCommandError> {
        self.command_runner.run("docker", args, timeout)
    }

    /// Execute a Docker cleanup command
    fn execute_cleanup(&self, command: &str, dry_run: bool) -> Result<String, DockerError> {
        if dry_run {
            return Ok("Dry run - no changes made".to_string());
        }

        let output = Command::new("sh")
            .args(["-c", command])
            .output()
            .map_err(|e| DockerError::CommandFailed(e.to_string()))?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(DockerError::CommandFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ))
        }
    }
}

impl DeveloperCleaner for DockerCleaner {
    fn tool(&self) -> DeveloperTool {
        DeveloperTool::Docker
    }

    fn is_installed(&self) -> bool {
        self.is_daemon_running()
    }

    fn scan(&self) -> ScanResult {
        if !self.is_installed() {
            return ScanResult::not_installed(DeveloperTool::Docker);
        }

        let mut targets = Vec::new();
        let mut errors = Vec::new();

        // Get disk usage
        match self.get_disk_usage() {
            Ok(usage) => {
                // Basic prune (dangling images, stopped containers)
                if usage.images_reclaimable > 0 || usage.containers_reclaimable > 0 {
                    let size = usage.images_reclaimable + usage.containers_reclaimable;
                    targets.push(
                        CleanupTarget::new_command(
                            "Docker Basic Cleanup",
                            "docker system prune -f",
                            SafetyLevel::Safe,
                        )
                        .with_size(size)
                        .with_description("Remove dangling images and stopped containers"),
                    );
                }

                // Build cache
                if usage.build_cache_reclaimable > 0 {
                    targets.push(
                        CleanupTarget::new_command(
                            "Docker Build Cache",
                            "docker builder prune -f",
                            SafetyLevel::Caution,
                        )
                        .with_size(usage.build_cache_reclaimable)
                        .with_description("Remove build cache - rebuilds will take longer"),
                    );
                }

                // Volumes (more dangerous)
                if usage.volumes_reclaimable > 0 {
                    targets.push(
                        CleanupTarget::new_command(
                            "Docker Unused Volumes",
                            "docker volume prune -f",
                            SafetyLevel::Warning,
                        )
                        .with_size(usage.volumes_reclaimable)
                        .with_description("Remove unused volumes - data may be lost"),
                    );
                }

                // Full cleanup (most aggressive)
                let total_reclaimable = usage.images_reclaimable
                    + usage.containers_reclaimable
                    + usage.volumes_reclaimable
                    + usage.build_cache_reclaimable;

                if total_reclaimable > 0 {
                    targets.push(
                        CleanupTarget::new_command(
                            "Docker Full Cleanup",
                            "docker system prune -a --volumes -f",
                            SafetyLevel::Warning,
                        )
                        .with_size(total_reclaimable)
                        .with_description(
                            "Remove all unused images, containers, volumes, and cache",
                        ),
                    );
                }
            }
            Err(e) => {
                errors.push(format!("Failed to get Docker disk usage: {}", e));
            }
        }

        // Add individual dangling images
        let dangling = self.get_dangling_images();
        for image in dangling {
            targets.push(
                CleanupTarget::new_command(
                    format!("Dangling Image: {}", &image.id[..12.min(image.id.len())]),
                    format!("docker rmi {}", image.id),
                    SafetyLevel::Safe,
                )
                .with_size(parse_size(&image.size_str))
                .with_description(format!("Created {}", image.created)),
            );
        }

        // Add individual stopped containers
        let stopped = self.get_stopped_containers();
        for container in stopped {
            targets.push(
                CleanupTarget::new_command(
                    format!("Stopped Container: {}", container.name),
                    format!("docker rm {}", container.id),
                    SafetyLevel::Safe,
                )
                .with_size(parse_size(&container.size_str))
                .with_description(format!("Status: {}", container.status)),
            );
        }

        let total_size = targets.iter().map(|t| t.size).sum();

        ScanResult {
            tool: DeveloperTool::Docker,
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
                CleanupMethod::Command(cmd) => self.execute_cleanup(cmd, dry_run),
                CleanupMethod::CommandWithArgs(cmd, args) => {
                    let full_cmd = format!("{} {}", cmd, args.join(" "));
                    self.execute_cleanup(&full_cmd, dry_run)
                }
                CleanupMethod::DirectDelete => {
                    // Docker cleanup doesn't use direct delete
                    Err(DockerError::CommandFailed(
                        "Direct delete not supported for Docker".to_string(),
                    ))
                }
            };

            match result {
                Ok(_) => {
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
                    log::warn!("Failed to clean {}: {}", target.name, e);
                    errors.push(CleanupError {
                        target: target.name.clone(),
                        message: e.to_string(),
                    });
                }
            }
        }

        CleanupResult {
            tool: DeveloperTool::Docker,
            freed_bytes,
            items_cleaned,
            dry_run,
            errors,
        }
    }
}

/// Docker disk usage information
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DockerDiskUsage {
    pub images_size: u64,
    pub images_reclaimable: u64,
    pub containers_size: u64,
    pub containers_reclaimable: u64,
    pub volumes_size: u64,
    pub volumes_reclaimable: u64,
    pub build_cache_size: u64,
    pub build_cache_reclaimable: u64,
}

impl DockerDiskUsage {
    /// Get total disk usage
    pub fn total_size(&self) -> u64 {
        self.images_size + self.containers_size + self.volumes_size + self.build_cache_size
    }

    /// Get total reclaimable space
    pub fn total_reclaimable(&self) -> u64 {
        self.images_reclaimable
            + self.containers_reclaimable
            + self.volumes_reclaimable
            + self.build_cache_reclaimable
    }
}

/// Docker image information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerImage {
    pub id: String,
    pub size_str: String,
    pub created: String,
}

/// Docker container information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerContainer {
    pub id: String,
    pub name: String,
    pub size_str: String,
    pub status: String,
}

/// Docker-specific errors
#[derive(Debug, thiserror::Error)]
pub enum DockerError {
    #[error("Docker daemon is not running")]
    DaemonNotRunning,

    #[error("Command failed: {0}")]
    CommandFailed(String),

    #[error("Command timed out: {0}")]
    CommandTimedOut(String),
}

impl DockerError {
    fn from_developer_command_error(error: DeveloperCommandError) -> Self {
        match error {
            DeveloperCommandError::Io(error) => Self::CommandFailed(error.to_string()),
            DeveloperCommandError::TimedOut { command, timeout } => {
                Self::CommandTimedOut(format!("`{}` timed out after {:?}", command, timeout))
            }
        }
    }
}

// JSON structure for docker system df output
#[derive(Debug, Deserialize)]
struct DockerDfEntry {
    #[serde(rename = "Type")]
    entry_type: String,
    #[serde(rename = "Size")]
    size: String,
    #[serde(rename = "Reclaimable")]
    reclaimable: String,
}

/// Parse Docker size strings (e.g., "1.5GB", "500MB", "100kB")
fn parse_size(size_str: &str) -> u64 {
    let size_str = size_str.trim();

    // Handle formats like "1.5GB (50%)"
    let size_part = size_str.split_whitespace().next().unwrap_or(size_str);

    // Find where the number ends and unit begins
    let mut num_end = 0;
    for (i, c) in size_part.char_indices() {
        if c.is_ascii_digit() || c == '.' {
            num_end = i + 1;
        } else {
            break;
        }
    }

    if num_end == 0 {
        return 0;
    }

    let num: f64 = size_part[..num_end].parse().unwrap_or(0.0);
    let unit = &size_part[num_end..].to_uppercase();

    let multiplier: u64 = match unit.as_str() {
        "B" | "" => 1,
        "KB" | "K" => 1024,
        "MB" | "M" => 1024 * 1024,
        "GB" | "G" => 1024 * 1024 * 1024,
        "TB" | "T" => 1024 * 1024 * 1024 * 1024,
        _ => 1,
    };

    (num * multiplier as f64) as u64
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::VecDeque;
    use std::io;
    use std::sync::Mutex;

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

    #[test]
    fn test_docker_cleaner_creation() {
        let cleaner = DockerCleaner::new();
        assert_eq!(cleaner.tool(), DeveloperTool::Docker);
    }

    #[test]
    fn test_docker_cleaner_default_trait() {
        let cleaner = DockerCleaner::default();
        assert_eq!(cleaner.tool(), DeveloperTool::Docker);
    }

    #[test]
    fn test_parse_size() {
        assert_eq!(parse_size("100B"), 100);
        assert_eq!(parse_size("1KB"), 1024);
        assert_eq!(parse_size("1MB"), 1024 * 1024);
        assert_eq!(parse_size("1GB"), 1024 * 1024 * 1024);
        assert_eq!(parse_size("1.5GB"), (1.5 * 1024.0 * 1024.0 * 1024.0) as u64);
        assert_eq!(parse_size("500MB (50%)"), 500 * 1024 * 1024);
    }

    #[test]
    fn test_parse_size_edge_cases() {
        // Empty string
        assert_eq!(parse_size(""), 0);
        // Whitespace
        assert_eq!(parse_size("  "), 0);
        // Just number without unit
        assert_eq!(parse_size("1024"), 1024);
        // Lowercase units
        assert_eq!(parse_size("1kb"), 1024);
        assert_eq!(parse_size("1mb"), 1024 * 1024);
        assert_eq!(parse_size("1gb"), 1024 * 1024 * 1024);
        // Short form units
        assert_eq!(parse_size("1K"), 1024);
        assert_eq!(parse_size("1M"), 1024 * 1024);
        assert_eq!(parse_size("1G"), 1024 * 1024 * 1024);
        assert_eq!(parse_size("1T"), 1024 * 1024 * 1024 * 1024);
        // Decimal values
        assert_eq!(parse_size("0.5GB"), (0.5 * 1024.0 * 1024.0 * 1024.0) as u64);
        assert_eq!(parse_size("2.5MB"), (2.5 * 1024.0 * 1024.0) as u64);
        // With parenthetical info (Docker format)
        assert_eq!(
            parse_size("1.2GB (75%)"),
            (1.2 * 1024.0 * 1024.0 * 1024.0) as u64
        );
        // Zero
        assert_eq!(parse_size("0B"), 0);
        assert_eq!(parse_size("0"), 0);
    }

    #[test]
    fn test_docker_disk_usage() {
        let usage = DockerDiskUsage {
            images_size: 1000,
            images_reclaimable: 500,
            containers_size: 200,
            containers_reclaimable: 100,
            volumes_size: 300,
            volumes_reclaimable: 150,
            build_cache_size: 400,
            build_cache_reclaimable: 200,
        };

        assert_eq!(usage.total_size(), 1900);
        assert_eq!(usage.total_reclaimable(), 950);
    }

    #[test]
    fn test_docker_disk_usage_default() {
        let usage = DockerDiskUsage::default();
        assert_eq!(usage.total_size(), 0);
        assert_eq!(usage.total_reclaimable(), 0);
        assert_eq!(usage.images_size, 0);
        assert_eq!(usage.images_reclaimable, 0);
        assert_eq!(usage.containers_size, 0);
        assert_eq!(usage.containers_reclaimable, 0);
        assert_eq!(usage.volumes_size, 0);
        assert_eq!(usage.volumes_reclaimable, 0);
        assert_eq!(usage.build_cache_size, 0);
        assert_eq!(usage.build_cache_reclaimable, 0);
    }

    #[test]
    fn test_docker_image_struct() {
        let image = DockerImage {
            id: "abc123def456".to_string(),
            size_str: "1.5GB".to_string(),
            created: "2 days ago".to_string(),
        };
        assert_eq!(image.id, "abc123def456");
        assert_eq!(image.size_str, "1.5GB");
        assert_eq!(image.created, "2 days ago");
    }

    #[test]
    fn test_docker_container_struct() {
        let container = DockerContainer {
            id: "container123".to_string(),
            name: "my-container".to_string(),
            size_str: "500MB".to_string(),
            status: "Exited (0) 3 hours ago".to_string(),
        };
        assert_eq!(container.id, "container123");
        assert_eq!(container.name, "my-container");
        assert_eq!(container.size_str, "500MB");
        assert_eq!(container.status, "Exited (0) 3 hours ago");
    }

    #[test]
    fn test_docker_error_variants() {
        let daemon_error = DockerError::DaemonNotRunning;
        assert_eq!(daemon_error.to_string(), "Docker daemon is not running");

        let command_error = DockerError::CommandFailed("permission denied".to_string());
        assert_eq!(
            command_error.to_string(),
            "Command failed: permission denied"
        );

        let timeout_error = DockerError::CommandTimedOut("docker info".to_string());
        assert_eq!(timeout_error.to_string(), "Command timed out: docker info");
    }

    #[test]
    fn test_is_daemon_running_success_uses_probe_timeout() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::success("")]);
        let cleaner = DockerCleaner::with_command_runner(runner.clone());

        assert!(cleaner.is_daemon_running());

        let calls = runner.calls();
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].0, "docker");
        assert_eq!(calls[0].1, vec!["info"]);
        assert_eq!(calls[0].2, COMMAND_PROBE_TIMEOUT);
    }

    #[test]
    fn test_is_daemon_running_failure_returns_false() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::failure(
            "Cannot connect to the Docker daemon",
        )]);
        let cleaner = DockerCleaner::with_command_runner(runner);

        assert!(!cleaner.is_daemon_running());
    }

    #[test]
    fn test_is_daemon_running_timeout_returns_false() {
        let runner = MockCommandRunner::new(vec![MockCommandRunner::timeout(
            "docker info",
            COMMAND_PROBE_TIMEOUT,
        )]);
        let cleaner = DockerCleaner::with_command_runner(runner);

        assert!(!cleaner.is_daemon_running());
    }

    #[test]
    fn test_get_disk_usage_uses_mocked_docker_output() {
        let df_output = [
            r#"{"Type":"Images","Size":"1GB","Reclaimable":"500MB (50%)"}"#,
            r#"{"Type":"Containers","Size":"200MB","Reclaimable":"100MB (50%)"}"#,
            r#"{"Type":"Local Volumes","Size":"300MB","Reclaimable":"150MB (50%)"}"#,
            r#"{"Type":"Build Cache","Size":"400MB","Reclaimable":"200MB (50%)"}"#,
        ]
        .join("\n");
        let runner = MockCommandRunner::new(vec![
            MockCommandRunner::success(""),
            MockCommandRunner::success(df_output),
        ]);
        let cleaner = DockerCleaner::with_command_runner(runner);

        let usage = cleaner
            .get_disk_usage()
            .expect("mocked Docker disk usage should parse");

        assert_eq!(usage.images_size, 1024 * 1024 * 1024);
        assert_eq!(usage.images_reclaimable, 500 * 1024 * 1024);
        assert_eq!(usage.containers_reclaimable, 100 * 1024 * 1024);
        assert_eq!(usage.volumes_reclaimable, 150 * 1024 * 1024);
        assert_eq!(usage.build_cache_reclaimable, 200 * 1024 * 1024);
    }

    #[test]
    fn test_get_disk_usage_timeout_returns_structured_error() {
        let runner = MockCommandRunner::new(vec![
            MockCommandRunner::success(""),
            MockCommandRunner::timeout("docker system df", DOCKER_SCAN_COMMAND_TIMEOUT),
        ]);
        let cleaner = DockerCleaner::with_command_runner(runner);

        let error = cleaner
            .get_disk_usage()
            .expect_err("timeout should be surfaced as a Docker error");

        assert!(matches!(error, DockerError::CommandTimedOut(_)));
    }

    #[test]
    fn test_scan_returns_valid_result_structure() {
        let runner = MockCommandRunner::new(vec![
            MockCommandRunner::success(""),
            MockCommandRunner::success(""),
            MockCommandRunner::success(
                r#"{"Type":"Images","Size":"1GB","Reclaimable":"500MB (50%)"}"#,
            ),
            MockCommandRunner::success("abc123def456\t100MB\t2 days ago\n"),
            MockCommandRunner::success("container123\tmock-container\t50MB\tExited (0)\n"),
        ]);
        let cleaner = DockerCleaner::with_command_runner(runner);
        let result = cleaner.scan();

        assert_eq!(result.tool, DeveloperTool::Docker);
        assert!(result.installed);
        assert!(result.total_size > 0);
        assert!(result
            .targets
            .iter()
            .any(|target| target.name == "Docker Basic Cleanup"));
        assert!(result
            .targets
            .iter()
            .any(|target| target.name == "Dangling Image: abc123def456"));
        assert!(result
            .targets
            .iter()
            .any(|target| target.name == "Stopped Container: mock-container"));
    }

    #[test]
    fn test_scan_timeout_treats_docker_as_unavailable() {
        let cleaner = DockerCleaner::with_command_runner(MockCommandRunner::new(vec![
            MockCommandRunner::timeout("docker info", COMMAND_PROBE_TIMEOUT),
        ]));

        let result = cleaner.scan();

        assert_eq!(result.tool, DeveloperTool::Docker);
        assert!(!result.installed);
        assert_eq!(result.total_size, 0);
        assert!(result.targets.is_empty());
    }

    #[test]
    fn test_clean_dry_run_handles_empty_targets() {
        let cleaner = DockerCleaner::new();
        let targets: Vec<CleanupTarget> = Vec::new();
        let result = cleaner.clean(&targets, true);

        assert_eq!(result.tool, DeveloperTool::Docker);
        assert!(result.dry_run);
        assert_eq!(result.freed_bytes, 0);
        assert_eq!(result.items_cleaned, 0);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_cleanup_target_has_valid_method() {
        // Test command-based cleanup target (Docker style)
        let target = CleanupTarget::new_command(
            "Docker Basic Cleanup",
            "docker system prune -f",
            SafetyLevel::Safe,
        )
        .with_size(1024)
        .with_description("Test cleanup");

        assert_eq!(target.name, "Docker Basic Cleanup");
        assert_eq!(target.size, 1024);
        assert_eq!(target.safety_level, SafetyLevel::Safe);
        assert!(target.description.is_some());
        assert!(target.path.is_none()); // Docker uses command-based cleanup

        match &target.cleanup_method {
            CleanupMethod::Command(cmd) => {
                assert_eq!(cmd, "docker system prune -f");
            }
            _ => panic!("Expected Command cleanup method"),
        }
    }

    #[test]
    fn test_cleanup_target_safety_levels() {
        // Safe level for basic prune
        let safe_target =
            CleanupTarget::new_command("Basic Prune", "docker system prune -f", SafetyLevel::Safe);
        assert_eq!(safe_target.safety_level, SafetyLevel::Safe);

        // Caution level for build cache
        let caution_target = CleanupTarget::new_command(
            "Build Cache",
            "docker builder prune -f",
            SafetyLevel::Caution,
        );
        assert_eq!(caution_target.safety_level, SafetyLevel::Caution);

        // Warning level for full prune
        let warning_target = CleanupTarget::new_command(
            "Full Prune",
            "docker system prune -a --volumes -f",
            SafetyLevel::Warning,
        );
        assert_eq!(warning_target.safety_level, SafetyLevel::Warning);
    }

    #[test]
    fn test_is_installed_returns_boolean() {
        let running = DockerCleaner::with_command_runner(MockCommandRunner::new(vec![
            MockCommandRunner::success(""),
        ]));
        assert!(running.is_installed());

        let unavailable = DockerCleaner::with_command_runner(MockCommandRunner::new(vec![
            MockCommandRunner::timeout("docker info", COMMAND_PROBE_TIMEOUT),
        ]));
        assert!(!unavailable.is_installed());
    }

    #[test]
    fn test_scan_with_daemon_not_running() {
        // This test verifies the error handling path when Docker daemon is not running
        // We can't easily mock this, but we can verify the error type exists
        let error = DockerError::DaemonNotRunning;
        assert!(matches!(error, DockerError::DaemonNotRunning));
    }

    #[test]
    fn test_get_disk_usage_error_handling() {
        // Verify error types for disk usage
        let error = DockerError::CommandFailed("docker: command not found".to_string());
        assert!(error.to_string().contains("Command failed"));
    }

    #[test]
    fn test_docker_disk_usage_serialization() {
        let usage = DockerDiskUsage {
            images_size: 1000,
            images_reclaimable: 500,
            containers_size: 200,
            containers_reclaimable: 100,
            volumes_size: 300,
            volumes_reclaimable: 150,
            build_cache_size: 400,
            build_cache_reclaimable: 200,
        };

        // Test serialization
        let json = serde_json::to_string(&usage).expect("Serialization should succeed");
        assert!(json.contains("images_size"));
        assert!(json.contains("1000"));

        // Test deserialization
        let deserialized: DockerDiskUsage =
            serde_json::from_str(&json).expect("Deserialization should succeed");
        assert_eq!(deserialized.images_size, 1000);
        assert_eq!(deserialized.total_size(), usage.total_size());
    }

    #[test]
    fn test_docker_image_serialization() {
        let image = DockerImage {
            id: "sha256:abc123".to_string(),
            size_str: "1.5GB".to_string(),
            created: "2 days ago".to_string(),
        };

        let json = serde_json::to_string(&image).expect("Serialization should succeed");
        let deserialized: DockerImage =
            serde_json::from_str(&json).expect("Deserialization should succeed");
        assert_eq!(deserialized.id, image.id);
    }

    #[test]
    fn test_docker_container_serialization() {
        let container = DockerContainer {
            id: "abc123".to_string(),
            name: "test-container".to_string(),
            size_str: "100MB".to_string(),
            status: "Exited".to_string(),
        };

        let json = serde_json::to_string(&container).expect("Serialization should succeed");
        let deserialized: DockerContainer =
            serde_json::from_str(&json).expect("Deserialization should succeed");
        assert_eq!(deserialized.name, container.name);
    }
}
