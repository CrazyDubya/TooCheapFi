import Foundation

struct Preferences: Codable {
    // Check intervals
    var checkIntervalSeconds: Int = 5
    var pingTimeoutSeconds: Int = 2

    // Test targets
    var ispTestTargets: [String] = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]
    var dnsTestDomains: [String] = ["apple.com", "cloudflare.com", "microsoft.com"]

    // Notifications
    var notificationsEnabled: Bool = true
    var notifyOnOutage: Bool = true
    var notifyOnRestore: Bool = true
    var notifyOnSignalDrop: Bool = false
    var outageThresholdSeconds: Int = 10  // Don't notify for blips shorter than this

    // History
    var historyEnabled: Bool = true
    var historyRetentionDays: Int = 30

    // Speed test
    var speedTestSizeMB: Int = 10

    // UI
    var showLatencyInMenuBar: Bool = false
    var compactMode: Bool = false

    // MARK: - Signal Thresholds (dBm)
    var rssiExcellent: Int = -50   // >= -50 is excellent
    var rssiGood: Int = -60        // >= -60 is good
    var rssiFair: Int = -70        // >= -70 is fair
    var rssiWeak: Int = -80        // >= -80 is weak, below is very weak

    // MARK: - SNR Thresholds (dB)
    var snrGood: Int = 25          // >= 25 is good
    var snrPoor: Int = 15          // < 15 is poor

    // MARK: - Latency Thresholds (ms)
    var latencyGood: Double = 30   // <= 30 is good
    var latencyFair: Double = 50   // <= 50 is fair
    var latencyPoor: Double = 100  // <= 100 is poor, above is very poor

    // MARK: - Congestion Thresholds (network count)
    var congestionLow: Int = 3     // <= 3 is low
    var congestionMedium: Int = 7  // <= 7 is medium, above is high

    // MARK: - Speed Thresholds (Mbps)
    var speedSlow: Double = 50     // < 50 is considered slow

    // MARK: - Singleton

    static var shared: Preferences = Preferences.load()

    // MARK: - File Paths

    static var configDirectory: URL {
        guard let appSupportBase = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            // Fallback to home directory if Application Support unavailable
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".toocheapfi")
        }

        let appSupport = appSupportBase.appendingPathComponent("TooCheapFi")

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )

        return appSupport
    }

    static var configPath: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    static var historyPath: URL {
        configDirectory.appendingPathComponent("history.db")
    }

    // MARK: - Load/Save

    static func load() -> Preferences {
        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data)
        else {
            // Return defaults and save them
            let defaults = Preferences()
            try? defaults.save()
            return defaults
        }
        return prefs
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Preferences.configPath)
    }

    mutating func update(_ block: (inout Preferences) -> Void) throws {
        block(&self)
        try save()
        Preferences.shared = self
    }

    // MARK: - Reset

    static func reset() throws {
        let defaults = Preferences()
        try defaults.save()
        shared = defaults
    }

    // MARK: - Open Config

    static func openConfigInFinder() {
        NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: configDirectory.path)
    }
}

// MARK: - AppKit Import for NSWorkspace

import AppKit
