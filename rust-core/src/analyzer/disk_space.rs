// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Disk space query module
//!
//! Provides disk space information using system APIs.

use std::path::Path;

use serde::{Deserialize, Serialize};

use super::AnalyzerError;

/// Disk space information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskSpace {
    /// Total disk capacity in bytes
    pub total_bytes: u64,
    /// Used space in bytes
    pub used_bytes: u64,
    /// Available space in bytes
    pub available_bytes: u64,
    /// Usage percentage (0.0 - 100.0)
    pub used_percentage: f64,
    /// Mount point path
    pub mount_point: String,
    /// File system type (e.g., "apfs", "hfs+")
    pub fs_type: String,
}

impl DiskSpace {
    /// Format total space as human-readable string
    pub fn total_formatted(&self) -> String {
        format_bytes(self.total_bytes)
    }

    /// Format used space as human-readable string
    pub fn used_formatted(&self) -> String {
        format_bytes(self.used_bytes)
    }

    /// Format available space as human-readable string
    pub fn available_formatted(&self) -> String {
        format_bytes(self.available_bytes)
    }

    /// Get usage level indicator
    pub fn usage_level(&self) -> UsageLevel {
        match self.used_percentage {
            p if p < 50.0 => UsageLevel::Low,
            p if p < 75.0 => UsageLevel::Normal,
            p if p < 90.0 => UsageLevel::High,
            _ => UsageLevel::Critical,
        }
    }
}

/// Usage level indicator
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum UsageLevel {
    /// Less than 50% used
    Low,
    /// 50-75% used
    Normal,
    /// 75-90% used
    High,
    /// Over 90% used
    Critical,
}

impl UsageLevel {
    /// Get human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            UsageLevel::Low => "Plenty of space available",
            UsageLevel::Normal => "Moderate disk usage",
            UsageLevel::High => "Consider cleaning up",
            UsageLevel::Critical => "Low disk space - cleanup recommended",
        }
    }
}

/// Get disk space information for a path
pub fn get_disk_space(path: &Path) -> Result<DiskSpace, AnalyzerError> {
    use sysinfo::Disks;

    let disks = Disks::new_with_refreshed_list();

    // Find the disk that contains this path
    let disk = disks
        .iter()
        .filter(|d| path.starts_with(d.mount_point()))
        .max_by_key(|d| d.mount_point().as_os_str().len())
        .ok_or_else(|| {
            AnalyzerError::DiskQueryFailed(format!(
                "Could not find disk for path: {}",
                path.display()
            ))
        })?;

    let total = disk.total_space();
    let available = disk.available_space();
    let used = total.saturating_sub(available);
    let percentage = if total > 0 {
        (used as f64 / total as f64) * 100.0
    } else {
        0.0
    };

    Ok(DiskSpace {
        total_bytes: total,
        used_bytes: used,
        available_bytes: available,
        used_percentage: percentage,
        mount_point: disk.mount_point().to_string_lossy().to_string(),
        fs_type: disk.file_system().to_string_lossy().to_string(),
    })
}

/// Format bytes as human-readable string
pub fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB", "PB"];
    const THRESHOLD: f64 = 1024.0;

    if bytes == 0 {
        return "0 B".to_string();
    }

    let mut size = bytes as f64;
    let mut unit_index = 0;

    while size >= THRESHOLD && unit_index < UNITS.len() - 1 {
        size /= THRESHOLD;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.2} {}", size, UNITS[unit_index])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_disk_space_query() {
        let result = get_disk_space(Path::new("/"));

        assert!(result.is_ok());
        let space = result.unwrap();

        assert!(space.total_bytes > 0);
        assert!(space.available_bytes > 0);
        assert!(space.used_bytes <= space.total_bytes);
        assert!(space.used_percentage >= 0.0 && space.used_percentage <= 100.0);
    }

    #[test]
    fn test_disk_space_formatting() {
        let space = DiskSpace {
            total_bytes: 500_000_000_000, // 500 GB
            used_bytes: 250_000_000_000,  // 250 GB
            available_bytes: 250_000_000_000,
            used_percentage: 50.0,
            mount_point: "/".to_string(),
            fs_type: "apfs".to_string(),
        };

        assert!(space.total_formatted().contains("GB"));
        assert!(space.used_formatted().contains("GB"));
        assert!(space.available_formatted().contains("GB"));
    }

    #[test]
    fn test_usage_level() {
        assert_eq!(
            DiskSpace {
                total_bytes: 100,
                used_bytes: 30,
                available_bytes: 70,
                used_percentage: 30.0,
                mount_point: "/".to_string(),
                fs_type: "apfs".to_string(),
            }
            .usage_level(),
            UsageLevel::Low
        );

        assert_eq!(
            DiskSpace {
                total_bytes: 100,
                used_bytes: 60,
                available_bytes: 40,
                used_percentage: 60.0,
                mount_point: "/".to_string(),
                fs_type: "apfs".to_string(),
            }
            .usage_level(),
            UsageLevel::Normal
        );

        assert_eq!(
            DiskSpace {
                total_bytes: 100,
                used_bytes: 85,
                available_bytes: 15,
                used_percentage: 85.0,
                mount_point: "/".to_string(),
                fs_type: "apfs".to_string(),
            }
            .usage_level(),
            UsageLevel::High
        );

        assert_eq!(
            DiskSpace {
                total_bytes: 100,
                used_bytes: 95,
                available_bytes: 5,
                used_percentage: 95.0,
                mount_point: "/".to_string(),
                fs_type: "apfs".to_string(),
            }
            .usage_level(),
            UsageLevel::Critical
        );
    }

    #[test]
    fn test_format_bytes() {
        assert_eq!(format_bytes(0), "0 B");
        assert_eq!(format_bytes(512), "512 B");
        assert_eq!(format_bytes(1024), "1.00 KB");
        assert_eq!(format_bytes(1024 * 1024), "1.00 MB");
        assert_eq!(format_bytes(1024 * 1024 * 1024), "1.00 GB");
        assert_eq!(format_bytes(1024u64 * 1024 * 1024 * 1024), "1.00 TB");
    }
}
