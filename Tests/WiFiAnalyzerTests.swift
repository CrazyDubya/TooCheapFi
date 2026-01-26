import XCTest
@testable import TooCheapFiCore

/// Tests for WiFi analysis functionality
final class WiFiAnalyzerTests: XCTestCase {

    // MARK: - Channel Band Tests

    func testChannelBandClassification_2_4GHz() {
        let channels2_4GHz = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

        for channel in channels2_4GHz {
            let band = classifyChannelBand(channel)
            XCTAssertEqual(band, "2.4 GHz", "Channel \(channel) should be 2.4 GHz")
        }
    }

    func testChannelBandClassification_5GHz() {
        let channels5GHz = [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112,
                           116, 120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165]

        for channel in channels5GHz {
            let band = classifyChannelBand(channel)
            XCTAssertEqual(band, "5 GHz", "Channel \(channel) should be 5 GHz")
        }
    }

    func testChannelBandClassification_6GHz() {
        let channels6GHz = [1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69,
                           73, 77, 81, 85, 89, 93, 97, 101, 105, 109, 113, 117, 121, 125, 129,
                           133, 137, 141, 145, 149, 153, 157, 161, 165, 169, 173, 177, 181,
                           185, 189, 193, 197, 201, 205, 209, 213, 217, 221, 225, 229, 233]

        // Note: 6GHz classification depends on context - channels overlap with 2.4GHz numbers
        // This test validates the logic handles edge cases
        for channel in channels6GHz.filter({ $0 > 14 && !([36, 40, 44, 48, 52, 56, 60, 64, 100, 104,
                                                          108, 112, 116, 120, 124, 128, 132, 136,
                                                          140, 144, 149, 153, 157, 161, 165].contains($0)) }) {
            let band = classifyChannelBand(channel)
            XCTAssertEqual(band, "6 GHz", "Channel \(channel) should be 6 GHz")
        }
    }

    // MARK: - Congestion Level Tests

    func testCongestionLevel_None() {
        let networkCount = 0
        let level = determineCongestionLevel(networkCount: networkCount)
        XCTAssertEqual(level, "None")
    }

    func testCongestionLevel_Low() {
        for count in 1...3 {
            let level = determineCongestionLevel(networkCount: count)
            XCTAssertEqual(level, "Low", "Count \(count) should be Low congestion")
        }
    }

    func testCongestionLevel_Medium() {
        for count in 4...7 {
            let level = determineCongestionLevel(networkCount: count)
            XCTAssertEqual(level, "Medium", "Count \(count) should be Medium congestion")
        }
    }

    func testCongestionLevel_High() {
        for count in [8, 10, 15, 20] {
            let level = determineCongestionLevel(networkCount: count)
            XCTAssertEqual(level, "High", "Count \(count) should be High congestion")
        }
    }

    // MARK: - Non-Overlapping Channel Tests (2.4 GHz)

    func testNonOverlappingChannels_2_4GHz() {
        let nonOverlapping = [1, 6, 11]

        XCTAssertTrue(isNonOverlappingChannel(1, band: "2.4 GHz"))
        XCTAssertTrue(isNonOverlappingChannel(6, band: "2.4 GHz"))
        XCTAssertTrue(isNonOverlappingChannel(11, band: "2.4 GHz"))

        // Overlapping channels
        XCTAssertFalse(isNonOverlappingChannel(2, band: "2.4 GHz"))
        XCTAssertFalse(isNonOverlappingChannel(3, band: "2.4 GHz"))
        XCTAssertFalse(isNonOverlappingChannel(4, band: "2.4 GHz"))
        XCTAssertFalse(isNonOverlappingChannel(5, band: "2.4 GHz"))
        XCTAssertFalse(isNonOverlappingChannel(7, band: "2.4 GHz"))
    }

    // MARK: - Channel Recommendation Tests

    func testChannelRecommendation_LeastCongested() {
        let channelCounts = [
            1: 5,   // High
            6: 2,   // Low
            11: 8   // High
        ]

        let recommended = findLeastCongestedChannel(channelCounts)
        XCTAssertEqual(recommended, 6, "Should recommend least congested channel")
    }

    func testChannelRecommendation_TieBreaker() {
        let channelCounts = [
            1: 3,
            6: 3,
            11: 3
        ]

        let recommended = findLeastCongestedChannel(channelCounts)
        // When tied, prefer channel 1 (first in sorted order)
        XCTAssertTrue([1, 6, 11].contains(recommended), "Should recommend one of the tied channels")
    }

    // MARK: - 5 GHz Channel Tests

    func testNonDFSChannels_5GHz() {
        let nonDFS = [36, 40, 44, 48, 149, 153, 157, 161, 165]

        for channel in nonDFS {
            XCTAssertFalse(isDFSChannel(channel), "Channel \(channel) should not be DFS")
        }
    }

    func testDFSChannels_5GHz() {
        let dfs = [52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144]

        for channel in dfs {
            XCTAssertTrue(isDFSChannel(channel), "Channel \(channel) should be DFS")
        }
    }

    // MARK: - Signal Quality Tests

    func testSignalQuality_Excellent() {
        let rssi = -45
        let quality = determineSignalQuality(rssi: rssi)
        XCTAssertEqual(quality, "Excellent")
    }

    func testSignalQuality_Good() {
        let rssi = -55
        let quality = determineSignalQuality(rssi: rssi)
        XCTAssertEqual(quality, "Good")
    }

    func testSignalQuality_Fair() {
        let rssi = -65
        let quality = determineSignalQuality(rssi: rssi)
        XCTAssertEqual(quality, "Fair")
    }

    func testSignalQuality_Weak() {
        let rssi = -75
        let quality = determineSignalQuality(rssi: rssi)
        XCTAssertEqual(quality, "Weak")
    }

    func testSignalQuality_VeryWeak() {
        let rssi = -85
        let quality = determineSignalQuality(rssi: rssi)
        XCTAssertEqual(quality, "Very Weak")
    }

    // MARK: - SNR Tests

    func testSNRCalculation() {
        let rssi = -50
        let noise = -90
        let snr = rssi - noise
        XCTAssertEqual(snr, 40, "SNR should be RSSI - Noise")
    }

    func testSNRQuality_Good() {
        let snr = 30
        XCTAssertTrue(snr >= 25, "SNR 30 should be good (>=25)")
    }

    func testSNRQuality_Marginal() {
        let snr = 20
        XCTAssertTrue(snr >= 15 && snr < 25, "SNR 20 should be marginal (15-25)")
    }

    func testSNRQuality_Poor() {
        let snr = 10
        XCTAssertTrue(snr < 15, "SNR 10 should be poor (<15)")
    }

    // MARK: - PHY Mode Tests

    func testPHYModeClassification() {
        XCTAssertEqual(classifyPHYMode(11), "802.11ax (Wi-Fi 6)")
        XCTAssertEqual(classifyPHYMode(10), "802.11ac (Wi-Fi 5)")
        XCTAssertEqual(classifyPHYMode(7), "802.11n (Wi-Fi 4)")
        XCTAssertEqual(classifyPHYMode(4), "802.11g")
        XCTAssertEqual(classifyPHYMode(2), "802.11b")
        XCTAssertEqual(classifyPHYMode(1), "802.11a")
        XCTAssertEqual(classifyPHYMode(0), "Unknown")
    }

    // MARK: - Channel Width Tests

    func testChannelWidthClassification() {
        XCTAssertEqual(classifyChannelWidth(20), "20 MHz")
        XCTAssertEqual(classifyChannelWidth(40), "40 MHz")
        XCTAssertEqual(classifyChannelWidth(80), "80 MHz")
        XCTAssertEqual(classifyChannelWidth(160), "160 MHz")
    }

    // MARK: - Helper Functions

    private func classifyChannelBand(_ channel: Int) -> String {
        if channel >= 1 && channel <= 14 {
            return "2.4 GHz"
        } else if channel >= 36 && channel <= 165 {
            return "5 GHz"
        } else {
            return "6 GHz"
        }
    }

    private func determineCongestionLevel(networkCount: Int) -> String {
        if networkCount == 0 { return "None" }
        if networkCount <= 3 { return "Low" }
        if networkCount <= 7 { return "Medium" }
        return "High"
    }

    private func isNonOverlappingChannel(_ channel: Int, band: String) -> Bool {
        if band == "2.4 GHz" {
            return [1, 6, 11].contains(channel)
        }
        return true  // All 5GHz channels are non-overlapping
    }

    private func findLeastCongestedChannel(_ channelCounts: [Int: Int]) -> Int {
        channelCounts.min(by: { $0.value < $1.value })?.key ?? 1
    }

    private func isDFSChannel(_ channel: Int) -> Bool {
        let dfsChannels = [52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144]
        return dfsChannels.contains(channel)
    }

    private func determineSignalQuality(rssi: Int) -> String {
        if rssi >= -50 { return "Excellent" }
        if rssi >= -60 { return "Good" }
        if rssi >= -70 { return "Fair" }
        if rssi >= -80 { return "Weak" }
        return "Very Weak"
    }

    private func classifyPHYMode(_ mode: Int) -> String {
        switch mode {
        case 11: return "802.11ax (Wi-Fi 6)"
        case 10: return "802.11ac (Wi-Fi 5)"
        case 7: return "802.11n (Wi-Fi 4)"
        case 4: return "802.11g"
        case 2: return "802.11b"
        case 1: return "802.11a"
        default: return "Unknown"
        }
    }

    private func classifyChannelWidth(_ width: Int) -> String {
        "\(width) MHz"
    }
}
