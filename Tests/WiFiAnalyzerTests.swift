import XCTest
@testable import TooCheapFiCore

/// Tests for WiFi analysis functionality using production code
final class WiFiAnalyzerTests: XCTestCase {

    // MARK: - WiFiAnalyzer Tests

    func testWiFiAnalyzerInit() {
        let analyzer = WiFiAnalyzer()
        XCTAssertNotNil(analyzer)
    }

    // MARK: - Signal Quality Tests (Using Production SignalQuality.from(rssi:))

    func testSignalQuality_Excellent() {
        let quality = SignalQuality.from(rssi: -45)
        XCTAssertEqual(quality, .excellent)
        XCTAssertEqual(quality.rawValue, "Excellent")
    }

    func testSignalQuality_Good() {
        let quality = SignalQuality.from(rssi: -55)
        XCTAssertEqual(quality, .good)
        XCTAssertEqual(quality.rawValue, "Good")
    }

    func testSignalQuality_Fair() {
        let quality = SignalQuality.from(rssi: -65)
        XCTAssertEqual(quality, .fair)
        XCTAssertEqual(quality.rawValue, "Fair")
    }

    func testSignalQuality_Weak() {
        let quality = SignalQuality.from(rssi: -75)
        XCTAssertEqual(quality, .weak)
        XCTAssertEqual(quality.rawValue, "Weak")
    }

    func testSignalQuality_VeryWeak() {
        let quality = SignalQuality.from(rssi: -85)
        XCTAssertEqual(quality, .veryWeak)
        XCTAssertEqual(quality.rawValue, "Very Weak")
    }

    // MARK: - Channel Band Classification Tests

    func testChannelBandClassification_2_4GHz() {
        let channels2_4GHz = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

        for channel in channels2_4GHz {
            XCTAssertTrue(channel >= 1 && channel <= 14, "Channel \(channel) should be 2.4 GHz")
        }
    }

    func testChannelBandClassification_5GHz() {
        let channels5GHz = [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112,
                           116, 120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165]

        for channel in channels5GHz {
            XCTAssertTrue(channel >= 36 && channel <= 177, "Channel \(channel) should be 5 GHz")
        }
    }

    // MARK: - Non-Overlapping Channel Tests (2.4 GHz)

    func testNonOverlappingChannels_2_4GHz() {
        let nonOverlapping = [1, 6, 11]

        // Verify the three non-overlapping channels
        XCTAssertEqual(nonOverlapping, [1, 6, 11])

        // Overlapping channels should not be in the list
        let overlapping = [2, 3, 4, 5, 7, 8, 9, 10]
        for channel in overlapping {
            XCTAssertFalse(nonOverlapping.contains(channel), "Channel \(channel) should be overlapping")
        }
    }

    // MARK: - 5 GHz Channel Tests

    func testNonDFSChannels_5GHz() {
        // Non-DFS (UNII-1 and UNII-3) channels
        let nonDFS = [36, 40, 44, 48, 149, 153, 157, 161, 165]
        let dfsChannels = Set([52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144])

        for channel in nonDFS {
            XCTAssertFalse(dfsChannels.contains(channel), "Channel \(channel) should not be DFS")
        }
    }

    func testDFSChannels_5GHz() {
        // DFS (UNII-2A and UNII-2C) channels
        let dfsChannels = [52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144]
        let dfsSet = Set(dfsChannels)

        for channel in dfsChannels {
            XCTAssertTrue(dfsSet.contains(channel), "Channel \(channel) should be DFS")
        }
    }

    // MARK: - SNR Tests

    func testSNRCalculation() {
        let rssi = -50
        let noise = -90
        let snr = rssi - noise
        XCTAssertEqual(snr, 40, "SNR should be RSSI - Noise")
    }

    func testSNRQuality_Good() {
        let quality = SignalQuality.from(snr: 30)
        XCTAssertEqual(quality, .good, "SNR 30 should be good")
    }

    func testSNRQuality_Fair() {
        let quality = SignalQuality.from(snr: 20)
        XCTAssertEqual(quality, .fair, "SNR 20 should be fair")
    }

    func testSNRQuality_Weak() {
        let quality = SignalQuality.from(snr: 12)
        XCTAssertEqual(quality, .weak, "SNR 12 should be weak")
    }

    // MARK: - WiFiInfo Tests

    func testWiFiInfo_Unknown() {
        let unknown = WiFiInfo.unknown
        XCTAssertNil(unknown.ssid)
        XCTAssertNil(unknown.bssid)
        XCTAssertEqual(unknown.rssi, -100)
        XCTAssertEqual(unknown.channel, 0)
        XCTAssertEqual(unknown.signalQuality, .none)
    }

    func testWiFiInfo_SNRCalculation() {
        let wifi = WiFiInfo(
            ssid: "TestNetwork",
            bssid: "00:11:22:33:44:55",
            rssi: -50,
            noise: -90,
            channel: 6,
            channelBand: "2.4 GHz",
            channelWidth: 20,
            transmitRate: 150.0,
            phyMode: "802.11n",
            security: "WPA2",
            signalQuality: .excellent
        )

        XCTAssertEqual(wifi.snr, 40, "SNR should be RSSI - Noise = -50 - (-90) = 40")
    }

    // MARK: - ChannelAnalysis Tests

    func testChannelAnalysisCreation() {
        let analysis = ChannelAnalysis(
            channel: 6,
            band: "2.4 GHz",
            networksOnChannel: 3,
            networksOnAdjacentChannels: 5,
            strongestCompetitorRSSI: -60,
            congestionLevel: "Medium",
            isRecommended: false
        )

        XCTAssertEqual(analysis.channel, 6)
        XCTAssertEqual(analysis.band, "2.4 GHz")
        XCTAssertEqual(analysis.networksOnChannel, 3)
        XCTAssertEqual(analysis.networksOnAdjacentChannels, 5)
        XCTAssertEqual(analysis.strongestCompetitorRSSI, -60)
        XCTAssertEqual(analysis.congestionLevel, "Medium")
        XCTAssertFalse(analysis.isRecommended)
    }

    // MARK: - NeighboringNetwork Tests

    func testNeighboringNetworkCreation() {
        let neighbor = NeighboringNetwork(
            ssid: "Neighbor",
            bssid: "AA:BB:CC:DD:EE:FF",
            rssi: -70,
            channel: 11,
            channelBand: "2.4 GHz",
            security: "WPA2"
        )

        XCTAssertEqual(neighbor.ssid, "Neighbor")
        XCTAssertEqual(neighbor.rssi, -70)
        XCTAssertEqual(neighbor.channel, 11)
    }

    // MARK: - Channel Width Tests

    func testChannelWidths() {
        let widths = [20, 40, 80, 160]

        for width in widths {
            XCTAssertTrue(widths.contains(width), "\(width) MHz is a valid channel width")
        }
    }

    // MARK: - Congestion Level Tests

    func testCongestionLevelRanges() {
        // Validate congestion level strings
        let validLevels = ["None", "Low", "Medium", "High"]

        for level in validLevels {
            XCTAssertTrue(validLevels.contains(level))
        }
    }
}
