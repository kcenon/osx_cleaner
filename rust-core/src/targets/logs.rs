// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Log and Crash Report Management
//!
//! Provides cleanup functionality for diagnostic data:
//! - User application logs (`~/Library/Logs/`)
//! - User crash reports (`~/Library/Logs/DiagnosticReports/`)
//! - System logs (`/var/log/`) - read-only, info only
//! - System crash reports (`/Library/Logs/DiagnosticReports/`) - read-only
//!
//! This module handles cleanup of logs and crash reports based on age,
//! with configurable retention periods and safety checks.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

use rayon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::developer::expand_home;
use crate::safety::SafetyLevel;

/// Default retention period in days
const DEFAULT_RETENTION_DAYS: u32 = 30;

/// Minimum age in days before auto-cleanup (requires confirmation below this)
const MIN_AGE_FOR_AUTO_CLEANUP: u32 = 7;

/// User log directory path
const USER_LOGS_PATH: &str = "~/Library/Logs";

/// User crash reports directory path
const USER_CRASH_REPORTS_PATH: &str = "~/Library/Logs/DiagnosticReports";

/// System log directory path (read-only for info)
const SYSTEM_LOGS_PATH: &str = "/var/log";

/// System crash reports directory path (read-only for info)
const SYSTEM_CRASH_REPORTS_PATH: &str = "/Library/Logs/DiagnosticReports";

/// Console logs directory path
const CONSOLE_LOGS_PATH: &str = "~/Library/Logs/com.apple.Console";

/// Type of log entry
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LogType {
    /// General application log
    AppLog,
    /// Crash report (.crash files)
    CrashReport,
    /// Spin report (.spin files) - for unresponsive apps
    SpinReport,
    /// Hang report (.hang files) - for frozen apps
    HangReport,
    /// System log (managed by newsyslog)
    SystemLog,
    /// Diagnostic report (general .diag files)
    DiagnosticReport,
    /// Console output log
    ConsoleLog,
}

impl LogType {
    /// Get the display name for this log type
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::AppLog => "Application Log",
            Self::CrashReport => "Crash Report",
            Self::SpinReport => "Spin Report",
            Self::HangReport => "Hang Report",
            Self::SystemLog => "System Log",
            Self::DiagnosticReport => "Diagnostic Report",
            Self::ConsoleLog => "Console Log",
        }
    }

    /// Get the file extension pattern for this log type
    pub fn extension(&self) -> Option<&'static str> {
        match self {
            Self::AppLog => Some("log"),
            Self::CrashReport => Some("crash"),
            Self::SpinReport => Some("spin"),
            Self::HangReport => Some("hang"),
            Self::SystemLog => Some("log"),
            Self::DiagnosticReport => Some("diag"),
            Self::ConsoleLog => Some("log"),
        }
    }

    /// Check if this log type is safe to auto-clean
    pub fn is_safe_to_auto_clean(&self) -> bool {
        match self {
            Self::AppLog | Self::CrashReport | Self::SpinReport | Self::HangReport => true,
            Self::ConsoleLog | Self::DiagnosticReport => true,
            Self::SystemLog => false, // System logs are managed by newsyslog
        }
    }
}

/// Source of the log (user or system level)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LogSource {
    /// User-level logs (~/Library/Logs)
    User,
    /// System-level logs (/var/log, /Library/Logs)
    System,
}

impl LogSource {
    /// Get the display name for this source
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::User => "User",
            Self::System => "System",
        }
    }

    /// Check if this source is safe to clean
    pub fn is_cleanable(&self) -> bool {
        matches!(self, Self::User)
    }
}

/// Individual log entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogEntry {
    /// Full path to the log file
    pub path: PathBuf,
    /// Type of log
    pub log_type: LogType,
    /// Source (user or system)
    pub source: LogSource,
    /// File size in bytes
    pub size: u64,
    /// Last modified time
    pub last_modified: SystemTime,
    /// Age in days
    pub age_days: u32,
    /// Application name (if detectable)
    pub app_name: Option<String>,
}

impl LogEntry {
    /// Check if this entry can be safely deleted
    pub fn is_safe_to_delete(&self) -> bool {
        self.source.is_cleanable() && self.log_type.is_safe_to_auto_clean()
    }

    /// Check if this entry requires confirmation before deletion
    pub fn requires_confirmation(&self) -> bool {
        self.age_days < MIN_AGE_FOR_AUTO_CLEANUP
    }

    /// Get the safety level for this entry
    pub fn safety_level(&self) -> SafetyLevel {
        match (&self.source, self.age_days) {
            (LogSource::System, _) => SafetyLevel::Warning,
            (LogSource::User, days) if days < MIN_AGE_FOR_AUTO_CLEANUP => SafetyLevel::Caution,
            (LogSource::User, _) => SafetyLevel::Safe,
        }
    }
}

/// Summary of log scan results
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LogScanSummary {
    /// Total number of log entries found
    pub total_count: usize,
    /// Total size of all logs in bytes
    pub total_size: u64,
    /// Count by log type
    pub by_type: HashMap<LogType, (usize, u64)>,
    /// Count by source
    pub by_source: HashMap<LogSource, (usize, u64)>,
    /// Count by age range
    pub by_age: HashMap<String, (usize, u64)>,
}

impl LogScanSummary {
    /// Create a new summary from log entries
    pub fn from_entries(entries: &[LogEntry]) -> Self {
        let mut summary = Self::default();

        summary.total_count = entries.len();
        summary.total_size = entries.iter().map(|e| e.size).sum();

        // Group by type
        for entry in entries {
            let type_entry = summary.by_type.entry(entry.log_type).or_insert((0, 0));
            type_entry.0 += 1;
            type_entry.1 += entry.size;

            let source_entry = summary.by_source.entry(entry.source).or_insert((0, 0));
            source_entry.0 += 1;
            source_entry.1 += entry.size;

            let age_key = Self::age_bucket(entry.age_days);
            let age_entry = summary.by_age.entry(age_key).or_insert((0, 0));
            age_entry.0 += 1;
            age_entry.1 += entry.size;
        }

        summary
    }

    fn age_bucket(days: u32) -> String {
        match days {
            0..=7 => "0-7 days".to_string(),
            8..=30 => "8-30 days".to_string(),
            31..=90 => "31-90 days".to_string(),
            _ => "90+ days".to_string(),
        }
    }
}

/// Error during log cleanup operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogCleanupError {
    /// Path that failed to be cleaned
    pub path: PathBuf,
    /// Error message
    pub message: String,
}

impl LogCleanupError {
    /// Create a new cleanup error
    pub fn new(path: PathBuf, message: impl Into<String>) -> Self {
        Self {
            path,
            message: message.into(),
        }
    }
}

/// Result of log cleanup operation
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LogCleanupResult {
    /// Number of files cleaned
    pub files_cleaned: usize,
    /// Space freed in bytes
    pub bytes_freed: u64,
    /// Errors encountered during cleanup
    pub errors: Vec<LogCleanupError>,
}

impl LogCleanupResult {
    /// Check if the cleanup was successful (no errors)
    pub fn is_success(&self) -> bool {
        self.errors.is_empty()
    }

    /// Get total files attempted (cleaned + errors)
    pub fn total_attempted(&self) -> usize {
        self.files_cleaned + self.errors.len()
    }
}

/// Log and crash report cleaner
pub struct LogCleaner {
    /// User log paths to scan
    user_log_paths: Vec<PathBuf>,
    /// System log paths (read-only info)
    system_log_paths: Vec<PathBuf>,
    /// Retention period in days
    retention_days: u32,
    /// Whether to include system logs in scan (info only)
    include_system_logs: bool,
}

impl Default for LogCleaner {
    fn default() -> Self {
        Self::new()
    }
}

impl LogCleaner {
    /// Create a new log cleaner with default settings
    pub fn new() -> Self {
        Self {
            user_log_paths: vec![
                expand_home(USER_LOGS_PATH),
                expand_home(USER_CRASH_REPORTS_PATH),
                expand_home(CONSOLE_LOGS_PATH),
            ],
            system_log_paths: vec![
                PathBuf::from(SYSTEM_LOGS_PATH),
                PathBuf::from(SYSTEM_CRASH_REPORTS_PATH),
            ],
            retention_days: DEFAULT_RETENTION_DAYS,
            include_system_logs: false,
        }
    }

    /// Create a log cleaner with custom retention period
    pub fn with_retention(retention_days: u32) -> Self {
        let mut cleaner = Self::new();
        cleaner.retention_days = retention_days;
        cleaner
    }

    /// Set whether to include system logs in scan
    pub fn set_include_system_logs(&mut self, include: bool) {
        self.include_system_logs = include;
    }

    /// Set the retention period in days
    pub fn set_retention_days(&mut self, days: u32) {
        self.retention_days = days;
    }

    /// Get the current retention period
    pub fn retention_days(&self) -> u32 {
        self.retention_days
    }

    /// Scan all log directories and return entries
    pub fn scan_logs(&self) -> Vec<LogEntry> {
        let mut entries = Vec::new();

        // Scan user logs
        for path in &self.user_log_paths {
            if path.exists() {
                entries.extend(self.scan_directory(path, LogSource::User));
            }
        }

        // Optionally scan system logs (info only)
        if self.include_system_logs {
            for path in &self.system_log_paths {
                if path.exists() {
                    entries.extend(self.scan_directory(path, LogSource::System));
                }
            }
        }

        entries
    }

    /// Scan a directory for log files
    fn scan_directory(&self, dir: &Path, source: LogSource) -> Vec<LogEntry> {
        let mut entries = Vec::new();

        if let Ok(read_dir) = fs::read_dir(dir) {
            for entry in read_dir.flatten() {
                let path = entry.path();

                if path.is_file() {
                    if let Some(log_entry) = self.create_log_entry(&path, source) {
                        entries.push(log_entry);
                    }
                } else if path.is_dir() {
                    // Recursively scan subdirectories
                    entries.extend(self.scan_directory(&path, source));
                }
            }
        }

        entries
    }

    /// Create a log entry from a file path
    fn create_log_entry(&self, path: &Path, source: LogSource) -> Option<LogEntry> {
        let metadata = fs::metadata(path).ok()?;
        let log_type = self.detect_log_type(path)?;
        let last_modified = metadata.modified().ok()?;
        let age_days = Self::calculate_age_days(last_modified);
        let app_name = self.extract_app_name(path);

        Some(LogEntry {
            path: path.to_path_buf(),
            log_type,
            source,
            size: metadata.len(),
            last_modified,
            age_days,
            app_name,
        })
    }

    /// Detect the log type based on file extension and path
    fn detect_log_type(&self, path: &Path) -> Option<LogType> {
        let extension = path.extension()?.to_str()?.to_lowercase();
        let path_str = path.to_string_lossy().to_lowercase();

        match extension.as_str() {
            "crash" => Some(LogType::CrashReport),
            "spin" => Some(LogType::SpinReport),
            "hang" => Some(LogType::HangReport),
            "diag" => Some(LogType::DiagnosticReport),
            "log" => {
                if path_str.contains("/var/log") {
                    Some(LogType::SystemLog)
                } else if path_str.contains("com.apple.console") {
                    Some(LogType::ConsoleLog)
                } else {
                    Some(LogType::AppLog)
                }
            }
            _ => None,
        }
    }

    /// Extract application name from path
    fn extract_app_name(&self, path: &Path) -> Option<String> {
        // Try to extract from parent directory name or filename
        let filename = path.file_stem()?.to_str()?;

        // Crash reports often have format: AppName_Date_Identifier.crash
        if let Some(underscore_pos) = filename.find('_') {
            return Some(filename[..underscore_pos].to_string());
        }

        // Try parent directory
        path.parent()
            .and_then(|p| p.file_name())
            .and_then(|n| n.to_str())
            .map(|s| s.to_string())
    }

    /// Calculate age in days from last modified time
    fn calculate_age_days(last_modified: SystemTime) -> u32 {
        let now = SystemTime::now();
        let duration = now.duration_since(last_modified).unwrap_or(Duration::ZERO);
        (duration.as_secs() / 86400) as u32
    }

    /// Filter entries by age (returns entries older than specified days)
    pub fn filter_by_age(&self, entries: &[LogEntry], min_age_days: u32) -> Vec<LogEntry> {
        entries
            .iter()
            .filter(|e| e.age_days >= min_age_days)
            .cloned()
            .collect()
    }

    /// Filter entries by type
    pub fn filter_by_type(&self, entries: &[LogEntry], log_type: LogType) -> Vec<LogEntry> {
        entries
            .iter()
            .filter(|e| e.log_type == log_type)
            .cloned()
            .collect()
    }

    /// Filter entries that are safe to delete
    pub fn filter_safe_to_delete(&self, entries: &[LogEntry]) -> Vec<LogEntry> {
        entries
            .iter()
            .filter(|e| e.is_safe_to_delete())
            .cloned()
            .collect()
    }

    /// Get entries that are older than retention period and safe to clean
    pub fn get_cleanable_entries(&self) -> Vec<LogEntry> {
        let all_entries = self.scan_logs();
        let old_entries = self.filter_by_age(&all_entries, self.retention_days);
        self.filter_safe_to_delete(&old_entries)
    }

    /// Clean log entries (delete files)
    pub fn clean_logs(&self, entries: &[LogEntry]) -> LogCleanupResult {
        let mut result = LogCleanupResult::default();

        // Only clean user logs that are safe to delete
        let safe_entries: Vec<_> = entries.iter().filter(|e| e.is_safe_to_delete()).collect();

        // Use parallel processing for deletion
        let results: Vec<_> = safe_entries
            .par_iter()
            .map(|entry| match fs::remove_file(&entry.path) {
                Ok(()) => Ok(entry.size),
                Err(e) => Err(LogCleanupError::new(entry.path.clone(), e.to_string())),
            })
            .collect();

        // Aggregate results
        for r in results {
            match r {
                Ok(size) => {
                    result.files_cleaned += 1;
                    result.bytes_freed += size;
                }
                Err(e) => {
                    result.errors.push(e);
                }
            }
        }

        result
    }

    /// Perform automatic cleanup of old logs
    pub fn auto_cleanup(&self) -> LogCleanupResult {
        let cleanable = self.get_cleanable_entries();
        self.clean_logs(&cleanable)
    }

    /// Get scan summary without cleaning
    pub fn get_summary(&self) -> LogScanSummary {
        let entries = self.scan_logs();
        LogScanSummary::from_entries(&entries)
    }

    /// Get summary of cleanable entries
    pub fn get_cleanable_summary(&self) -> LogScanSummary {
        let cleanable = self.get_cleanable_entries();
        LogScanSummary::from_entries(&cleanable)
    }

    /// Check if system logs directory is accessible
    pub fn can_access_system_logs(&self) -> bool {
        PathBuf::from(SYSTEM_LOGS_PATH)
            .read_dir()
            .map(|_| true)
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::io::Write;

    #[allow(dead_code)]
    fn create_test_log(dir: &Path, name: &str, content: &str, age_days: u32) -> PathBuf {
        let path = dir.join(name);
        let mut file = File::create(&path).unwrap();
        file.write_all(content.as_bytes()).unwrap();

        // Set modification time
        if age_days > 0 {
            let mtime = SystemTime::now() - Duration::from_secs(age_days as u64 * 86400);
            filetime::set_file_mtime(&path, filetime::FileTime::from_system_time(mtime)).ok();
        }

        path
    }

    #[test]
    fn test_log_type_display_name() {
        assert_eq!(LogType::CrashReport.display_name(), "Crash Report");
        assert_eq!(LogType::AppLog.display_name(), "Application Log");
        assert_eq!(LogType::SpinReport.display_name(), "Spin Report");
    }

    #[test]
    fn test_log_type_extension() {
        assert_eq!(LogType::CrashReport.extension(), Some("crash"));
        assert_eq!(LogType::SpinReport.extension(), Some("spin"));
        assert_eq!(LogType::HangReport.extension(), Some("hang"));
    }

    #[test]
    fn test_log_type_safe_to_auto_clean() {
        assert!(LogType::CrashReport.is_safe_to_auto_clean());
        assert!(LogType::AppLog.is_safe_to_auto_clean());
        assert!(!LogType::SystemLog.is_safe_to_auto_clean());
    }

    #[test]
    fn test_log_source_cleanable() {
        assert!(LogSource::User.is_cleanable());
        assert!(!LogSource::System.is_cleanable());
    }

    #[test]
    fn test_log_cleaner_default() {
        let cleaner = LogCleaner::new();
        assert_eq!(cleaner.retention_days(), DEFAULT_RETENTION_DAYS);
    }

    #[test]
    fn test_log_cleaner_with_retention() {
        let cleaner = LogCleaner::with_retention(60);
        assert_eq!(cleaner.retention_days(), 60);
    }

    #[test]
    fn test_detect_log_type() {
        let cleaner = LogCleaner::new();

        let crash_path = Path::new("/tmp/test.crash");
        assert_eq!(
            cleaner.detect_log_type(crash_path),
            Some(LogType::CrashReport)
        );

        let spin_path = Path::new("/tmp/test.spin");
        assert_eq!(
            cleaner.detect_log_type(spin_path),
            Some(LogType::SpinReport)
        );

        let hang_path = Path::new("/tmp/test.hang");
        assert_eq!(
            cleaner.detect_log_type(hang_path),
            Some(LogType::HangReport)
        );
    }

    #[test]
    fn test_calculate_age_days() {
        let now = SystemTime::now();
        assert_eq!(LogCleaner::calculate_age_days(now), 0);

        let week_ago = now - Duration::from_secs(7 * 86400);
        assert_eq!(LogCleaner::calculate_age_days(week_ago), 7);
    }

    #[test]
    fn test_log_entry_safety_level() {
        let entry = LogEntry {
            path: PathBuf::from("/tmp/test.crash"),
            log_type: LogType::CrashReport,
            source: LogSource::User,
            size: 1024,
            last_modified: SystemTime::now() - Duration::from_secs(60 * 86400),
            age_days: 60,
            app_name: Some("TestApp".to_string()),
        };

        assert_eq!(entry.safety_level(), SafetyLevel::Safe);
        assert!(entry.is_safe_to_delete());
        assert!(!entry.requires_confirmation());
    }

    #[test]
    fn test_log_entry_requires_confirmation() {
        let entry = LogEntry {
            path: PathBuf::from("/tmp/test.crash"),
            log_type: LogType::CrashReport,
            source: LogSource::User,
            size: 1024,
            last_modified: SystemTime::now() - Duration::from_secs(3 * 86400),
            age_days: 3,
            app_name: Some("TestApp".to_string()),
        };

        assert_eq!(entry.safety_level(), SafetyLevel::Caution);
        assert!(entry.requires_confirmation());
    }

    #[test]
    fn test_log_scan_summary() {
        let entries = vec![
            LogEntry {
                path: PathBuf::from("/tmp/test1.crash"),
                log_type: LogType::CrashReport,
                source: LogSource::User,
                size: 1024,
                last_modified: SystemTime::now(),
                age_days: 0,
                app_name: None,
            },
            LogEntry {
                path: PathBuf::from("/tmp/test2.log"),
                log_type: LogType::AppLog,
                source: LogSource::User,
                size: 2048,
                last_modified: SystemTime::now(),
                age_days: 35,
                app_name: None,
            },
        ];

        let summary = LogScanSummary::from_entries(&entries);

        assert_eq!(summary.total_count, 2);
        assert_eq!(summary.total_size, 3072);
        assert!(summary.by_type.contains_key(&LogType::CrashReport));
        assert!(summary.by_type.contains_key(&LogType::AppLog));
    }

    #[test]
    fn test_filter_by_age() {
        let cleaner = LogCleaner::new();

        let entries = vec![
            LogEntry {
                path: PathBuf::from("/tmp/old.crash"),
                log_type: LogType::CrashReport,
                source: LogSource::User,
                size: 1024,
                last_modified: SystemTime::now() - Duration::from_secs(60 * 86400),
                age_days: 60,
                app_name: None,
            },
            LogEntry {
                path: PathBuf::from("/tmp/new.crash"),
                log_type: LogType::CrashReport,
                source: LogSource::User,
                size: 1024,
                last_modified: SystemTime::now(),
                age_days: 0,
                app_name: None,
            },
        ];

        let filtered = cleaner.filter_by_age(&entries, 30);
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].age_days, 60);
    }

    #[test]
    fn test_filter_safe_to_delete() {
        let cleaner = LogCleaner::new();

        let entries = vec![
            LogEntry {
                path: PathBuf::from("/tmp/user.crash"),
                log_type: LogType::CrashReport,
                source: LogSource::User,
                size: 1024,
                last_modified: SystemTime::now(),
                age_days: 0,
                app_name: None,
            },
            LogEntry {
                path: PathBuf::from("/var/log/system.log"),
                log_type: LogType::SystemLog,
                source: LogSource::System,
                size: 1024,
                last_modified: SystemTime::now(),
                age_days: 0,
                app_name: None,
            },
        ];

        let filtered = cleaner.filter_safe_to_delete(&entries);
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].source, LogSource::User);
    }

    #[test]
    fn test_extract_app_name() {
        let cleaner = LogCleaner::new();

        // Test crash report format: AppName_Date_Identifier.crash
        let path = Path::new("/tmp/Safari_2024-01-01_123456.crash");
        assert_eq!(cleaner.extract_app_name(path), Some("Safari".to_string()));

        // Test simple filename
        let path2 = Path::new("/tmp/DiagnosticReports/Chrome/test.log");
        assert_eq!(cleaner.extract_app_name(path2), Some("Chrome".to_string()));
    }
}
