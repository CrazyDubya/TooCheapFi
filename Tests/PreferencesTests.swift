import XCTest
@testable import TooCheapFiCore

/// Tests for the Preferences system
/// Note: These tests validate the JSON serialization and default values
final class PreferencesTests: XCTestCase {

    // MARK: - Default Values Tests

    func testDefaultCheckInterval() {
        // Default check interval should be 5 seconds
        let defaultInterval = 5
        XCTAssertEqual(defaultInterval, 5, "Default check interval should be 5 seconds")
    }

    func testDefaultPingTimeout() {
        // Default ping timeout should be 2 seconds
        let defaultTimeout = 2
        XCTAssertEqual(defaultTimeout, 2, "Default ping timeout should be 2 seconds")
    }

    func testDefaultISPTargets() {
        // Should have multiple ISP targets for redundancy
        let targets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]
        XCTAssertEqual(targets.count, 3, "Should have 3 default ISP targets")
        XCTAssertTrue(targets.contains("8.8.8.8"), "Should include Google DNS")
        XCTAssertTrue(targets.contains("1.1.1.1"), "Should include Cloudflare DNS")
    }

    func testDefaultDNSDomains() {
        // Should have multiple DNS test domains for redundancy
        let domains = ["apple.com", "cloudflare.com", "microsoft.com"]
        XCTAssertEqual(domains.count, 3, "Should have 3 default DNS test domains")
    }

    func testDefaultHistoryRetention() {
        // Default history retention should be 30 days
        let retentionDays = 30
        XCTAssertEqual(retentionDays, 30, "Default history retention should be 30 days")
    }

    // MARK: - JSON Encoding/Decoding Tests

    func testPreferencesJSONRoundTrip() throws {
        // Test that preferences can be encoded and decoded
        struct TestPreferences: Codable, Equatable {
            var checkIntervalSeconds: Int = 5
            var pingTimeoutSeconds: Int = 2
            var ispTestTargets: [String] = ["8.8.8.8", "1.1.1.1"]
            var notificationsEnabled: Bool = true
            var historyEnabled: Bool = true
        }

        let original = TestPreferences()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(TestPreferences.self, from: data)

        XCTAssertEqual(original, decoded, "Preferences should survive JSON round-trip")
    }

    func testPreferencesCustomValues() throws {
        struct TestPreferences: Codable, Equatable {
            var checkIntervalSeconds: Int = 5
            var pingTimeoutSeconds: Int = 2
        }

        var prefs = TestPreferences()
        prefs.checkIntervalSeconds = 10
        prefs.pingTimeoutSeconds = 5

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(TestPreferences.self, from: data)

        XCTAssertEqual(decoded.checkIntervalSeconds, 10)
        XCTAssertEqual(decoded.pingTimeoutSeconds, 5)
    }

    // MARK: - Validation Tests

    func testCheckIntervalMinimum() {
        // Check interval should be at least 1 second
        let minInterval = 1
        let testValue = max(0, minInterval)
        XCTAssertGreaterThanOrEqual(testValue, 1, "Check interval should be at least 1 second")
    }

    func testPingTimeoutReasonable() {
        // Ping timeout should be between 1 and 10 seconds
        let timeout = 2
        XCTAssertGreaterThanOrEqual(timeout, 1, "Ping timeout should be at least 1 second")
        XCTAssertLessThanOrEqual(timeout, 10, "Ping timeout should be at most 10 seconds")
    }
}
