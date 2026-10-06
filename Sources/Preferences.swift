import Foundation

public struct Preferences: Codable {
    // Check intervals
    public var checkIntervalSeconds: Int = 5
    public var pingTimeoutSeconds: Int = 2

    // Test targets
    public var ispTestTargets: [String] = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]
    public var dnsTestDomains: [String] = ["apple.com", "cloudflare.com", "microsoft.com"]

    // Notifications
    public var notificationsEnabled: Bool = true
    public var notifyOnOutage: Bool = true
    public var notifyOnRestore: Bool = true
    public var notifyOnSignalDrop: Bool = false
    public var outageThresholdSeconds: Int = 10  // Don't notify for blips shorter than this

    // History
    public var historyEnabled: Bool = true
    public var historyRetentionDays: Int = 30

    // Speed test
    public var speedTestSizeMB: Int = 10

    // UI
    public var showLatencyInMenuBar: Bool = false
    public var compactMode: Bool = false

    // MARK: - Signal Thresholds (dBm)
    public var rssiExcellent: Int = -50   // >= -50 is excellent
    public var rssiGood: Int = -60        // >= -60 is good
    public var rssiFair: Int = -70        // >= -70 is fair
    public var rssiWeak: Int = -80        // >= -80 is weak, below is very weak

    // MARK: - SNR Thresholds (dB)
    public var snrGood: Int = 25          // >= 25 is good
    public var snrPoor: Int = 15          // < 15 is poor

    // MARK: - Latency Thresholds (ms)
    public var latencyGood: Double = 30   // <= 30 is good
    public var latencyFair: Double = 50   // <= 50 is fair
    public var latencyPoor: Double = 100  // <= 100 is poor, above is very poor

    // MARK: - Congestion Thresholds (network count)
    public var congestionLow: Int = 3     // <= 3 is low
    public var congestionMedium: Int = 7  // <= 7 is medium, above is high

    // MARK: - Speed Thresholds (Mbps)
    public var speedSlow: Double = 50     // < 50 is considered slow

    // MARK: - Validation

    /// Validates and corrects preference values to ensure they're within acceptable ranges
    public mutating func validate() {
        // Intervals must be reasonable
        checkIntervalSeconds = max(1, min(300, checkIntervalSeconds))
        pingTimeoutSeconds = max(1, min(30, pingTimeoutSeconds))
        historyRetentionDays = max(1, min(365, historyRetentionDays))
        speedTestSizeMB = max(1, min(100, speedTestSizeMB))
        outageThresholdSeconds = max(0, min(300, outageThresholdSeconds))

        // RSSI thresholds must be in valid range and properly ordered
        rssiExcellent = max(-100, min(0, rssiExcellent))
        rssiGood = max(-100, min(rssiExcellent, rssiGood))
        rssiFair = max(-100, min(rssiGood, rssiFair))
        rssiWeak = max(-100, min(rssiFair, rssiWeak))

        // SNR thresholds
        snrGood = max(0, min(100, snrGood))
        snrPoor = max(0, min(snrGood, snrPoor))

        // Latency thresholds must be positive and properly ordered
        latencyGood = max(1, latencyGood)
        latencyFair = max(latencyGood, latencyFair)
        latencyPoor = max(latencyFair, latencyPoor)

        // Congestion thresholds
        congestionLow = max(0, congestionLow)
        congestionMedium = max(congestionLow, congestionMedium)

        // Speed threshold
        speedSlow = max(1, speedSlow)

        // Ensure we have at least one test target
        if ispTestTargets.isEmpty {
            ispTestTargets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]
        }
        if dnsTestDomains.isEmpty {
            dnsTestDomains = ["apple.com", "cloudflare.com", "microsoft.com"]
        }
    }

    // MARK: - Singleton

    public static var shared: Preferences = Preferences.load()

    // MARK: - File Paths

    public static var configDirectory: URL {
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
        do {
            try FileManager.default.createDirectory(
                at: appSupport,
                withIntermediateDirectories: true
            )
        } catch {
            logError("Failed to create config directory: \(error)")
        }

        return appSupport
    }

    public static var configPath: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    public static var historyPath: URL {
        configDirectory.appendingPathComponent("history.db")
    }

    // MARK: - Load/Save

    public static func load() -> Preferences {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            // Config file doesn't exist, create defaults
            var defaults = Preferences()
            defaults.validate()
            do {
                try defaults.save()
            } catch {
                logError("Failed to save default preferences: \(error)")
            }
            return defaults
        }

        do {
            let data = try Data(contentsOf: configPath)
            var prefs = try JSONDecoder().decode(Preferences.self, from: data)
            prefs.validate()
            return prefs
        } catch {
            logError("Failed to load preferences, using defaults: \(error)")
            var defaults = Preferences()
            defaults.validate()
            do {
                try defaults.save()
            } catch {
                logError("Failed to save default preferences: \(error)")
            }
            return defaults
        }
    }

    public func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Preferences.configPath)
    }

    public mutating func update(_ block: (inout Preferences) -> Void) throws {
        block(&self)
        try save()
        Preferences.shared = self
    }

    // MARK: - Reset

    public static func reset() throws {
        let defaults = Preferences()
        try defaults.save()
        shared = defaults
    }

    // MARK: - Open Config

    public static func openConfigInFinder() {
        NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: configDirectory.path)
    }

    // MARK: - Public Initializer

    public init() {}
}

// MARK: - AppKit Import for NSWorkspace

import AppKit
