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

pub mod analyzer;
pub mod cleaner;
pub mod developer;
pub mod fs;
pub mod logging;
pub mod safety;
pub mod scanner;
pub mod system;
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

// ============================================================================
// Safety Validator FFI Functions
// ============================================================================

/// Check if a path is protected (DANGER level - never delete)
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - Returns true if the path is protected, false otherwise
#[no_mangle]
pub unsafe extern "C" fn osx_is_protected(path: *const c_char) -> bool {
    if path.is_null() {
        return true; // Treat null paths as protected for safety
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return true, // Treat invalid paths as protected for safety
    };

    let validator = safety::SafetyValidator::new();
    validator.is_protected(std::path::Path::new(path_str))
}

/// Classify a path and return detailed information as JSON
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON: {"path": "...", "level": "...", "level_value": N, "reason": "...", "is_deletable": bool}
#[no_mangle]
pub unsafe extern "C" fn osx_classify_path(path: *const c_char) -> FFIResult {
    if path.is_null() {
        return FFIResult::err("Path is null".to_string());
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in path".to_string()),
    };

    let validator = safety::SafetyValidator::new();
    let path_obj = std::path::Path::new(path_str);
    let level = validator.classify(path_obj);

    #[derive(serde::Serialize)]
    struct ClassifyResult {
        path: String,
        level: String,
        level_value: u8,
        reason: String,
        is_deletable: bool,
        requires_confirmation: bool,
    }

    let result = ClassifyResult {
        path: path_str.to_string(),
        level: level.to_string(),
        level_value: level as u8,
        reason: level.description().to_string(),
        is_deletable: level.is_deletable(),
        requires_confirmation: level.requires_confirmation(),
    };

    let json = serde_json::to_string(&result).unwrap_or_default();
    FFIResult::ok(Some(json))
}

/// Validate multiple paths in batch
///
/// # Safety
/// - `paths_json` must be a valid null-terminated C string containing a JSON array of paths
/// - `cleanup_level` is 1-4 (Light, Normal, Deep, System)
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON array of validation results
#[no_mangle]
pub unsafe extern "C" fn osx_validate_batch(
    paths_json: *const c_char,
    cleanup_level: i32,
) -> FFIResult {
    if paths_json.is_null() {
        return FFIResult::err("Paths JSON is null".to_string());
    }

    let paths_str = match CStr::from_ptr(paths_json).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in paths JSON".to_string()),
    };

    let paths: Vec<String> = match serde_json::from_str(paths_str) {
        Ok(p) => p,
        Err(e) => return FFIResult::err(format!("Invalid JSON: {}", e)),
    };

    let cleanup = safety::CleanupLevel::from(cleanup_level as u8);
    let path_refs: Vec<&str> = paths.iter().map(|s| s.as_str()).collect();

    let results = safety::validate_batch(&path_refs, cleanup);

    #[derive(serde::Serialize)]
    struct BatchResult {
        path: String,
        success: bool,
        level: Option<String>,
        level_value: Option<u8>,
        error: Option<String>,
    }

    let batch_results: Vec<BatchResult> = paths
        .iter()
        .zip(results.iter())
        .map(|(path, result)| match result {
            Ok(level) => BatchResult {
                path: path.clone(),
                success: true,
                level: Some(level.to_string()),
                level_value: Some(*level as u8),
                error: None,
            },
            Err(e) => BatchResult {
                path: path.clone(),
                success: false,
                level: None,
                level_value: None,
                error: Some(e.to_string()),
            },
        })
        .collect();

    let json = serde_json::to_string(&batch_results).unwrap_or_default();
    FFIResult::ok(Some(json))
}

/// Validate a single cleanup operation
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - `cleanup_level` is 1-4 (Light, Normal, Deep, System)
/// - The returned FFIResult must be freed with `osx_free_result`
#[no_mangle]
pub unsafe extern "C" fn osx_validate_cleanup(
    path: *const c_char,
    cleanup_level: i32,
) -> FFIResult {
    if path.is_null() {
        return FFIResult::err("Path is null".to_string());
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in path".to_string()),
    };

    let cleanup = safety::CleanupLevel::from(cleanup_level as u8);

    match safety::validate_cleanup(path_str, cleanup) {
        Ok(()) => {
            let validator = safety::SafetyValidator::new();
            let level = validator.classify(std::path::Path::new(path_str));

            #[derive(serde::Serialize)]
            struct ValidateResult {
                valid: bool,
                level: String,
                level_value: u8,
            }

            let result = ValidateResult {
                valid: true,
                level: level.to_string(),
                level_value: level as u8,
            };

            let json = serde_json::to_string(&result).unwrap_or_default();
            FFIResult::ok(Some(json))
        }
        Err(e) => FFIResult::err(e.to_string()),
    }
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

// ============================================================================
// Disk Analyzer FFI Functions
// ============================================================================

/// Get disk space information for the root filesystem
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON-encoded DiskSpace struct
#[no_mangle]
pub extern "C" fn osx_get_disk_space() -> FFIResult {
    let analyzer = analyzer::DiskAnalyzer::new();

    match analyzer.get_disk_space() {
        Ok(space) => {
            let json = serde_json::to_string(&space).unwrap_or_default();
            FFIResult::ok(Some(json))
        }
        Err(e) => FFIResult::err(e.to_string()),
    }
}

/// Analyze home directory and get top N directories by size
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON-encoded Vec<DirectoryInfo>
#[no_mangle]
pub extern "C" fn osx_analyze_home(top_n: i32) -> FFIResult {
    let analyzer = analyzer::DiskAnalyzer::new();
    let n = top_n.max(1) as usize;

    let dirs = analyzer.analyze_home_directory(n);
    let json = serde_json::to_string(&dirs).unwrap_or_default();

    FFIResult::ok(Some(json))
}

/// Analyze application caches
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON-encoded Vec<CacheInfo>
#[no_mangle]
pub extern "C" fn osx_analyze_caches() -> FFIResult {
    let analyzer = analyzer::DiskAnalyzer::new();

    let caches = analyzer.analyze_caches();
    let json = serde_json::to_string(&caches).unwrap_or_default();

    FFIResult::ok(Some(json))
}

/// Analyze developer tool components
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON-encoded Vec<DeveloperComponentInfo>
#[no_mangle]
pub extern "C" fn osx_analyze_developer() -> FFIResult {
    let analyzer = analyzer::DiskAnalyzer::new();

    let components = analyzer.analyze_developer();
    let json = serde_json::to_string(&components).unwrap_or_default();

    FFIResult::ok(Some(json))
}

/// Estimate cleanable space
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON-encoded CleanableEstimate
#[no_mangle]
pub extern "C" fn osx_estimate_cleanable() -> FFIResult {
    let analyzer = analyzer::DiskAnalyzer::new();

    let estimate = analyzer.estimate_cleanable();
    let json = serde_json::to_string(&estimate).unwrap_or_default();

    FFIResult::ok(Some(json))
}

/// Perform full disk analysis
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON-encoded AnalysisResult
#[no_mangle]
pub extern "C" fn osx_full_analysis() -> FFIResult {
    let analyzer = analyzer::DiskAnalyzer::new();

    match analyzer.analyze() {
        Ok(result) => {
            let json = serde_json::to_string(&result).unwrap_or_default();
            FFIResult::ok(Some(json))
        }
        Err(e) => FFIResult::err(e.to_string()),
    }
}

// ============================================================================
// Logging FFI Functions
// ============================================================================

/// Initialize the deletion logger with optional file output
///
/// # Safety
/// - `log_path` may be null for memory-only logging
/// - If not null, must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn osx_init_logger(log_path: *const c_char) -> FFIResult {
    let path = if log_path.is_null() {
        None
    } else {
        match CStr::from_ptr(log_path).to_str() {
            Ok(s) => Some(std::path::PathBuf::from(s)),
            Err(_) => return FFIResult::err("Invalid UTF-8 in log path".to_string()),
        }
    };

    match logging::init_global_logger(path.as_deref()) {
        Ok(_) => FFIResult::ok(None),
        Err(e) => FFIResult::err(e),
    }
}

/// Get all deletion log entries as JSON
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
#[no_mangle]
pub extern "C" fn osx_get_deletion_logs() -> FFIResult {
    let json = logging::global_logger().get_entries_json();
    FFIResult::ok(Some(json))
}

/// Get deletion log statistics as JSON
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
#[no_mangle]
pub extern "C" fn osx_get_log_stats() -> FFIResult {
    let stats = logging::global_logger().get_stats();
    let json = serde_json::to_string(&stats).unwrap_or_else(|_| "{}".to_string());
    FFIResult::ok(Some(json))
}

/// Clear all deletion logs from memory
#[no_mangle]
pub extern "C" fn osx_clear_logs() {
    logging::global_logger().clear();
}

// ============================================================================
// Process Detection FFI Functions
// ============================================================================

/// Check if a specific application is running
///
/// # Safety
/// - `app_name` must be a valid null-terminated C string
/// - Returns true if the application is running, false otherwise
#[no_mangle]
pub unsafe extern "C" fn osx_is_app_running(app_name: *const c_char) -> bool {
    if app_name.is_null() {
        return false;
    }

    let name = match CStr::from_ptr(app_name).to_str() {
        Ok(s) => s,
        Err(_) => return false,
    };

    safety::process::is_app_running(name)
}

/// Check if a file or directory is in use by any process
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - Returns true if the path is in use, false otherwise
#[no_mangle]
pub unsafe extern "C" fn osx_is_file_in_use(path: *const c_char) -> bool {
    if path.is_null() {
        return false;
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return false,
    };

    safety::process::is_file_in_use(std::path::Path::new(path_str))
}

/// Check if any application related to a cache path is running
///
/// # Safety
/// - `cache_path` must be a valid null-terminated C string
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON: {"running": bool, "app_name": "..." or null}
#[no_mangle]
pub unsafe extern "C" fn osx_check_related_app_running(cache_path: *const c_char) -> FFIResult {
    if cache_path.is_null() {
        return FFIResult::err("Cache path is null".to_string());
    }

    let path_str = match CStr::from_ptr(cache_path).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in cache path".to_string()),
    };

    #[derive(serde::Serialize)]
    struct RelatedAppResult {
        running: bool,
        app_name: Option<String>,
    }

    let result = match safety::process::check_related_app_running(path_str) {
        Some(app_name) => RelatedAppResult {
            running: true,
            app_name: Some(app_name),
        },
        None => RelatedAppResult {
            running: false,
            app_name: None,
        },
    };

    let json = serde_json::to_string(&result).unwrap_or_default();
    FFIResult::ok(Some(json))
}

/// Get a list of all running processes
///
/// # Safety
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON array: [{"pid": N, "name": "...", "path": "..." or null}, ...]
#[no_mangle]
pub extern "C" fn osx_get_running_processes() -> FFIResult {
    let processes = safety::process::get_running_processes();

    #[derive(serde::Serialize)]
    struct ProcessResult {
        pid: u32,
        name: String,
        path: Option<String>,
    }

    let results: Vec<ProcessResult> = processes
        .into_iter()
        .map(|p| ProcessResult {
            pid: p.pid,
            name: p.name,
            path: p.path,
        })
        .collect();

    let json = serde_json::to_string(&results).unwrap_or_default();
    FFIResult::ok(Some(json))
}

/// Get processes using a specific file or directory
///
/// # Safety
/// - `path` must be a valid null-terminated C string
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON array: [{"pid": N, "name": "...", "path": "..." or null}, ...]
#[no_mangle]
pub unsafe extern "C" fn osx_get_processes_using_path(path: *const c_char) -> FFIResult {
    if path.is_null() {
        return FFIResult::err("Path is null".to_string());
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in path".to_string()),
    };

    let processes = safety::process::get_processes_using_path(std::path::Path::new(path_str));

    #[derive(serde::Serialize)]
    struct ProcessResult {
        pid: u32,
        name: String,
        path: Option<String>,
    }

    let results: Vec<ProcessResult> = processes
        .into_iter()
        .map(|p| ProcessResult {
            pid: p.pid,
            name: p.name,
            path: p.path,
        })
        .collect();

    let json = serde_json::to_string(&results).unwrap_or_default();
    FFIResult::ok(Some(json))
}

/// Get cache paths associated with a specific application
///
/// # Safety
/// - `app_name` must be a valid null-terminated C string
/// - The returned FFIResult must be freed with `osx_free_result`
/// - Returns JSON array of paths: ["path1", "path2", ...]
#[no_mangle]
pub unsafe extern "C" fn osx_get_app_cache_paths(app_name: *const c_char) -> FFIResult {
    if app_name.is_null() {
        return FFIResult::err("App name is null".to_string());
    }

    let name = match CStr::from_ptr(app_name).to_str() {
        Ok(s) => s,
        Err(_) => return FFIResult::err("Invalid UTF-8 in app name".to_string()),
    };

    let mapping = safety::process::AppCacheMapping::new();
    let paths = mapping.get_cache_paths(name);

    let json = serde_json::to_string(&paths).unwrap_or_else(|_| "[]".to_string());
    FFIResult::ok(Some(json))
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

    // Process Detection FFI Tests

    #[test]
    fn test_is_app_running_null() {
        unsafe {
            // Null pointer should return false
            assert!(!osx_is_app_running(std::ptr::null()));
        }
    }

    #[test]
    fn test_is_app_running_valid() {
        use std::ffi::CString;
        unsafe {
            // Test with a valid app name (Finder is usually always running on macOS)
            let app_name = CString::new("Finder").unwrap();
            // Don't assert specific value - just ensure it doesn't crash
            let _ = osx_is_app_running(app_name.as_ptr());
        }
    }

    #[test]
    fn test_is_file_in_use_null() {
        unsafe {
            // Null pointer should return false
            assert!(!osx_is_file_in_use(std::ptr::null()));
        }
    }

    #[test]
    fn test_is_file_in_use_valid() {
        use std::ffi::CString;
        unsafe {
            // Test with a valid path
            let path = CString::new("/tmp").unwrap();
            // Don't assert specific value - just ensure it doesn't crash
            let _ = osx_is_file_in_use(path.as_ptr());
        }
    }

    #[test]
    fn test_check_related_app_running_null() {
        unsafe {
            let result = osx_check_related_app_running(std::ptr::null());
            assert!(!result.success);
            osx_free_string(result.error_message);
        }
    }

    #[test]
    fn test_check_related_app_running_valid() {
        use std::ffi::CString;
        unsafe {
            let cache_path = CString::new("Library/Caches/Google/Chrome").unwrap();
            let result = osx_check_related_app_running(cache_path.as_ptr());
            assert!(result.success);
            // Parse and validate JSON
            if !result.data.is_null() {
                let data_str = CStr::from_ptr(result.data).to_str().unwrap();
                assert!(data_str.contains("running"));
            }
            osx_free_string(result.data);
        }
    }

    #[test]
    fn test_get_running_processes() {
        let result = osx_get_running_processes();
        assert!(result.success);
        // Should return a JSON array (even if empty)
        if !result.data.is_null() {
            unsafe {
                let data_str = CStr::from_ptr(result.data).to_str().unwrap();
                assert!(data_str.starts_with('['));
                assert!(data_str.ends_with(']'));
                osx_free_string(result.data);
            }
        }
    }

    #[test]
    fn test_get_processes_using_path_null() {
        unsafe {
            let result = osx_get_processes_using_path(std::ptr::null());
            assert!(!result.success);
            osx_free_string(result.error_message);
        }
    }

    #[test]
    fn test_get_app_cache_paths_null() {
        unsafe {
            let result = osx_get_app_cache_paths(std::ptr::null());
            assert!(!result.success);
            osx_free_string(result.error_message);
        }
    }

    #[test]
    fn test_get_app_cache_paths_valid() {
        use std::ffi::CString;
        unsafe {
            let app_name = CString::new("Google Chrome").unwrap();
            let result = osx_get_app_cache_paths(app_name.as_ptr());
            assert!(result.success);
            // Should return a JSON array
            if !result.data.is_null() {
                let data_str = CStr::from_ptr(result.data).to_str().unwrap();
                // Chrome should have cache paths defined
                assert!(data_str.contains("Chrome") || data_str == "null");
                osx_free_string(result.data);
            }
        }
    }
}
