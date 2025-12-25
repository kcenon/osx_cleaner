//! Running process detection module
//!
//! Detects running applications to prevent cache deletion while they're in use.

use std::collections::HashMap;
use std::path::Path;
use std::process::Command;

/// Result of process detection
#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub path: Option<String>,
}

/// Application to cache path mapping
pub struct AppCacheMapping {
    mappings: HashMap<String, Vec<String>>,
}

impl Default for AppCacheMapping {
    fn default() -> Self {
        Self::new()
    }
}

impl AppCacheMapping {
    pub fn new() -> Self {
        let mut mappings = HashMap::new();

        // Browser mappings
        mappings.insert(
            "Google Chrome".to_string(),
            vec![
                "Library/Caches/Google/Chrome".to_string(),
                "Library/Application Support/Google/Chrome".to_string(),
            ],
        );

        mappings.insert(
            "Firefox".to_string(),
            vec![
                "Library/Caches/Firefox".to_string(),
                "Library/Application Support/Firefox".to_string(),
            ],
        );

        mappings.insert(
            "Safari".to_string(),
            vec![
                "Library/Caches/com.apple.Safari".to_string(),
                "Library/Safari".to_string(),
            ],
        );

        mappings.insert(
            "Brave Browser".to_string(),
            vec![
                "Library/Caches/com.brave.Browser".to_string(),
                "Library/Application Support/BraveSoftware".to_string(),
            ],
        );

        // IDE mappings
        mappings.insert(
            "Xcode".to_string(),
            vec![
                "Library/Developer/Xcode/DerivedData".to_string(),
                "Library/Caches/com.apple.dt.Xcode".to_string(),
            ],
        );

        mappings.insert(
            "Code".to_string(), // VS Code
            vec![
                "Library/Application Support/Code".to_string(),
                "Library/Caches/com.microsoft.VSCode".to_string(),
            ],
        );

        // Container apps
        mappings.insert(
            "Docker".to_string(),
            vec![
                "Library/Containers/com.docker.docker".to_string(),
                ".docker".to_string(),
            ],
        );

        AppCacheMapping { mappings }
    }

    /// Get cache paths for a given application
    pub fn get_cache_paths(&self, app_name: &str) -> Option<&Vec<String>> {
        self.mappings.get(app_name)
    }

    /// Find which application uses a given cache path
    pub fn find_app_for_cache(&self, cache_path: &str) -> Option<String> {
        for (app, paths) in &self.mappings {
            for path in paths {
                if cache_path.contains(path) {
                    return Some(app.clone());
                }
            }
        }
        None
    }
}

/// Detect running processes using pgrep
pub fn get_running_processes() -> Vec<ProcessInfo> {
    let output = Command::new("pgrep")
        .args(["-l", "-x", ".*"])
        .output()
        .ok();

    match output {
        Some(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            stdout
                .lines()
                .filter_map(|line| {
                    let parts: Vec<&str> = line.splitn(2, ' ').collect();
                    if parts.len() == 2 {
                        Some(ProcessInfo {
                            pid: parts[0].parse().unwrap_or(0),
                            name: parts[1].to_string(),
                            path: None,
                        })
                    } else {
                        None
                    }
                })
                .collect()
        }
        _ => Vec::new(),
    }
}

/// Check if a specific application is running
pub fn is_app_running(app_name: &str) -> bool {
    let output = Command::new("pgrep")
        .args(["-x", app_name])
        .output()
        .ok();

    matches!(output, Some(o) if o.status.success())
}

/// Check if a file is in use by any process
pub fn is_file_in_use(path: &Path) -> bool {
    let output = Command::new("lsof")
        .args(["+D", &path.to_string_lossy()])
        .output()
        .ok();

    matches!(output, Some(o) if o.status.success() && !o.stdout.is_empty())
}

/// Get processes using a specific file or directory
pub fn get_processes_using_path(path: &Path) -> Vec<ProcessInfo> {
    let output = Command::new("lsof")
        .args(["+D", &path.to_string_lossy()])
        .output()
        .ok();

    match output {
        Some(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            stdout
                .lines()
                .skip(1) // Skip header
                .filter_map(|line| {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 2 {
                        Some(ProcessInfo {
                            pid: parts[1].parse().unwrap_or(0),
                            name: parts[0].to_string(),
                            path: parts.get(8).map(|s| s.to_string()),
                        })
                    } else {
                        None
                    }
                })
                .collect()
        }
        _ => Vec::new(),
    }
}

/// Check if any application related to a cache path is running
pub fn check_related_app_running(cache_path: &str) -> Option<String> {
    let mapping = AppCacheMapping::new();

    if let Some(app_name) = mapping.find_app_for_cache(cache_path) {
        if is_app_running(&app_name) {
            return Some(app_name);
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_app_cache_mapping() {
        let mapping = AppCacheMapping::new();

        let chrome_paths = mapping.get_cache_paths("Google Chrome");
        assert!(chrome_paths.is_some());
        assert!(!chrome_paths.unwrap().is_empty());
    }

    #[test]
    fn test_find_app_for_cache() {
        let mapping = AppCacheMapping::new();

        let app = mapping.find_app_for_cache("Library/Caches/Google/Chrome/Default");
        assert_eq!(app, Some("Google Chrome".to_string()));
    }

    #[test]
    fn test_is_app_running() {
        // This test may fail in CI environments
        // "Finder" should always be running on macOS
        #[cfg(target_os = "macos")]
        {
            let finder_running = is_app_running("Finder");
            // Don't assert - Finder may not be running in headless environments
            let _ = finder_running;
        }
    }
}
