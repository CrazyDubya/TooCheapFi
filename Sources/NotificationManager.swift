import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var lastNotifiedStatus: Bool?
    private var outageStartTime: Date?
    private var notificationsEnabled = true

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Notifications

    func handleStatusChange(from oldStatus: NetworkStatus?, to newStatus: NetworkStatus) {
        guard notificationsEnabled else { return }

        let wasConnected = oldStatus?.isFullyConnected ?? true
        let isConnected = newStatus.isFullyConnected

        // Detect outage start
        if wasConnected && !isConnected {
            outageStartTime = Date()
            notifyOutageStart(status: newStatus)
        }

        // Detect outage end
        if !wasConnected && isConnected {
            let duration = outageStartTime.map { Date().timeIntervalSince($0) }
            notifyOutageEnd(duration: duration)
            outageStartTime = nil
        }

        // Detect captive portal
        if newStatus.captivePortalDetected && !(oldStatus?.captivePortalDetected ?? false) {
            notifyCaptivePortal(url: newStatus.captivePortalURL)
        }

        // Detect significant signal drop
        if let oldWifi = oldStatus?.wifiInfo, let newWifi = newStatus.wifiInfo {
            if oldWifi.signalQuality == .good || oldWifi.signalQuality == .excellent {
                if newWifi.signalQuality == .weak || newWifi.signalQuality == .veryWeak {
                    notifySignalDrop(from: oldWifi.rssi, to: newWifi.rssi)
                }
            }
        }

        lastNotifiedStatus = isConnected
    }

    private func notifyOutageStart(status: NetworkStatus) {
        let content = UNMutableNotificationContent()
        content.title = "Internet Disconnected"

        // Determine the cause
        if status.interfaceType == .none {
            content.body = "No network connection detected"
        } else if !status.gatewayReachable {
            content.body = "Cannot reach your router. Check if it's powered on."
        } else if !status.internetReachable {
            content.body = "Router works but no internet. ISP may be down."
        } else if !status.dnsWorking {
            content.body = "Internet works but DNS is failing."
        } else {
            content.body = "Connection issues detected"
        }

        content.sound = .default
        content.categoryIdentifier = "OUTAGE"

        let request = UNNotificationRequest(
            identifier: "outage-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func notifyOutageEnd(duration: TimeInterval?) {
        let content = UNMutableNotificationContent()
        content.title = "Internet Restored"

        if let duration = duration {
            content.body = "Connection restored after \(formatDuration(duration))"
        } else {
            content.body = "Your internet connection is back online"
        }

        content.sound = nil  // Silent for restore
        content.categoryIdentifier = "RESTORED"

        let request = UNNotificationRequest(
            identifier: "restore-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func notifyCaptivePortal(url: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Login Required"
        content.body = "This network requires you to log in via a web browser"
        content.sound = .default
        content.categoryIdentifier = "CAPTIVE_PORTAL"

        if let url = url {
            content.userInfo = ["portalURL": url]
        }

        let request = UNNotificationRequest(
            identifier: "captive-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func notifySignalDrop(from oldRSSI: Int, to newRSSI: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Wi-Fi Signal Weak"
        content.body = "Signal dropped from \(oldRSSI) dBm to \(newRSSI) dBm. Consider moving closer to router."
        content.sound = nil  // Silent for signal warnings
        content.categoryIdentifier = "SIGNAL_WEAK"

        let request = UNNotificationRequest(
            identifier: "signal-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    // MARK: - Settings

    func setEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
    }

    var isEnabled: Bool {
        notificationsEnabled
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo

        if let portalURL = userInfo["portalURL"] as? String,
           let url = URL(string: portalURL) {
            NSWorkspace.shared.open(url)
        }

        completionHandler()
    }
}
