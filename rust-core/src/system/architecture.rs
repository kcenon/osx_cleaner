// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! CPU architecture detection
//!
//! Provides detection of Apple Silicon vs Intel architecture and Rosetta 2 status.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::process::Command;

/// CPU architecture type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(C)]
pub enum Architecture {
    /// Apple Silicon (arm64/aarch64)
    AppleSilicon = 0,
    /// Intel x86_64
    Intel = 1,
    /// Unknown or unsupported architecture
    Unknown = 2,
}

impl Architecture {
    /// Detect the current CPU architecture
    pub fn detect() -> Self {
        #[cfg(target_arch = "aarch64")]
        {
            Architecture::AppleSilicon
        }

        #[cfg(target_arch = "x86_64")]
        {
            // On x86_64, we could be running on Intel or under Rosetta
            // Check for Rosetta translation
            if Self::is_running_under_rosetta() {
                // Actually Apple Silicon, running x86_64 under Rosetta
                Architecture::AppleSilicon
            } else {
                Architecture::Intel
            }
        }

        #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
        {
            Architecture::Unknown
        }
    }

    /// Check if the current process is running under Rosetta 2
    pub fn is_running_under_rosetta() -> bool {
        let output = Command::new("sysctl")
            .arg("-n")
            .arg("sysctl.proc_translated")
            .output();

        match output {
            Ok(result) => {
                let value = String::from_utf8_lossy(&result.stdout);
                value.trim() == "1"
            }
            Err(_) => false,
        }
    }

    /// Check if Rosetta 2 is installed on the system
    pub fn is_rosetta_installed() -> bool {
        std::path::Path::new("/Library/Apple/usr/libexec/oah/libRosettaRuntime")
            .exists()
    }

    /// Get the native architecture name
    pub fn name(&self) -> &'static str {
        match self {
            Architecture::AppleSilicon => "arm64",
            Architecture::Intel => "x86_64",
            Architecture::Unknown => "unknown",
        }
    }

    /// Get the human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            Architecture::AppleSilicon => "Apple Silicon (arm64)",
            Architecture::Intel => "Intel (x86_64)",
            Architecture::Unknown => "Unknown Architecture",
        }
    }

    /// Check if this architecture supports Rosetta 2
    pub fn supports_rosetta(&self) -> bool {
        matches!(self, Architecture::AppleSilicon)
    }
}

impl Default for Architecture {
    fn default() -> Self {
        Self::detect()
    }
}

impl fmt::Display for Architecture {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.description())
    }
}

impl From<&str> for Architecture {
    fn from(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "arm64" | "aarch64" | "apple silicon" => Architecture::AppleSilicon,
            "x86_64" | "intel" | "i386" => Architecture::Intel,
            _ => Architecture::Unknown,
        }
    }
}

/// Rosetta 2 cache information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RosettaInfo {
    /// Whether Rosetta 2 is installed
    pub installed: bool,
    /// Whether the current process is running under Rosetta
    pub is_translated: bool,
    /// Path to Rosetta cache (if exists)
    pub cache_path: Option<std::path::PathBuf>,
}

impl RosettaInfo {
    /// Detect Rosetta 2 information
    pub fn detect() -> Self {
        let installed = Architecture::is_rosetta_installed();
        let is_translated = Architecture::is_running_under_rosetta();

        // Rosetta 2 AOT cache location
        let cache_path = if installed {
            let path = std::path::PathBuf::from("/var/db/oah");
            if path.exists() {
                Some(path)
            } else {
                None
            }
        } else {
            None
        };

        Self {
            installed,
            is_translated,
            cache_path,
        }
    }

    /// Get Rosetta 2 cache size in bytes
    pub fn cache_size(&self) -> u64 {
        self.cache_path.as_ref().map_or(0, |path| {
            walkdir::WalkDir::new(path)
                .into_iter()
                .filter_map(|e| e.ok())
                .filter_map(|e| e.metadata().ok())
                .filter(|m| m.is_file())
                .map(|m| m.len())
                .sum()
        })
    }
}

impl Default for RosettaInfo {
    fn default() -> Self {
        Self::detect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_architecture_detect() {
        let arch = Architecture::detect();
        // Should return a valid architecture on macOS
        assert!(matches!(
            arch,
            Architecture::AppleSilicon | Architecture::Intel | Architecture::Unknown
        ));
    }

    #[test]
    fn test_architecture_from_str() {
        assert_eq!(Architecture::from("arm64"), Architecture::AppleSilicon);
        assert_eq!(Architecture::from("aarch64"), Architecture::AppleSilicon);
        assert_eq!(Architecture::from("x86_64"), Architecture::Intel);
        assert_eq!(Architecture::from("intel"), Architecture::Intel);
        assert_eq!(Architecture::from("unknown"), Architecture::Unknown);
    }

    #[test]
    fn test_architecture_name() {
        assert_eq!(Architecture::AppleSilicon.name(), "arm64");
        assert_eq!(Architecture::Intel.name(), "x86_64");
    }

    #[test]
    fn test_rosetta_info() {
        let info = RosettaInfo::detect();
        // Just ensure detection works without panic
        println!("Rosetta installed: {}", info.installed);
        println!("Running under Rosetta: {}", info.is_translated);
    }

    #[test]
    fn test_supports_rosetta() {
        assert!(Architecture::AppleSilicon.supports_rosetta());
        assert!(!Architecture::Intel.supports_rosetta());
    }
}
