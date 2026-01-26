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

    // MARK: - Singleton

    static var shared: Preferences = Preferences.load()

    // MARK: - File Paths

    static var configDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("TooCheapFi")

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
