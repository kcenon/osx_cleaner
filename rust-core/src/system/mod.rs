// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! System information module
//!
//! Provides comprehensive macOS system detection:
//! - Version detection and parsing
//! - Architecture detection (Intel vs Apple Silicon)
//! - Rosetta 2 status
//! - SIP (System Integrity Protection) status
//! - Version-specific path resolution

pub mod architecture;
pub mod paths;
pub mod version;

// Re-export main types for convenience
pub use architecture::{Architecture, RosettaInfo};
pub use paths::{CleanupMethod, SpecialTarget, VersionPaths};
pub use version::{known_versions, Version};

use serde::{Deserialize, Serialize};
use std::ffi::CStr;
use std::os::raw::c_char;
use std::process::Command;
use std::ptr;

/// Comprehensive system information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemInfo {
    /// macOS version
    pub os_version: Version,
    /// macOS codename (e.g., "Sequoia", "Sonoma")
    pub os_name: String,
    /// CPU architecture
    pub architecture: Architecture,
    /// System Integrity Protection status
    pub sip_enabled: bool,
    /// Rosetta 2 installation status
    pub rosetta_installed: bool,
    /// Whether current process is running under Rosetta
    pub running_under_rosetta: bool,
}

impl SystemInfo {
    /// Detect current system information
    pub fn detect() -> Self {
        let os_version = Version::detect().unwrap_or_default();
        let os_name = os_version.codename().to_string();
        let architecture = Architecture::detect();
        let rosetta_info = RosettaInfo::detect();
        let sip_enabled = Self::check_sip_status();

        Self {
            os_version,
            os_name,
            architecture,
            sip_enabled,
            rosetta_installed: rosetta_info.installed,
            running_under_rosetta: rosetta_info.is_translated,
        }
    }

    /// Check if the version is at least the specified version
    pub fn is_version_at_least(&self, major: u32, minor: u32) -> bool {
        self.os_version.is_at_least(major, minor)
    }

    /// Get version-specific paths for this system
    pub fn get_version_specific_paths(&self) -> VersionPaths {
        VersionPaths::for_version(&self.os_version)
    }

    /// Check if running on Apple Silicon
    pub fn is_apple_silicon(&self) -> bool {
        matches!(self.architecture, Architecture::AppleSilicon)
    }

    /// Check if running on Intel
    pub fn is_intel(&self) -> bool {
        matches!(self.architecture, Architecture::Intel)
    }

    /// Check System Integrity Protection status
    fn check_sip_status() -> bool {
        let output = Command::new("csrutil").arg("status").output();

        match output {
            Ok(result) => {
                let status = String::from_utf8_lossy(&result.stdout);
                status.contains("enabled")
            }
            Err(_) => true, // Assume SIP is enabled if we can't check
        }
    }

    /// Get a summary string for display
    pub fn summary(&self) -> String {
        format!(
            "macOS {} {} ({}) - SIP: {}",
            self.os_version,
            self.os_name,
            self.architecture.name(),
            if self.sip_enabled {
                "enabled"
            } else {
                "disabled"
            }
        )
    }

    /// Check if this version has the mediaanalysisd bug (15.1)
    pub fn has_mediaanalysisd_bug(&self) -> bool {
        self.os_version.is_at_least_patch(15, 1, 0) && !self.os_version.is_at_least_patch(15, 2, 0)
    }

    /// Check if this version uses Safari profiles (14.x+)
    pub fn has_safari_profiles(&self) -> bool {
        self.os_version.is_at_least(14, 0)
    }
}

impl Default for SystemInfo {
    fn default() -> Self {
        Self::detect()
    }
}

// ============================================================================
// FFI Functions
// ============================================================================

/// Get system information as JSON
///
/// # Safety
/// The returned string must be freed with `osx_free_string`.
#[no_mangle]
pub extern "C" fn osx_system_info() -> *mut c_char {
    let info = SystemInfo::detect();
    match serde_json::to_string(&info) {
        Ok(json) => crate::safe_cstring_or_null(json),
        Err(e) => {
            log::error!("Failed to serialize system info: {}", e);
            ptr::null_mut()
        }
    }
}

/// Get macOS version string (e.g., "15.1.0")
///
/// # Safety
/// The returned string must be freed with `osx_free_string`.
#[no_mangle]
pub extern "C" fn osx_macos_version() -> *mut c_char {
    let version = Version::detect().unwrap_or_default();
    crate::safe_cstring_or_null(version.to_string())
}

/// Get macOS codename (e.g., "Sequoia")
///
/// # Safety
/// The returned string must be freed with `osx_free_string`.
#[no_mangle]
pub extern "C" fn osx_macos_codename() -> *mut c_char {
    let version = Version::detect().unwrap_or_default();
    crate::safe_cstring_or_null(version.codename())
}

/// Get CPU architecture (0=AppleSilicon, 1=Intel, 2=Unknown)
#[no_mangle]
pub extern "C" fn osx_architecture() -> i32 {
    Architecture::detect() as i32
}

/// Check if running on Apple Silicon
#[no_mangle]
pub extern "C" fn osx_is_apple_silicon() -> bool {
    matches!(Architecture::detect(), Architecture::AppleSilicon)
}

/// Check if Rosetta 2 is installed
#[no_mangle]
pub extern "C" fn osx_is_rosetta_installed() -> bool {
    Architecture::is_rosetta_installed()
}

/// Check if current process is running under Rosetta
#[no_mangle]
pub extern "C" fn osx_is_running_under_rosetta() -> bool {
    Architecture::is_running_under_rosetta()
}

/// Check if SIP (System Integrity Protection) is enabled
#[no_mangle]
pub extern "C" fn osx_is_sip_enabled() -> bool {
    SystemInfo::check_sip_status()
}

/// Check if version is at least the specified version
#[no_mangle]
pub extern "C" fn osx_is_version_at_least(major: u32, minor: u32) -> bool {
    Version::detect()
        .map(|v| v.is_at_least(major, minor))
        .unwrap_or(false)
}

/// Get version-specific paths as JSON
///
/// # Safety
/// The returned string must be freed with `osx_free_string`.
#[no_mangle]
pub extern "C" fn osx_version_specific_paths() -> *mut c_char {
    let version = Version::detect().unwrap_or_default();
    let paths = VersionPaths::for_version(&version);

    match serde_json::to_string(&paths) {
        Ok(json) => crate::safe_cstring_or_null(json),
        Err(e) => {
            log::error!("Failed to serialize version paths: {}", e);
            ptr::null_mut()
        }
    }
}

/// Get special cleanup targets for the current version as JSON
///
/// # Safety
/// The returned string must be freed with `osx_free_string`.
#[no_mangle]
pub extern "C" fn osx_special_targets() -> *mut c_char {
    let version = Version::detect().unwrap_or_default();
    let paths = VersionPaths::for_version(&version);
    let targets: Vec<&SpecialTarget> = paths.targets_for_version(&version);

    match serde_json::to_string(&targets) {
        Ok(json) => crate::safe_cstring_or_null(json),
        Err(e) => {
            log::error!("Failed to serialize special targets: {}", e);
            ptr::null_mut()
        }
    }
}

/// Check if the current version has a known bug
///
/// # Safety
/// - `bug_name` must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn osx_has_known_bug(bug_name: *const c_char) -> bool {
    if bug_name.is_null() {
        return false;
    }

    let bug_str = match CStr::from_ptr(bug_name).to_str() {
        Ok(s) => s,
        Err(_) => return false,
    };

    let info = SystemInfo::detect();

    match bug_str {
        "mediaanalysisd" => info.has_mediaanalysisd_bug(),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_system_info_detect() {
        let info = SystemInfo::detect();
        println!("System: {}", info.summary());
        assert!(info.os_version.major >= 10);
    }

    #[test]
    fn test_system_info_methods() {
        let info = SystemInfo::detect();

        // Test architecture checks
        assert!(
            info.is_apple_silicon()
                || info.is_intel()
                || matches!(info.architecture, Architecture::Unknown)
        );
    }

    #[test]
    fn test_version_specific_paths() {
        let info = SystemInfo::detect();
        let paths = info.get_version_specific_paths();

        assert!(!paths.system_caches.is_empty());
    }

    #[test]
    fn test_ffi_system_info() {
        let ptr = osx_system_info();
        assert!(!ptr.is_null());

        unsafe {
            let json_str = CStr::from_ptr(ptr)
                .to_str()
                .expect("FFI string should be valid UTF-8");
            let _: SystemInfo =
                serde_json::from_str(json_str).expect("SystemInfo JSON should be valid");
            super::super::osx_free_string(ptr);
        }
    }

    #[test]
    fn test_ffi_version() {
        let ptr = osx_macos_version();
        assert!(!ptr.is_null());

        unsafe {
            let version_str = CStr::from_ptr(ptr)
                .to_str()
                .expect("FFI version string should be valid UTF-8");
            assert!(Version::parse(version_str).is_some());
            super::super::osx_free_string(ptr);
        }
    }

    #[test]
    fn test_ffi_architecture() {
        let arch = osx_architecture();
        assert!(arch >= 0 && arch <= 2);
    }

    #[test]
    fn test_safari_profiles_check() {
        let v14 = SystemInfo {
            os_version: Version::new(14, 0, 0),
            os_name: "Sonoma".to_string(),
            architecture: Architecture::AppleSilicon,
            sip_enabled: true,
            rosetta_installed: false,
            running_under_rosetta: false,
        };
        assert!(v14.has_safari_profiles());

        let v13 = SystemInfo {
            os_version: Version::new(13, 0, 0),
            os_name: "Ventura".to_string(),
            architecture: Architecture::AppleSilicon,
            sip_enabled: true,
            rosetta_installed: false,
            running_under_rosetta: false,
        };
        assert!(!v13.has_safari_profiles());
    }

    #[test]
    fn test_mediaanalysisd_bug_check() {
        let v15_1 = SystemInfo {
            os_version: Version::new(15, 1, 0),
            os_name: "Sequoia".to_string(),
            architecture: Architecture::AppleSilicon,
            sip_enabled: true,
            rosetta_installed: false,
            running_under_rosetta: false,
        };
        assert!(v15_1.has_mediaanalysisd_bug());

        let v15_2 = SystemInfo {
            os_version: Version::new(15, 2, 0),
            os_name: "Sequoia".to_string(),
            architecture: Architecture::AppleSilicon,
            sip_enabled: true,
            rosetta_installed: false,
            running_under_rosetta: false,
        };
        assert!(!v15_2.has_mediaanalysisd_bug());
    }
}
