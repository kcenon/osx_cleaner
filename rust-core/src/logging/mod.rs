// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Comprehensive logging module for deletion operations
//!
//! Provides structured logging with:
//! - Safety level information
//! - Deletion attempt tracking
//! - Result logging (success/failure)
//! - Timestamps
//! - Log rotation support

use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use crate::safety::SafetyLevel;

/// Maximum number of log entries to keep in memory
const MAX_MEMORY_LOG_ENTRIES: usize = 1000;

/// Maximum log file size in bytes (10 MB)
const MAX_LOG_FILE_SIZE: u64 = 10 * 1024 * 1024;

/// Number of rotated log files to keep
const MAX_ROTATED_FILES: usize = 5;

/// Result of a deletion operation
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeletionResult {
    Success,
    Failed,
    Skipped,
    DryRun,
}

impl std::fmt::Display for DeletionResult {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeletionResult::Success => write!(f, "SUCCESS"),
            DeletionResult::Failed => write!(f, "FAILED"),
            DeletionResult::Skipped => write!(f, "SKIPPED"),
            DeletionResult::DryRun => write!(f, "DRY_RUN"),
        }
    }
}

/// A structured log entry for deletion operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeletionLogEntry {
    pub timestamp: String,
    pub path: String,
    pub safety_level: String,
    pub result: DeletionResult,
    pub bytes_freed: u64,
    pub error_message: Option<String>,
}

impl DeletionLogEntry {
    /// Create a new log entry
    pub fn new(
        path: impl Into<String>,
        safety_level: SafetyLevel,
        result: DeletionResult,
        bytes_freed: u64,
        error_message: Option<String>,
    ) -> Self {
        let now: DateTime<Local> = Local::now();
        DeletionLogEntry {
            timestamp: now.format("%Y-%m-%d %H:%M:%S%.3f").to_string(),
            path: path.into(),
            safety_level: safety_level.to_string(),
            result,
            bytes_freed,
            error_message,
        }
    }

    /// Format the log entry for file output
    pub fn format(&self) -> String {
        let error_info = self
            .error_message
            .as_ref()
            .map(|e| format!(" [{}]", e))
            .unwrap_or_default();

        format!(
            "[{}] {} | {} | {} | {} bytes{}",
            self.timestamp,
            self.result,
            self.safety_level,
            self.path,
            self.bytes_freed,
            error_info
        )
    }
}

/// Deletion logger with file and memory logging support
pub struct DeletionLogger {
    log_file_path: Option<PathBuf>,
    memory_log: Mutex<VecDeque<DeletionLogEntry>>,
    file_writer: Mutex<Option<BufWriter<File>>>,
}

impl Default for DeletionLogger {
    fn default() -> Self {
        Self::new()
    }
}

impl DeletionLogger {
    /// Create a new logger without file output
    pub fn new() -> Self {
        DeletionLogger {
            log_file_path: None,
            memory_log: Mutex::new(VecDeque::with_capacity(MAX_MEMORY_LOG_ENTRIES)),
            file_writer: Mutex::new(None),
        }
    }

    /// Create a logger with file output
    pub fn with_file(log_path: impl AsRef<Path>) -> std::io::Result<Self> {
        let path = log_path.as_ref().to_path_buf();

        // Create parent directories if needed
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)?;

        Ok(DeletionLogger {
            log_file_path: Some(path),
            memory_log: Mutex::new(VecDeque::with_capacity(MAX_MEMORY_LOG_ENTRIES)),
            file_writer: Mutex::new(Some(BufWriter::new(file))),
        })
    }

    /// Log a deletion attempt
    pub fn log_deletion(
        &self,
        path: impl Into<String>,
        safety_level: SafetyLevel,
        result: DeletionResult,
        bytes_freed: u64,
        error_message: Option<String>,
    ) {
        let entry = DeletionLogEntry::new(path, safety_level, result, bytes_freed, error_message);

        // Log to standard logger
        match result {
            DeletionResult::Success => {
                log::info!(
                    "Deleted: {} ({} bytes) [{}]",
                    entry.path,
                    bytes_freed,
                    safety_level
                );
            }
            DeletionResult::Failed => {
                log::error!(
                    "Failed to delete: {} [{}] - {}",
                    entry.path,
                    safety_level,
                    entry.error_message.as_deref().unwrap_or("Unknown error")
                );
            }
            DeletionResult::Skipped => {
                log::warn!(
                    "Skipped: {} [{}] - {}",
                    entry.path,
                    safety_level,
                    entry.error_message.as_deref().unwrap_or("No reason given")
                );
            }
            DeletionResult::DryRun => {
                log::info!(
                    "[DRY RUN] Would delete: {} ({} bytes) [{}]",
                    entry.path,
                    bytes_freed,
                    safety_level
                );
            }
        }

        // Add to memory log
        if let Ok(mut log) = self.memory_log.lock() {
            if log.len() >= MAX_MEMORY_LOG_ENTRIES {
                log.pop_front();
            }
            log.push_back(entry.clone());
        }

        // Write to file
        self.write_to_file(&entry);
    }

    /// Write an entry to the log file
    fn write_to_file(&self, entry: &DeletionLogEntry) {
        if let Ok(mut writer_guard) = self.file_writer.lock() {
            if let Some(ref mut writer) = *writer_guard {
                let _ = writeln!(writer, "{}", entry.format());
                let _ = writer.flush();
            }
        }

        // Check if rotation is needed
        self.check_and_rotate();
    }

    /// Check file size and rotate if needed
    fn check_and_rotate(&self) {
        if let Some(ref path) = self.log_file_path {
            if let Ok(metadata) = std::fs::metadata(path) {
                if metadata.len() > MAX_LOG_FILE_SIZE {
                    self.rotate_logs();
                }
            }
        }
    }

    /// Rotate log files
    fn rotate_logs(&self) {
        if let Some(ref path) = self.log_file_path {
            // Close current writer
            if let Ok(mut writer_guard) = self.file_writer.lock() {
                *writer_guard = None;
            }

            // Rotate existing files
            for i in (1..MAX_ROTATED_FILES).rev() {
                let old_path = path.with_extension(format!("log.{}", i));
                let new_path = path.with_extension(format!("log.{}", i + 1));
                let _ = std::fs::rename(&old_path, &new_path);
            }

            // Rename current log to .1
            let rotated_path = path.with_extension("log.1");
            let _ = std::fs::rename(path, &rotated_path);

            // Create new log file
            if let Ok(file) = OpenOptions::new().create(true).append(true).open(path) {
                if let Ok(mut writer_guard) = self.file_writer.lock() {
                    *writer_guard = Some(BufWriter::new(file));
                }
            }

            log::info!("Log file rotated: {:?}", path);
        }
    }

    /// Get all log entries from memory
    pub fn get_entries(&self) -> Vec<DeletionLogEntry> {
        self.memory_log
            .lock()
            .map(|log| log.iter().cloned().collect())
            .unwrap_or_default()
    }

    /// Get log entries as JSON
    pub fn get_entries_json(&self) -> String {
        let entries = self.get_entries();
        serde_json::to_string(&entries).unwrap_or_else(|_| "[]".to_string())
    }

    /// Clear memory log
    pub fn clear(&self) {
        if let Ok(mut log) = self.memory_log.lock() {
            log.clear();
        }
    }

    /// Get summary statistics
    pub fn get_stats(&self) -> LogStats {
        let entries = self.get_entries();
        let mut stats = LogStats::default();

        for entry in entries {
            match entry.result {
                DeletionResult::Success => {
                    stats.success_count += 1;
                    stats.total_bytes_freed += entry.bytes_freed;
                }
                DeletionResult::Failed => stats.failed_count += 1,
                DeletionResult::Skipped => stats.skipped_count += 1,
                DeletionResult::DryRun => {
                    stats.dry_run_count += 1;
                    stats.dry_run_bytes += entry.bytes_freed;
                }
            }
        }

        stats
    }
}

/// Summary statistics for logged operations
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LogStats {
    pub success_count: usize,
    pub failed_count: usize,
    pub skipped_count: usize,
    pub dry_run_count: usize,
    pub total_bytes_freed: u64,
    pub dry_run_bytes: u64,
}

/// Global logger instance
static GLOBAL_LOGGER: std::sync::OnceLock<DeletionLogger> = std::sync::OnceLock::new();

/// Initialize the global logger
pub fn init_global_logger(log_path: Option<&Path>) -> Result<(), String> {
    let logger = match log_path {
        Some(path) => {
            DeletionLogger::with_file(path).map_err(|e| format!("Failed to create log file: {}", e))?
        }
        None => DeletionLogger::new(),
    };

    GLOBAL_LOGGER
        .set(logger)
        .map_err(|_| "Global logger already initialized".to_string())
}

/// Get the global logger
pub fn global_logger() -> &'static DeletionLogger {
    GLOBAL_LOGGER.get_or_init(DeletionLogger::new)
}

/// Convenience function to log a deletion
pub fn log_deletion(
    path: impl Into<String>,
    safety_level: SafetyLevel,
    result: DeletionResult,
    bytes_freed: u64,
    error_message: Option<String>,
) {
    global_logger().log_deletion(path, safety_level, result, bytes_freed, error_message);
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_log_entry_creation() {
        let entry = DeletionLogEntry::new(
            "/test/path",
            SafetyLevel::Safe,
            DeletionResult::Success,
            1024,
            None,
        );

        assert_eq!(entry.path, "/test/path");
        assert_eq!(entry.safety_level, "SAFE");
        assert_eq!(entry.bytes_freed, 1024);
        assert!(entry.error_message.is_none());
    }

    #[test]
    fn test_log_entry_format() {
        let entry = DeletionLogEntry::new(
            "/test/path",
            SafetyLevel::Caution,
            DeletionResult::Failed,
            0,
            Some("Permission denied".to_string()),
        );

        let formatted = entry.format();
        assert!(formatted.contains("FAILED"));
        assert!(formatted.contains("CAUTION"));
        assert!(formatted.contains("/test/path"));
        assert!(formatted.contains("Permission denied"));
    }

    #[test]
    fn test_memory_logger() {
        let logger = DeletionLogger::new();

        logger.log_deletion("/test/1", SafetyLevel::Safe, DeletionResult::Success, 100, None);
        logger.log_deletion("/test/2", SafetyLevel::Caution, DeletionResult::DryRun, 200, None);

        let entries = logger.get_entries();
        assert_eq!(entries.len(), 2);
    }

    #[test]
    fn test_file_logger() {
        let dir = tempdir().unwrap();
        let log_path = dir.path().join("test.log");

        let logger = DeletionLogger::with_file(&log_path).unwrap();
        logger.log_deletion("/test/path", SafetyLevel::Safe, DeletionResult::Success, 1024, None);

        // Flush and check file exists
        drop(logger);
        assert!(log_path.exists());
    }

    #[test]
    fn test_log_stats() {
        let logger = DeletionLogger::new();

        logger.log_deletion("/test/1", SafetyLevel::Safe, DeletionResult::Success, 100, None);
        logger.log_deletion("/test/2", SafetyLevel::Safe, DeletionResult::Success, 200, None);
        logger.log_deletion(
            "/test/3",
            SafetyLevel::Danger,
            DeletionResult::Skipped,
            0,
            Some("Protected".to_string()),
        );

        let stats = logger.get_stats();
        assert_eq!(stats.success_count, 2);
        assert_eq!(stats.skipped_count, 1);
        assert_eq!(stats.total_bytes_freed, 300);
    }

    #[test]
    fn test_deletion_result_display() {
        assert_eq!(format!("{}", DeletionResult::Success), "SUCCESS");
        assert_eq!(format!("{}", DeletionResult::Failed), "FAILED");
        assert_eq!(format!("{}", DeletionResult::Skipped), "SKIPPED");
        assert_eq!(format!("{}", DeletionResult::DryRun), "DRY_RUN");
    }
}
