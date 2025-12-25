// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! OSX Cleaner Core Engine
//!
//! This crate provides the core functionality for OSX Cleaner:
//! - File system scanning and analysis
//! - Safety validation for cleanup operations
//! - Cleanup execution with parallel processing
//!
//! The crate exposes a C FFI interface for integration with Swift.

pub mod cleaner;
pub mod developer;
pub mod fs;
pub mod safety;
pub mod scanner;
pub mod targets;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

/// Result returned by FFI functions
#[repr(C)]
pub struct FFIResult {
    pub success: bool,
    pub error_message: *mut c_char,
    pub data: *mut c_char,
}

impl FFIResult {
    pub fn ok(data: Option<String>) -> Self {
        FFIResult {
            success: true,
            error_message: ptr::null_mut(),
            data: data
                .map(|s| CString::new(s).unwrap().into_raw())
                .unwrap_or(ptr::null_mut()),
        }
    }

    pub fn err(message: String) -> Self {
        FFIResult {
            success: false,
            error_message: CString::new(message).unwrap().into_raw(),
            data: ptr::null_mut(),
        }
    }
}

/// Initialize the Rust core library
///
/// # Safety
/// This function initializes the logger and should be called once at startup.
#[no_mangle]
pub extern "C" fn osx_core_init() -> bool {
    env_logger::try_init().is_ok()
}

/// Get the version of the Rust core library
///
/// # Safety
/// The returned string must be freed with `osx_free_string`.
#[no_mangle]
pub extern "C" fn osx_core_version() -> *mut c_char {
    let version = env!("CARGO_PKG_VERSION");
    CString::new(version).unwrap().into_raw()
}

/// Analyze a path for cleanup opportunities
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - The returned FFIResult must be freed with `osx_free_result`
#[no_mangle]
pub unsafe extern "C" fn osx_analyze_path(path: *const c_char) -> FFIResult {
    if path.is_null() {
        return FFIResult::err("Path is null".to_string());
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in path".to_string()),
    };

    match scanner::analyze(path_str) {
        Ok(result) => {
            let json = serde_json::to_string(&result).unwrap_or_default();
            FFIResult::ok(Some(json))
        }
        Err(e) => FFIResult::err(e.to_string()),
    }
}

/// Calculate safety level for a path
///
/// # Safety
/// - `path` must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn osx_calculate_safety(path: *const c_char) -> i32 {
    if path.is_null() {
        return -1;
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    safety::calculate_safety_level(path_str) as i32
}

/// Clean a path with the specified cleanup level
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - `cleanup_level` is 1-4 (Light, Normal, Deep, System)
/// - `dry_run` if true, no files will be deleted
#[no_mangle]
pub unsafe extern "C" fn osx_clean_path(
    path: *const c_char,
    cleanup_level: i32,
    dry_run: bool,
) -> FFIResult {
    if path.is_null() {
        return FFIResult::err("Path is null".to_string());
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in path".to_string()),
    };

    let config = cleaner::CleanConfig::from_safety_level(cleanup_level as u8, dry_run);

    match cleaner::clean(path_str, &config) {
        Ok(result) => {
            let json = serde_json::to_string(&result).unwrap_or_default();
            FFIResult::ok(Some(json))
        }
        Err(e) => FFIResult::err(e.to_string()),
    }
}

/// Free a string allocated by Rust
///
/// # Safety
/// - `s` must be a pointer returned by a Rust FFI function
/// - `s` must not be used after this call
#[no_mangle]
pub unsafe extern "C" fn osx_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// Free an FFIResult
///
/// # Safety
/// - `result` must be a valid pointer to an FFIResult
#[no_mangle]
pub unsafe extern "C" fn osx_free_result(result: *mut FFIResult) {
    if !result.is_null() {
        let r = Box::from_raw(result);
        osx_free_string(r.error_message);
        osx_free_string(r.data);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffi_result_ok() {
        let result = FFIResult::ok(Some("test".to_string()));
        assert!(result.success);
        assert!(result.error_message.is_null());
        assert!(!result.data.is_null());

        unsafe {
            osx_free_string(result.data);
        }
    }

    #[test]
    fn test_ffi_result_err() {
        let result = FFIResult::err("error".to_string());
        assert!(!result.success);
        assert!(!result.error_message.is_null());
        assert!(result.data.is_null());

        unsafe {
            osx_free_string(result.error_message);
        }
    }
}
