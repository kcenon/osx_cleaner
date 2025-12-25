// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! macOS version detection and parsing
//!
//! Provides version parsing from sw_vers command and version comparison utilities.

use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::fmt;
use std::process::Command;

/// macOS version representation
///
/// Stores major, minor, and patch version numbers (e.g., 15.1.0 for Sequoia 15.1)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(C)]
pub struct Version {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
}

impl Version {
    /// Create a new Version
    pub fn new(major: u32, minor: u32, patch: u32) -> Self {
        Self {
            major,
            minor,
            patch,
        }
    }

    /// Detect the current macOS version using sw_vers
    pub fn detect() -> Option<Self> {
        let output = Command::new("sw_vers")
            .arg("-productVersion")
            .output()
            .ok()?;

        if !output.status.success() {
            return None;
        }

        let version_str = String::from_utf8_lossy(&output.stdout);
        Self::parse(version_str.trim())
    }

    /// Parse a version string (e.g., "15.1.0" or "14.5")
    pub fn parse(version_str: &str) -> Option<Self> {
        let parts: Vec<&str> = version_str.split('.').collect();
        if parts.is_empty() {
            return None;
        }

        let major = parts.first()?.parse().ok()?;
        let minor = parts.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);
        let patch = parts.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);

        Some(Self::new(major, minor, patch))
    }

    /// Check if version is at least the specified version
    pub fn is_at_least(&self, major: u32, minor: u32) -> bool {
        self.major > major || (self.major == major && self.minor >= minor)
    }

    /// Check if version is at least the specified version (with patch)
    pub fn is_at_least_patch(&self, major: u32, minor: u32, patch: u32) -> bool {
        match self.major.cmp(&major) {
            Ordering::Greater => true,
            Ordering::Less => false,
            Ordering::Equal => match self.minor.cmp(&minor) {
                Ordering::Greater => true,
                Ordering::Less => false,
                Ordering::Equal => self.patch >= patch,
            },
        }
    }

    /// Get the macOS codename for this version
    pub fn codename(&self) -> &'static str {
        match self.major {
            15 => "Sequoia",
            14 => "Sonoma",
            13 => "Ventura",
            12 => "Monterey",
            11 => "Big Sur",
            10 if self.minor == 15 => "Catalina",
            10 if self.minor == 14 => "Mojave",
            _ => "Unknown",
        }
    }

    /// Check if this version is within a specific range (inclusive)
    pub fn is_in_range(&self, min: &Version, max: &Version) -> bool {
        *self >= *min && *self <= *max
    }
}

impl Default for Version {
    fn default() -> Self {
        Self::detect().unwrap_or(Self::new(0, 0, 0))
    }
}

impl Ord for Version {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.major.cmp(&other.major) {
            Ordering::Equal => match self.minor.cmp(&other.minor) {
                Ordering::Equal => self.patch.cmp(&other.patch),
                ord => ord,
            },
            ord => ord,
        }
    }
}

impl PartialOrd for Version {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl fmt::Display for Version {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.patch == 0 {
            write!(f, "{}.{}", self.major, self.minor)
        } else {
            write!(f, "{}.{}.{}", self.major, self.minor, self.patch)
        }
    }
}

impl From<(u32, u32, u32)> for Version {
    fn from((major, minor, patch): (u32, u32, u32)) -> Self {
        Self::new(major, minor, patch)
    }
}

impl From<(u32, u32)> for Version {
    fn from((major, minor): (u32, u32)) -> Self {
        Self::new(major, minor, 0)
    }
}

/// Known macOS version constants
pub mod known_versions {
    use super::Version;

    pub const SEQUOIA: Version = Version {
        major: 15,
        minor: 0,
        patch: 0,
    };
    pub const SEQUOIA_15_1: Version = Version {
        major: 15,
        minor: 1,
        patch: 0,
    };
    pub const SONOMA: Version = Version {
        major: 14,
        minor: 0,
        patch: 0,
    };
    pub const VENTURA: Version = Version {
        major: 13,
        minor: 0,
        patch: 0,
    };
    pub const MONTEREY: Version = Version {
        major: 12,
        minor: 0,
        patch: 0,
    };
    pub const BIG_SUR: Version = Version {
        major: 11,
        minor: 0,
        patch: 0,
    };
    pub const CATALINA: Version = Version {
        major: 10,
        minor: 15,
        patch: 0,
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_parse() {
        assert_eq!(
            Version::parse("15.1.0"),
            Some(Version::new(15, 1, 0))
        );
        assert_eq!(
            Version::parse("14.5"),
            Some(Version::new(14, 5, 0))
        );
        assert_eq!(
            Version::parse("10.15.7"),
            Some(Version::new(10, 15, 7))
        );
    }

    #[test]
    fn test_version_is_at_least() {
        let v = Version::new(15, 1, 0);
        assert!(v.is_at_least(15, 0));
        assert!(v.is_at_least(15, 1));
        assert!(!v.is_at_least(15, 2));
        assert!(v.is_at_least(14, 5));
        assert!(!v.is_at_least(16, 0));
    }

    #[test]
    fn test_version_ordering() {
        let v14 = Version::new(14, 0, 0);
        let v15 = Version::new(15, 0, 0);
        let v15_1 = Version::new(15, 1, 0);
        let v15_1_1 = Version::new(15, 1, 1);

        assert!(v14 < v15);
        assert!(v15 < v15_1);
        assert!(v15_1 < v15_1_1);
    }

    #[test]
    fn test_version_codename() {
        assert_eq!(Version::new(15, 0, 0).codename(), "Sequoia");
        assert_eq!(Version::new(14, 5, 0).codename(), "Sonoma");
        assert_eq!(Version::new(10, 15, 7).codename(), "Catalina");
    }

    #[test]
    fn test_version_display() {
        assert_eq!(Version::new(15, 1, 0).to_string(), "15.1");
        assert_eq!(Version::new(15, 1, 1).to_string(), "15.1.1");
    }

    #[test]
    fn test_version_detect() {
        // This test will pass on macOS
        if cfg!(target_os = "macos") {
            let version = Version::detect();
            assert!(version.is_some());
            let v = version.unwrap();
            assert!(v.major >= 10);
        }
    }
}
