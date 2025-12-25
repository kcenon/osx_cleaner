// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Cloud sync status detection module
//!
//! Detects if files are being synced by cloud services to prevent data loss.

use std::fs;
use std::path::Path;
use std::process::Command;

/// Cloud service type
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CloudService {
    ICloud,
    Dropbox,
    OneDrive,
    GoogleDrive,
    Unknown,
}

impl CloudService {
    pub fn name(&self) -> &'static str {
        match self {
            CloudService::ICloud => "iCloud",
            CloudService::Dropbox => "Dropbox",
            CloudService::OneDrive => "OneDrive",
            CloudService::GoogleDrive => "Google Drive",
            CloudService::Unknown => "Unknown",
        }
    }
}

/// Sync status of a file
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SyncStatus {
    /// File is fully synced
    Synced,
    /// File is currently being synced
    Syncing,
    /// File is pending sync
    Pending,
    /// File only exists in cloud (not downloaded)
    CloudOnly,
    /// File only exists locally (not uploaded)
    LocalOnly,
    /// Sync error
    Error,
    /// Not a cloud-synced file
    NotApplicable,
}

/// Cloud sync information for a path
#[derive(Debug, Clone)]
pub struct CloudSyncInfo {
    pub service: CloudService,
    pub status: SyncStatus,
    pub path: String,
}

/// Check if a path is in an iCloud synced location
pub fn is_icloud_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();

    // iCloud Drive location
    if path_str.contains("Library/Mobile Documents") {
        return true;
    }

    // iCloud Desktop & Documents
    if path_str.contains("com~apple~CloudDocs") {
        return true;
    }

    false
}

/// Get iCloud sync status for a path
pub fn get_icloud_status(path: &Path) -> Option<SyncStatus> {
    if !is_icloud_path(path) {
        return None;
    }

    // Check for .icloud file (cloud-only placeholder)
    let filename = path.file_name()?.to_string_lossy();
    if filename.starts_with('.') && filename.ends_with(".icloud") {
        return Some(SyncStatus::CloudOnly);
    }

    // Use brctl to check status on macOS
    #[cfg(target_os = "macos")]
    {
        let output = Command::new("brctl")
            .args(["status", &path.to_string_lossy()])
            .output()
            .ok()?;

        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            if stdout.contains("downloading") {
                return Some(SyncStatus::Syncing);
            }
            if stdout.contains("uploading") {
                return Some(SyncStatus::Syncing);
            }
            if stdout.contains("pending") {
                return Some(SyncStatus::Pending);
            }
            return Some(SyncStatus::Synced);
        }
    }

    Some(SyncStatus::Synced)
}

/// Check if a path is in a Dropbox synced location
pub fn is_dropbox_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();

    // Default Dropbox location
    if path_str.contains("/Dropbox/") {
        return true;
    }

    // Check for Dropbox info file
    if let Some(home) = dirs::home_dir() {
        let dropbox_info = home.join(".dropbox/info.json");
        if dropbox_info.exists() {
            if let Ok(content) = fs::read_to_string(&dropbox_info) {
                // Parse JSON to find actual Dropbox path
                if let Some(start) = content.find("\"path\": \"") {
                    let start = start + 9;
                    if let Some(end) = content[start..].find('"') {
                        let dropbox_path = &content[start..start + end];
                        if path_str.starts_with(dropbox_path) {
                            return true;
                        }
                    }
                }
            }
        }
    }

    false
}

/// Get Dropbox sync status for a path
pub fn get_dropbox_status(path: &Path) -> Option<SyncStatus> {
    if !is_dropbox_path(path) {
        return None;
    }

    // Check for extended attributes
    #[cfg(target_os = "macos")]
    {
        let output = Command::new("xattr")
            .args(["-p", "com.dropbox.attrs", &path.to_string_lossy()])
            .output()
            .ok();

        if let Some(output) = output {
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                if stdout.contains("syncing") {
                    return Some(SyncStatus::Syncing);
                }
            }
        }
    }

    Some(SyncStatus::Synced)
}

/// Check if a path is in a OneDrive synced location
pub fn is_onedrive_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();
    path_str.contains("/OneDrive")
}

/// Get OneDrive sync status for a path
pub fn get_onedrive_status(path: &Path) -> Option<SyncStatus> {
    if !is_onedrive_path(path) {
        return None;
    }

    // Check for placeholder files
    if let Some(filename) = path.file_name() {
        let name = filename.to_string_lossy();
        if name.ends_with(".cloud") {
            return Some(SyncStatus::CloudOnly);
        }
    }

    Some(SyncStatus::Synced)
}

/// Check if a path is in a Google Drive synced location
pub fn is_google_drive_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();
    path_str.contains("/Google Drive/") || path_str.contains("/GoogleDrive/")
}

/// Detect cloud service for a path
pub fn detect_cloud_service(path: &Path) -> Option<CloudService> {
    if is_icloud_path(path) {
        Some(CloudService::ICloud)
    } else if is_dropbox_path(path) {
        Some(CloudService::Dropbox)
    } else if is_onedrive_path(path) {
        Some(CloudService::OneDrive)
    } else if is_google_drive_path(path) {
        Some(CloudService::GoogleDrive)
    } else {
        None
    }
}

/// Get comprehensive cloud sync info for a path
pub fn get_cloud_sync_info(path: &Path) -> Option<CloudSyncInfo> {
    let service = detect_cloud_service(path)?;

    let status = match service {
        CloudService::ICloud => get_icloud_status(path).unwrap_or(SyncStatus::Synced),
        CloudService::Dropbox => get_dropbox_status(path).unwrap_or(SyncStatus::Synced),
        CloudService::OneDrive => get_onedrive_status(path).unwrap_or(SyncStatus::Synced),
        CloudService::GoogleDrive => SyncStatus::Synced,
        CloudService::Unknown => SyncStatus::NotApplicable,
    };

    Some(CloudSyncInfo {
        service,
        status,
        path: path.to_string_lossy().to_string(),
    })
}

/// Check if a path is safe to delete from a cloud sync perspective
pub fn is_safe_to_delete_cloud(path: &Path) -> Result<(), String> {
    if let Some(info) = get_cloud_sync_info(path) {
        match info.status {
            SyncStatus::Syncing => {
                return Err(format!(
                    "{} is currently syncing to {}",
                    path.display(),
                    info.service.name()
                ));
            }
            SyncStatus::Pending => {
                return Err(format!(
                    "{} is pending sync to {}",
                    path.display(),
                    info.service.name()
                ));
            }
            SyncStatus::CloudOnly => {
                return Err(format!(
                    "{} only exists in {} cloud - deletion will remove from all devices",
                    path.display(),
                    info.service.name()
                ));
            }
            _ => {}
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_is_icloud_path() {
        let icloud_path = PathBuf::from("/Users/test/Library/Mobile Documents/com~apple~CloudDocs");
        assert!(is_icloud_path(&icloud_path));

        let local_path = PathBuf::from("/Users/test/Documents");
        assert!(!is_icloud_path(&local_path));
    }

    #[test]
    fn test_detect_cloud_service() {
        let icloud = PathBuf::from("/Users/test/Library/Mobile Documents/file.txt");
        assert_eq!(detect_cloud_service(&icloud), Some(CloudService::ICloud));

        let dropbox = PathBuf::from("/Users/test/Dropbox/file.txt");
        assert_eq!(detect_cloud_service(&dropbox), Some(CloudService::Dropbox));

        let local = PathBuf::from("/Users/test/Documents/file.txt");
        assert_eq!(detect_cloud_service(&local), None);
    }

    #[test]
    fn test_cloud_service_name() {
        assert_eq!(CloudService::ICloud.name(), "iCloud");
        assert_eq!(CloudService::Dropbox.name(), "Dropbox");
    }
}
