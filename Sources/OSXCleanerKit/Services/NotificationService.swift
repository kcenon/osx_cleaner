// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import Foundation
import UserNotifications

/// Disk usage threshold levels for notifications
public enum DiskThreshold: Int, Comparable {
    case warning = 85    // 85% - Yellow warning
    case critical = 90   // 90% - Orange recommendation
    case emergency = 95  // 95% - Red auto-cleanup trigger

    public var message: String {
        switch self {
        case .warning:
            return "Disk space is running low"
        case .critical:
            return "Disk space is critically low"
        case .emergency:
            return "Disk space is almost full"
        }
    }

    public var recommendation: String {
        switch self {
        case .warning:
            return "Consider running 'osxcleaner clean --level light' to free up space."
        case .critical:
            return "Run 'osxcleaner clean --level normal' to free up space soon."
        case .emergency:
            return "Immediate action required. Running automatic cleanup."
        }
    }

    public static func < (lhs: DiskThreshold, rhs: DiskThreshold) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Service for sending system notifications
///
/// Uses macOS UserNotifications framework to send disk usage warnings
/// and cleanup completion notifications.
public final class NotificationService {

    // MARK: - Singleton

    public static let shared = NotificationService()

    // MARK: - Properties

    private let notificationCenter: UNUserNotificationCenter
    private let bundleIdentifier = "com.osxcleaner"
    private var isAuthorized = false

    // MARK: - Initialization

    public init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - Permission

    /// Request notification permission from the user
    /// - Returns: True if permission was granted
    @discardableResult
    public func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted

            if granted {
                AppLogger.shared.info("Notification permission granted")
            } else {
                AppLogger.shared.warning("Notification permission denied")
            }

            return granted
        } catch {
            AppLogger.shared.error("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Check current authorization status
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        return settings.authorizationStatus
    }

    // MARK: - Disk Warning Notifications

    /// Send a disk usage warning notification
    /// - Parameters:
    ///   - usagePercent: Current disk usage percentage
    ///   - threshold: The threshold that was exceeded
    ///   - availableSpace: Available disk space in bytes
    public func sendDiskWarning(
        usagePercent: Double,
        threshold: DiskThreshold,
        availableSpace: UInt64
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "OSX Cleaner - \(threshold.message)"
        content.body = """
            Disk usage: \(String(format: "%.1f", usagePercent))%
            Available: \(formatBytes(availableSpace))

            \(threshold.recommendation)
            """
        content.sound = threshold == .emergency ? .defaultCritical : .default
        content.categoryIdentifier = "\(bundleIdentifier).disk-warning"

        // Add action buttons
        content.userInfo = [
            "threshold": threshold.rawValue,
            "usagePercent": usagePercent,
            "availableSpace": availableSpace
        ]

        await sendNotification(
            identifier: "\(bundleIdentifier).disk-warning.\(threshold.rawValue)",
            content: content
        )
    }

    /// Send a cleanup completion notification
    /// - Parameters:
    ///   - freedSpace: Space freed by cleanup in bytes
    ///   - filesRemoved: Number of files removed
    ///   - level: Cleanup level that was performed
    public func sendCleanupComplete(
        freedSpace: UInt64,
        filesRemoved: Int,
        level: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "OSX Cleaner - Cleanup Complete"
        content.body = """
            Level: \(level.capitalized)
            Space freed: \(formatBytes(freedSpace))
            Files removed: \(filesRemoved)
            """
        content.sound = .default
        content.categoryIdentifier = "\(bundleIdentifier).cleanup-complete"

        content.userInfo = [
            "freedSpace": freedSpace,
            "filesRemoved": filesRemoved,
            "level": level
        ]

        await sendNotification(
            identifier: "\(bundleIdentifier).cleanup-complete.\(Date().timeIntervalSince1970)",
            content: content
        )
    }

    /// Send a cleanup error notification
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - level: Cleanup level that was attempted
    public func sendCleanupError(error: Error, level: String) async {
        let content = UNMutableNotificationContent()
        content.title = "OSX Cleaner - Cleanup Failed"
        content.body = """
            Level: \(level.capitalized)
            Error: \(error.localizedDescription)

            Check logs for details.
            """
        content.sound = .defaultCritical
        content.categoryIdentifier = "\(bundleIdentifier).cleanup-error"

        await sendNotification(
            identifier: "\(bundleIdentifier).cleanup-error.\(Date().timeIntervalSince1970)",
            content: content
        )
    }

    // MARK: - Notification Categories

    /// Register notification categories with action buttons
    public func registerNotificationCategories() {
        // Disk warning category with cleanup action
        let cleanupAction = UNNotificationAction(
            identifier: "\(bundleIdentifier).action.cleanup",
            title: "Run Cleanup",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "\(bundleIdentifier).action.dismiss",
            title: "Dismiss",
            options: []
        )

        let diskWarningCategory = UNNotificationCategory(
            identifier: "\(bundleIdentifier).disk-warning",
            actions: [cleanupAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Cleanup complete category
        let viewLogsAction = UNNotificationAction(
            identifier: "\(bundleIdentifier).action.view-logs",
            title: "View Logs",
            options: [.foreground]
        )

        let cleanupCompleteCategory = UNNotificationCategory(
            identifier: "\(bundleIdentifier).cleanup-complete",
            actions: [viewLogsAction],
            intentIdentifiers: [],
            options: []
        )

        // Cleanup error category
        let retryAction = UNNotificationAction(
            identifier: "\(bundleIdentifier).action.retry",
            title: "Retry",
            options: [.foreground]
        )

        let cleanupErrorCategory = UNNotificationCategory(
            identifier: "\(bundleIdentifier).cleanup-error",
            actions: [retryAction, viewLogsAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            diskWarningCategory,
            cleanupCompleteCategory,
            cleanupErrorCategory
        ])
    }

    // MARK: - Pending Notifications

    /// Remove all pending notifications
    public func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Remove specific pending notification
    public func removePendingNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Private Methods

    private func sendNotification(
        identifier: String,
        content: UNNotificationContent
    ) async {
        // Ensure authorization
        let status = await checkAuthorizationStatus()
        guard status == .authorized else {
            AppLogger.shared.warning("Cannot send notification: not authorized")
            return
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await notificationCenter.add(request)
            AppLogger.shared.info("Notification sent: \(identifier)")
        } catch {
            AppLogger.shared.error("Failed to send notification: \(error)")
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - Notification Delegate

/// Delegate for handling notification responses
public class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    public static let shared = NotificationDelegate()

    /// Called when user interacts with a notification
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        AppLogger.shared.info("Notification action received: \(actionIdentifier)")

        switch actionIdentifier {
        case "com.osxcleaner.action.cleanup":
            handleCleanupAction(userInfo: userInfo)
        case "com.osxcleaner.action.retry":
            handleRetryAction(userInfo: userInfo)
        case "com.osxcleaner.action.view-logs":
            handleViewLogsAction()
        default:
            break
        }

        completionHandler()
    }

    /// Called when notification is about to be presented while app is in foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    // MARK: - Action Handlers

    private func handleCleanupAction(userInfo: [AnyHashable: Any]) {
        // Trigger cleanup through command line
        let level: String
        if let threshold = userInfo["threshold"] as? Int {
            switch threshold {
            case 95:
                level = "normal"
            case 90:
                level = "light"
            default:
                level = "light"
            }
        } else {
            level = "light"
        }

        AppLogger.shared.info("User requested cleanup at level: \(level)")
        // Note: Actual cleanup would be triggered by the main app
    }

    private func handleRetryAction(userInfo: [AnyHashable: Any]) {
        if let level = userInfo["level"] as? String {
            AppLogger.shared.info("User requested retry cleanup at level: \(level)")
        }
    }

    private func handleViewLogsAction() {
        // Open log file location
        let logPath = "/tmp/osxcleaner-daily.log"
        AppLogger.shared.info("User requested to view logs at: \(logPath)")
    }
}
