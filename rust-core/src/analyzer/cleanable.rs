// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Cleanable space estimation module
//!
//! Calculates and categorizes cleanable space by safety level.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use super::categories::{CacheInfo, DeveloperComponentInfo};
use crate::safety::SafetyLevel;

/// Estimated cleanable space grouped by safety level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanableEstimate {
    /// Safe to delete immediately (auto-regenerates)
    pub safe_bytes: u64,
    /// Requires attention (may need rebuild)
    pub caution_bytes: u64,
    /// Requires careful consideration (re-download needed)
    pub warning_bytes: u64,
    /// Total cleanable bytes
    pub total_bytes: u64,
    /// Detailed breakdown of cleanable items
    pub items: Vec<CleanableItem>,
    /// Number of items by safety level
    pub item_counts: SafetyLevelCounts,
}

impl CleanableEstimate {
    /// Format safe bytes as human-readable string
    pub fn safe_formatted(&self) -> String {
        super::disk_space::format_bytes(self.safe_bytes)
    }

    /// Format caution bytes as human-readable string
    pub fn caution_formatted(&self) -> String {
        super::disk_space::format_bytes(self.caution_bytes)
    }

    /// Format warning bytes as human-readable string
    pub fn warning_formatted(&self) -> String {
        super::disk_space::format_bytes(self.warning_bytes)
    }

    /// Format total bytes as human-readable string
    pub fn total_formatted(&self) -> String {
        super::disk_space::format_bytes(self.total_bytes)
    }

    /// Get percentage of safe vs total
    pub fn safe_percentage(&self) -> f64 {
        if self.total_bytes == 0 {
            return 0.0;
        }
        (self.safe_bytes as f64 / self.total_bytes as f64) * 100.0
    }
}

/// Individual cleanable item
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanableItem {
    /// Item name
    pub name: String,
    /// Item path
    pub path: PathBuf,
    /// Size in bytes
    pub size: u64,
    /// Safety level
    pub safety_level: SafetyLevel,
    /// Category (cache, developer, etc.)
    pub category: String,
    /// Description of what will happen if deleted
    pub impact_description: String,
}

impl CleanableItem {
    /// Format size as human-readable string
    pub fn size_formatted(&self) -> String {
        super::disk_space::format_bytes(self.size)
    }
}

/// Counts by safety level
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SafetyLevelCounts {
    pub safe: usize,
    pub caution: usize,
    pub warning: usize,
    pub danger: usize,
}

/// Estimate cleanable space from cache and developer analysis
pub fn estimate_cleanable(
    caches: &[CacheInfo],
    developer: &[DeveloperComponentInfo],
) -> CleanableEstimate {
    let mut items = Vec::new();
    let mut safe_bytes = 0u64;
    let mut caution_bytes = 0u64;
    let mut warning_bytes = 0u64;
    let mut counts = SafetyLevelCounts::default();

    // Process cache items
    for cache in caches {
        // Skip cloud-synced apps in cleanable estimate
        if cache.is_cloud_app {
            continue;
        }

        let impact = match cache.safety_level {
            SafetyLevel::Safe => "Will be regenerated automatically",
            SafetyLevel::Caution => "May need to sign in again or rebuild cache",
            SafetyLevel::Warning => "May need to re-download data",
            SafetyLevel::Danger => "Should not be deleted",
        };

        match cache.safety_level {
            SafetyLevel::Safe => {
                safe_bytes += cache.size;
                counts.safe += 1;
            }
            SafetyLevel::Caution => {
                caution_bytes += cache.size;
                counts.caution += 1;
            }
            SafetyLevel::Warning => {
                warning_bytes += cache.size;
                counts.warning += 1;
            }
            SafetyLevel::Danger => {
                counts.danger += 1;
                // Don't add to cleanable total
                continue;
            }
        }

        items.push(CleanableItem {
            name: cache.app_name.clone(),
            path: cache.path.clone(),
            size: cache.size,
            safety_level: cache.safety_level,
            category: "Application Cache".to_string(),
            impact_description: impact.to_string(),
        });
    }

    // Process developer components
    for component in developer {
        let impact = match component.safety_level {
            SafetyLevel::Safe => "Build cache - regenerates on next build",
            SafetyLevel::Caution => "May need to rebuild projects or reconfigure simulators",
            SafetyLevel::Warning => "Debug symbols - re-download from device on next connection",
            SafetyLevel::Danger => "Critical developer data - do not delete",
        };

        match component.safety_level {
            SafetyLevel::Safe => {
                safe_bytes += component.size;
                counts.safe += 1;
            }
            SafetyLevel::Caution => {
                caution_bytes += component.size;
                counts.caution += 1;
            }
            SafetyLevel::Warning => {
                warning_bytes += component.size;
                counts.warning += 1;
            }
            SafetyLevel::Danger => {
                counts.danger += 1;
                continue;
            }
        }

        items.push(CleanableItem {
            name: component.component.clone(),
            path: component.path.clone(),
            size: component.size,
            safety_level: component.safety_level,
            category: format!("Developer: {}", component.tool),
            impact_description: impact.to_string(),
        });
    }

    // Sort items by size descending
    items.sort_by(|a, b| b.size.cmp(&a.size));

    let total_bytes = safe_bytes + caution_bytes + warning_bytes;

    CleanableEstimate {
        safe_bytes,
        caution_bytes,
        warning_bytes,
        total_bytes,
        items,
        item_counts: counts,
    }
}

/// Filter cleanable items by maximum safety level
pub fn filter_by_safety(estimate: &CleanableEstimate, max_level: SafetyLevel) -> CleanableEstimate {
    let filtered_items: Vec<CleanableItem> = estimate
        .items
        .iter()
        .filter(|item| item.safety_level <= max_level)
        .cloned()
        .collect();

    let mut safe_bytes = 0u64;
    let mut caution_bytes = 0u64;
    let mut warning_bytes = 0u64;
    let mut counts = SafetyLevelCounts::default();

    for item in &filtered_items {
        match item.safety_level {
            SafetyLevel::Safe => {
                safe_bytes += item.size;
                counts.safe += 1;
            }
            SafetyLevel::Caution => {
                caution_bytes += item.size;
                counts.caution += 1;
            }
            SafetyLevel::Warning => {
                warning_bytes += item.size;
                counts.warning += 1;
            }
            SafetyLevel::Danger => {
                counts.danger += 1;
            }
        }
    }

    CleanableEstimate {
        safe_bytes,
        caution_bytes,
        warning_bytes,
        total_bytes: safe_bytes + caution_bytes + warning_bytes,
        items: filtered_items,
        item_counts: counts,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_cache(name: &str, size: u64, safety: SafetyLevel) -> CacheInfo {
        CacheInfo {
            app_name: name.to_string(),
            bundle_id: Some(format!("com.test.{}", name.to_lowercase())),
            path: PathBuf::from(format!("/tmp/caches/{}", name)),
            size,
            safety_level: safety,
            is_cloud_app: false,
        }
    }

    fn create_test_developer(name: &str, size: u64, safety: SafetyLevel) -> DeveloperComponentInfo {
        DeveloperComponentInfo {
            component: name.to_string(),
            path: PathBuf::from(format!("/tmp/developer/{}", name)),
            size,
            safety_level: safety,
            description: format!("Test component: {}", name),
            tool: "Test".to_string(),
        }
    }

    #[test]
    fn test_estimate_cleanable_empty() {
        let estimate = estimate_cleanable(&[], &[]);

        assert_eq!(estimate.total_bytes, 0);
        assert_eq!(estimate.safe_bytes, 0);
        assert_eq!(estimate.caution_bytes, 0);
        assert_eq!(estimate.warning_bytes, 0);
        assert!(estimate.items.is_empty());
    }

    #[test]
    fn test_estimate_cleanable_with_caches() {
        let caches = vec![
            create_test_cache("Safari", 100, SafetyLevel::Safe),
            create_test_cache("Chrome", 200, SafetyLevel::Safe),
            create_test_cache("Slack", 50, SafetyLevel::Caution),
        ];

        let estimate = estimate_cleanable(&caches, &[]);

        assert_eq!(estimate.safe_bytes, 300);
        assert_eq!(estimate.caution_bytes, 50);
        assert_eq!(estimate.total_bytes, 350);
        assert_eq!(estimate.item_counts.safe, 2);
        assert_eq!(estimate.item_counts.caution, 1);
    }

    #[test]
    fn test_estimate_cleanable_with_developer() {
        let developer = vec![
            create_test_developer("DerivedData", 1000, SafetyLevel::Safe),
            create_test_developer("iOS DeviceSupport", 500, SafetyLevel::Warning),
        ];

        let estimate = estimate_cleanable(&[], &developer);

        assert_eq!(estimate.safe_bytes, 1000);
        assert_eq!(estimate.warning_bytes, 500);
        assert_eq!(estimate.total_bytes, 1500);
    }

    #[test]
    fn test_estimate_excludes_danger() {
        let caches = vec![
            create_test_cache("Safe", 100, SafetyLevel::Safe),
            create_test_cache("Dangerous", 999, SafetyLevel::Danger),
        ];

        let estimate = estimate_cleanable(&caches, &[]);

        // Danger items should not be included in totals
        assert_eq!(estimate.total_bytes, 100);
        assert_eq!(estimate.item_counts.danger, 1);
    }

    #[test]
    fn test_filter_by_safety() {
        let caches = vec![
            create_test_cache("Safe", 100, SafetyLevel::Safe),
            create_test_cache("Caution", 200, SafetyLevel::Caution),
            create_test_cache("Warning", 300, SafetyLevel::Warning),
        ];

        let estimate = estimate_cleanable(&caches, &[]);
        let filtered = filter_by_safety(&estimate, SafetyLevel::Safe);

        assert_eq!(filtered.total_bytes, 100);
        assert_eq!(filtered.items.len(), 1);

        let filtered_caution = filter_by_safety(&estimate, SafetyLevel::Caution);
        assert_eq!(filtered_caution.total_bytes, 300);
        assert_eq!(filtered_caution.items.len(), 2);
    }

    #[test]
    fn test_cleanable_formatting() {
        let estimate = CleanableEstimate {
            safe_bytes: 1024 * 1024 * 100,     // 100 MB
            caution_bytes: 1024 * 1024 * 50,   // 50 MB
            warning_bytes: 1024 * 1024 * 1024, // 1 GB
            total_bytes: 1024 * 1024 * 100 + 1024 * 1024 * 50 + 1024 * 1024 * 1024,
            items: vec![],
            item_counts: SafetyLevelCounts::default(),
        };

        assert!(estimate.safe_formatted().contains("MB"));
        assert!(estimate.warning_formatted().contains("GB"));
        assert!(estimate.total_formatted().contains("GB"));
    }

    #[test]
    fn test_safe_percentage() {
        let estimate = CleanableEstimate {
            safe_bytes: 50,
            caution_bytes: 30,
            warning_bytes: 20,
            total_bytes: 100,
            items: vec![],
            item_counts: SafetyLevelCounts::default(),
        };

        assert!((estimate.safe_percentage() - 50.0).abs() < 0.001);
    }

    #[test]
    fn test_items_sorted_by_size() {
        let caches = vec![
            create_test_cache("Small", 10, SafetyLevel::Safe),
            create_test_cache("Large", 1000, SafetyLevel::Safe),
            create_test_cache("Medium", 100, SafetyLevel::Safe),
        ];

        let estimate = estimate_cleanable(&caches, &[]);

        assert_eq!(estimate.items[0].name, "Large");
        assert_eq!(estimate.items[1].name, "Medium");
        assert_eq!(estimate.items[2].name, "Small");
    }
}
