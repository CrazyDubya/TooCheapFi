import XCTest

/// Tests for shared utility functions
final class UtilitiesTests: XCTestCase {

    // MARK: - Duration Formatting Tests

    func testFormatDuration_Seconds() {
        XCTAssertEqual(formatDuration(0), "0s")
        XCTAssertEqual(formatDuration(1), "1s")
        XCTAssertEqual(formatDuration(30), "30s")
        XCTAssertEqual(formatDuration(59), "59s")
    }

    func testFormatDuration_Minutes() {
        XCTAssertEqual(formatDuration(60), "1m 0s")
        XCTAssertEqual(formatDuration(90), "1m 30s")
        XCTAssertEqual(formatDuration(300), "5m 0s")
        XCTAssertEqual(formatDuration(3599), "59m 59s")
    }

    func testFormatDuration_Hours() {
        XCTAssertEqual(formatDuration(3600), "1h 0m")
        XCTAssertEqual(formatDuration(3660), "1h 1m")
        XCTAssertEqual(formatDuration(7200), "2h 0m")
        XCTAssertEqual(formatDuration(86400), "24h 0m")
    }

    func testFormatDuration_TimeInterval() {
        XCTAssertEqual(formatDuration(TimeInterval(45.5)), "45s")
        XCTAssertEqual(formatDuration(TimeInterval(120.9)), "2m 0s")
        XCTAssertEqual(formatDuration(TimeInterval(3700.0)), "1h 1m")
    }

    // MARK: - Byte Formatting Tests

    func testFormatBytes_Small() {
        XCTAssertTrue(formatBytes(0).contains("0") || formatBytes(0).contains("zero"))
        XCTAssertTrue(formatBytes(512).contains("512") || formatBytes(512).lowercased().contains("bytes"))
    }

    func testFormatBytes_Kilobytes() {
        let result = formatBytes(1024)
        XCTAssertTrue(result.contains("1") && result.uppercased().contains("KB"),
                     "1024 bytes should format as ~1 KB, got: \(result)")
    }

    func testFormatBytes_Megabytes() {
        let result = formatBytes(1048576)
        XCTAssertTrue(result.uppercased().contains("MB"),
                     "1MB should contain 'MB', got: \(result)")
    }

    func testFormatBytes_Gigabytes() {
        let result = formatBytes(Int64(1073741824))
        XCTAssertTrue(result.uppercased().contains("GB"),
                     "1GB should contain 'GB', got: \(result)")
    }

    // MARK: - Speed Formatting Tests

    func testFormatSpeed_LowSpeed() {
        let result = formatSpeed(5.5)
        XCTAssertTrue(result.contains("5.50") && result.contains("Mbps"),
                     "5.5 Mbps should format with 2 decimals, got: \(result)")
    }

    func testFormatSpeed_MediumSpeed() {
        let result = formatSpeed(50.5)
        XCTAssertTrue(result.contains("50.5") && result.contains("Mbps"),
                     "50.5 Mbps should format with 1 decimal, got: \(result)")
    }

    func testFormatSpeed_HighSpeed() {
        let result = formatSpeed(500.0)
        XCTAssertTrue(result.contains("500") && result.contains("Mbps"),
                     "500 Mbps should format as integer, got: \(result)")
    }

    func testFormatSpeed_GigabitSpeed() {
        let result = formatSpeed(1500.0)
        XCTAssertTrue(result.contains("1.5") && result.contains("Gbps"),
                     "1500 Mbps should format as 1.5 Gbps, got: \(result)")
    }

    // MARK: - Quality Emoji Tests

    func testQualityEmoji_Excellent() {
        XCTAssertEqual(qualityEmoji(for: .excellent), "🟢")
    }

    func testQualityEmoji_Good() {
        XCTAssertEqual(qualityEmoji(for: .good), "🟡")
    }

    func testQualityEmoji_Fair() {
        XCTAssertEqual(qualityEmoji(for: .fair), "🟠")
    }

    func testQualityEmoji_Poor() {
        XCTAssertEqual(qualityEmoji(for: .poor), "🔴")
    }

    func testQualityEmoji_None() {
        XCTAssertEqual(qualityEmoji(for: .none), "⚫")
    }

    // MARK: - Signal Emoji Tests

    func testSignalEmoji_Excellent() {
        XCTAssertEqual(signalEmoji(for: .excellent), "📶")
    }

    func testSignalEmoji_Good() {
        XCTAssertEqual(signalEmoji(for: .good), "📶")
    }

    func testSignalEmoji_Fair() {
        XCTAssertEqual(signalEmoji(for: .fair), "📶")
    }

    func testSignalEmoji_Weak() {
        XCTAssertEqual(signalEmoji(for: .weak), "📉")
    }

    func testSignalEmoji_VeryWeak() {
        XCTAssertEqual(signalEmoji(for: .veryWeak), "📉")
    }

    func testSignalEmoji_None() {
        XCTAssertEqual(signalEmoji(for: .none), "❌")
    }

    // MARK: - Congestion Emoji Tests

    func testCongestionEmoji_None() {
        XCTAssertEqual(congestionEmoji(for: "None"), "🟢")
    }

    func testCongestionEmoji_Low() {
        XCTAssertEqual(congestionEmoji(for: "Low"), "🟡")
    }

    func testCongestionEmoji_Medium() {
        XCTAssertEqual(congestionEmoji(for: "Medium"), "🟠")
    }

    func testCongestionEmoji_High() {
        XCTAssertEqual(congestionEmoji(for: "High"), "🔴")
    }

    func testCongestionEmoji_Unknown() {
        XCTAssertEqual(congestionEmoji(for: "Unknown"), "🔴")
    }
}
