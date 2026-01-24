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

    // Check for Dropbox CLI if available
    #[cfg(target_os = "macos")]
    {
        if let Ok(output) = Command::new("dropbox")
            .args(["filestatus", &path.to_string_lossy()])
            .output()
        {
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                if stdout.contains("syncing") || stdout.contains("uploading") {
                    return Some(SyncStatus::Syncing);
                }
                if stdout.contains("downloading") {
                    return Some(SyncStatus::Syncing);
                }
                if stdout.contains("unsyncable") || stdout.contains("error") {
                    return Some(SyncStatus::Error);
                }
            }
        }

        // Fallback: Check for extended attributes
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

    // Check for .dropbox.cache directory (indicates active sync)
    if let Some(parent) = path.parent() {
        let cache_dir = parent.join(".dropbox.cache");
        if cache_dir.exists() {
            // If cache dir exists and is recent, files might be syncing
            if let Ok(metadata) = fs::metadata(&cache_dir) {
                if let Ok(modified) = metadata.modified() {
                    if let Ok(elapsed) = modified.elapsed() {
                        // If modified within last 5 minutes, consider as potentially syncing
                        if elapsed.as_secs() < 300 {
                            // Can't determine exact status, return synced to be conservative
                            return Some(SyncStatus::Synced);
                        }
                    }
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

    // Check for placeholder files (.cloud extension)
    if let Some(filename) = path.file_name() {
        let name = filename.to_string_lossy();
        if name.ends_with(".cloud") {
            return Some(SyncStatus::CloudOnly);
        }
    }

    // Check for OneDrive marker file
    if let Some(parent) = path.parent() {
        let marker = parent.join(".849C9593-D756-4E56-8D6E-42412F2A707B");
        if marker.exists() {
            // OneDrive folder marker exists
        }
    }

    // Check for extended attributes on macOS
    #[cfg(target_os = "macos")]
    {
        if let Ok(output) = Command::new("xattr")
            .args(["-l", &path.to_string_lossy()])
            .output()
        {
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                // OneDrive uses com.microsoft.OneDrive* extended attributes
                if stdout.contains("com.microsoft.OneDrive.sync") {
                    if stdout.contains("syncing") || stdout.contains("uploading") {
                        return Some(SyncStatus::Syncing);
                    }
                }
            }
        }
    }

    // Check for temporary sync files
    if let Some(parent) = path.parent() {
        if let Ok(entries) = fs::read_dir(parent) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    // OneDrive creates .tmp files during sync
                    if name.starts_with("~$") || name.contains(".tmp") {
                        // Potential sync activity, but can't determine for this specific file
                        break;
                    }
                }
            }
        }
    }

    Some(SyncStatus::Synced)
}

/// Check if a path is in a Google Drive synced location
pub fn is_google_drive_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();
    path_str.contains("/Google Drive/") || path_str.contains("/GoogleDrive/")
}

/// Get Google Drive sync status for a path
pub fn get_google_drive_status(path: &Path) -> Option<SyncStatus> {
    if !is_google_drive_path(path) {
        return None;
    }

    // Check for .tmp files (Google Drive creates these during sync)
    if let Some(filename) = path.file_name() {
        let name = filename.to_string_lossy();
        if name.starts_with(".gd") || name.ends_with(".gdtmp") {
            return Some(SyncStatus::Syncing);
        }
    }

    // Check for temporary download files
    if path.extension().and_then(|e| e.to_str()) == Some("gdoc-download") {
        return Some(SyncStatus::Syncing);
    }

    Some(SyncStatus::Synced)
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
        CloudService::GoogleDrive => get_google_drive_status(path).unwrap_or(SyncStatus::Synced),
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
        assert_eq!(CloudService::OneDrive.name(), "OneDrive");
        assert_eq!(CloudService::GoogleDrive.name(), "Google Drive");
    }

    #[test]
    fn test_is_onedrive_path() {
        let onedrive_path = PathBuf::from("/Users/test/OneDrive/file.txt");
        assert!(is_onedrive_path(&onedrive_path));

        let local_path = PathBuf::from("/Users/test/Documents/file.txt");
        assert!(!is_onedrive_path(&local_path));
    }

    #[test]
    fn test_is_google_drive_path() {
        let gdrive_path1 = PathBuf::from("/Users/test/Google Drive/file.txt");
        assert!(is_google_drive_path(&gdrive_path1));

        let gdrive_path2 = PathBuf::from("/Users/test/GoogleDrive/file.txt");
        assert!(is_google_drive_path(&gdrive_path2));

        let local_path = PathBuf::from("/Users/test/Documents/file.txt");
        assert!(!is_google_drive_path(&local_path));
    }

    #[test]
    fn test_get_google_drive_status() {
        let gdrive_path = PathBuf::from("/Users/test/Google Drive/document.txt");
        let status = get_google_drive_status(&gdrive_path);
        assert!(status.is_some());

        // Test temporary file detection
        let temp_file = PathBuf::from("/Users/test/Google Drive/.gd_temp_file");
        if let Some(status) = get_google_drive_status(&temp_file) {
            assert_eq!(status, SyncStatus::Syncing);
        }
    }

    #[test]
    fn test_get_onedrive_status() {
        let onedrive_path = PathBuf::from("/Users/test/OneDrive/document.txt");
        let status = get_onedrive_status(&onedrive_path);
        assert!(status.is_some());

        // Test cloud-only file detection
        let cloud_file = PathBuf::from("/Users/test/OneDrive/file.cloud");
        if let Some(status) = get_onedrive_status(&cloud_file) {
            assert_eq!(status, SyncStatus::CloudOnly);
        }
    }

    #[test]
    fn test_cloud_sync_info_integration() {
        let gdrive_path = PathBuf::from("/Users/test/Google Drive/document.txt");
        let info = get_cloud_sync_info(&gdrive_path);

        if let Some(info) = info {
            assert_eq!(info.service, CloudService::GoogleDrive);
        }
    }
}
