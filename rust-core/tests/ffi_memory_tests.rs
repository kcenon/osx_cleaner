// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! FFI Memory Management Integration Tests
//!
//! These tests verify that the FFI boundary correctly manages memory:
//! - No memory leaks
//! - Safe deallocation
//! - Proper null pointer handling
//! - Roundtrip allocation/use/free cycles

use osxcore::*;
use std::ffi::{CStr, CString};

#[test]
fn test_ffi_result_allocation_ok() {
    let result = FFIResult::ok(Some("test data".to_string()));

    assert!(result.success);
    assert!(result.error_message.is_null());
    assert!(!result.data.is_null());

    unsafe {
        let data = CStr::from_ptr(result.data);
        assert_eq!(data.to_str().unwrap(), "test data");
        osx_free_string(result.data);
    }
}

#[test]
fn test_ffi_result_allocation_error() {
    let result = FFIResult::err("error message".to_string());

    assert!(!result.success);
    assert!(!result.error_message.is_null());
    assert!(result.data.is_null());

    unsafe {
        let error = CStr::from_ptr(result.error_message);
        assert_eq!(error.to_str().unwrap(), "error message");
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_massive_allocation_deallocation() {
    // Test for memory leaks with many allocations
    for i in 0..100000 {
        let data = format!("iteration {}", i);
        let result = FFIResult::ok(Some(data));
        unsafe {
            osx_free_string(result.data);
        }
    }

    // If we reach here without OOM, no significant leaks
}

#[test]
fn test_massive_error_allocation() {
    // Test error path for memory leaks
    for i in 0..100000 {
        let error = format!("error {}", i);
        let result = FFIResult::err(error);
        unsafe {
            osx_free_string(result.error_message);
        }
    }
}

#[test]
fn test_null_pointer_safety() {
    unsafe {
        // Freeing null pointers should be safe
        osx_free_string(std::ptr::null_mut());

        let result = FFIResult {
            success: true,
            error_message: std::ptr::null_mut(),
            data: std::ptr::null_mut(),
        };

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_core_version_roundtrip() {
    unsafe {
        let version = osx_core_version();
        assert!(!version.is_null());

        let version_str = CStr::from_ptr(version);
        let version_text = version_str.to_str().unwrap();
        assert!(!version_text.is_empty());

        osx_free_string(version);
    }
}

#[test]
fn test_analyze_path_memory() {
    unsafe {
        let path = CString::new("/tmp").unwrap();
        let result = osx_analyze_path(path.as_ptr());

        if result.success && !result.data.is_null() {
            let json_str = CStr::from_ptr(result.data).to_str().unwrap();
            let _: serde_json::Value =
                serde_json::from_str(json_str).expect("Should be valid JSON");
        }

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_classify_path_memory() {
    unsafe {
        let path = CString::new("/tmp").unwrap();
        let result = osx_classify_path(path.as_ptr());

        assert!(result.success);
        assert!(!result.data.is_null());

        let json_str = CStr::from_ptr(result.data).to_str().unwrap();
        let _: serde_json::Value = serde_json::from_str(json_str).expect("Should be valid JSON");

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_validate_batch_memory() {
    unsafe {
        let paths_json = CString::new(r#"["/tmp", "/var/tmp"]"#).unwrap();
        let result = osx_validate_batch(paths_json.as_ptr(), 2);

        assert!(result.success);
        assert!(!result.data.is_null());

        let json_str = CStr::from_ptr(result.data).to_str().unwrap();
        let _: Vec<serde_json::Value> =
            serde_json::from_str(json_str).expect("Should be valid JSON array");

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_get_disk_space_memory() {
    let result = osx_get_disk_space();

    if result.success && !result.data.is_null() {
        unsafe {
            let json_str = CStr::from_ptr(result.data).to_str().unwrap();
            let _: serde_json::Value =
                serde_json::from_str(json_str).expect("Should be valid JSON");

            osx_free_string(result.data);
        }
    }

    unsafe {
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_analyze_home_memory() {
    let result = osx_analyze_home(5);

    assert!(result.success);
    if !result.data.is_null() {
        unsafe {
            let json_str = CStr::from_ptr(result.data).to_str().unwrap();
            let _: Vec<serde_json::Value> =
                serde_json::from_str(json_str).expect("Should be valid JSON array");

            osx_free_string(result.data);
        }
    }
}

#[test]
fn test_analyze_caches_memory() {
    let result = osx_analyze_caches();

    assert!(result.success);
    if !result.data.is_null() {
        unsafe {
            let json_str = CStr::from_ptr(result.data).to_str().unwrap();
            let _: Vec<serde_json::Value> =
                serde_json::from_str(json_str).expect("Should be valid JSON array");

            osx_free_string(result.data);
        }
    }
}

#[test]
fn test_get_running_processes_memory() {
    let result = osx_get_running_processes();

    assert!(result.success);
    assert!(!result.data.is_null());

    unsafe {
        let json_str = CStr::from_ptr(result.data).to_str().unwrap();
        let _: Vec<serde_json::Value> =
            serde_json::from_str(json_str).expect("Should be valid JSON array");

        osx_free_string(result.data);
    }
}

#[test]
fn test_detect_cloud_service_memory() {
    unsafe {
        let path = CString::new("/tmp/test").unwrap();
        let result = osx_detect_cloud_service(path.as_ptr());

        assert!(result.success);
        assert!(!result.data.is_null());

        let json_str = CStr::from_ptr(result.data).to_str().unwrap();
        let _: serde_json::Value = serde_json::from_str(json_str).expect("Should be valid JSON");

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_get_cloud_sync_info_memory() {
    unsafe {
        let path = CString::new("/tmp/test").unwrap();
        let result = osx_get_cloud_sync_info(path.as_ptr());

        assert!(result.success);
        assert!(!result.data.is_null());

        let json_str = CStr::from_ptr(result.data).to_str().unwrap();
        let _: serde_json::Value = serde_json::from_str(json_str).expect("Should be valid JSON");

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_is_safe_to_delete_cloud_memory() {
    unsafe {
        let path = CString::new("/tmp/test").unwrap();
        let result = osx_is_safe_to_delete_cloud(path.as_ptr());

        assert!(result.success);
        assert!(!result.data.is_null());

        let json_str = CStr::from_ptr(result.data).to_str().unwrap();
        let _: serde_json::Value = serde_json::from_str(json_str).expect("Should be valid JSON");

        osx_free_string(result.data);
        osx_free_string(result.error_message);
    }
}

#[test]
fn test_concurrent_allocations() {
    use std::thread;

    let handles: Vec<_> = (0..10)
        .map(|i| {
            thread::spawn(move || {
                for j in 0..1000 {
                    let data = format!("thread {} iteration {}", i, j);
                    let result = FFIResult::ok(Some(data));
                    unsafe {
                        osx_free_string(result.data);
                    }
                }
            })
        })
        .collect();

    for handle in handles {
        handle.join().unwrap();
    }
}

#[test]
fn test_mixed_allocation_patterns() {
    // Mix of ok, err, and null results
    for i in 0..1000 {
        match i % 3 {
            0 => {
                let result = FFIResult::ok(Some(format!("data {}", i)));
                unsafe {
                    osx_free_string(result.data);
                }
            }
            1 => {
                let result = FFIResult::err(format!("error {}", i));
                unsafe {
                    osx_free_string(result.error_message);
                }
            }
            _ => {
                let result = FFIResult::ok(None);
                unsafe {
                    osx_free_string(result.data);
                }
            }
        }
    }
}

#[test]
fn test_large_string_allocation() {
    // Test with large strings (1MB each)
    for _ in 0..10 {
        let large_string = "x".repeat(1024 * 1024);
        let result = FFIResult::ok(Some(large_string));
        unsafe {
            assert!(!result.data.is_null());
            osx_free_string(result.data);
        }
    }
}

#[test]
fn test_init_logger_memory() {
    unsafe {
        // Test with null path
        let result = osx_init_logger(std::ptr::null());
        // May succeed or fail depending on if logger was already initialized
        osx_free_string(result.error_message);
        osx_free_string(result.data);

        // Test with valid path
        let log_path = CString::new("/tmp/test_osx_cleaner.log").unwrap();
        let result = osx_init_logger(log_path.as_ptr());
        osx_free_string(result.error_message);
        osx_free_string(result.data);
    }
}

#[test]
fn test_get_deletion_logs_memory() {
    let result = osx_get_deletion_logs();
    assert!(result.success);

    unsafe {
        if !result.data.is_null() {
            let json_str = CStr::from_ptr(result.data).to_str().unwrap();
            let _: serde_json::Value =
                serde_json::from_str(json_str).expect("Should be valid JSON");
            osx_free_string(result.data);
        }
    }
}

#[test]
fn test_get_log_stats_memory() {
    let result = osx_get_log_stats();
    assert!(result.success);

    unsafe {
        if !result.data.is_null() {
            let json_str = CStr::from_ptr(result.data).to_str().unwrap();
            let _: serde_json::Value =
                serde_json::from_str(json_str).expect("Should be valid JSON");
            osx_free_string(result.data);
        }
    }
}
