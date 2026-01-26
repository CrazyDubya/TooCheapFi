import XCTest

/// Tests for signal quality classification
final class SignalQualityTests: XCTestCase {

    // MARK: - RSSI Classification Tests

    func testExcellentSignal() {
        XCTAssertEqual(classifyRSSI(-30), "excellent")
        XCTAssertEqual(classifyRSSI(-40), "excellent")
        XCTAssertEqual(classifyRSSI(-50), "excellent")
    }

    func testGoodSignal() {
        XCTAssertEqual(classifyRSSI(-51), "good")
        XCTAssertEqual(classifyRSSI(-55), "good")
        XCTAssertEqual(classifyRSSI(-60), "good")
    }

    func testFairSignal() {
        XCTAssertEqual(classifyRSSI(-61), "fair")
        XCTAssertEqual(classifyRSSI(-65), "fair")
        XCTAssertEqual(classifyRSSI(-70), "fair")
    }

    func testWeakSignal() {
        XCTAssertEqual(classifyRSSI(-71), "weak")
        XCTAssertEqual(classifyRSSI(-75), "weak")
        XCTAssertEqual(classifyRSSI(-80), "weak")
    }

    func testVeryWeakSignal() {
        XCTAssertEqual(classifyRSSI(-81), "veryWeak")
        XCTAssertEqual(classifyRSSI(-90), "veryWeak")
        XCTAssertEqual(classifyRSSI(-100), "veryWeak")
    }

    // MARK: - SNR Classification Tests

    func testExcellentSNR() {
        XCTAssertTrue(isExcellentSNR(40))
        XCTAssertTrue(isExcellentSNR(35))
    }

    func testGoodSNR() {
        XCTAssertTrue(isGoodSNR(25))
        XCTAssertTrue(isGoodSNR(30))
    }

    func testPoorSNR() {
        XCTAssertTrue(isPoorSNR(10))
        XCTAssertTrue(isPoorSNR(5))
    }

    // MARK: - Channel Band Tests

    func testIs2_4GHzChannel() {
        XCTAssertTrue(is2_4GHzChannel(1))
        XCTAssertTrue(is2_4GHzChannel(6))
        XCTAssertTrue(is2_4GHzChannel(11))
        XCTAssertTrue(is2_4GHzChannel(13))
        XCTAssertFalse(is2_4GHzChannel(36))
        XCTAssertFalse(is2_4GHzChannel(149))
    }

    func testIs5GHzChannel() {
        XCTAssertTrue(is5GHzChannel(36))
        XCTAssertTrue(is5GHzChannel(44))
        XCTAssertTrue(is5GHzChannel(149))
        XCTAssertTrue(is5GHzChannel(165))
        XCTAssertFalse(is5GHzChannel(1))
        XCTAssertFalse(is5GHzChannel(11))
    }

    func testNonOverlapping2_4GHzChannels() {
        let nonOverlapping = [1, 6, 11]
        XCTAssertEqual(nonOverlapping.count, 3)
        XCTAssertEqual(nonOverlapping[1] - nonOverlapping[0], 5)
        XCTAssertEqual(nonOverlapping[2] - nonOverlapping[1], 5)
    }

    // MARK: - Congestion Level Tests

    func testCongestionLevel_None() {
        XCTAssertEqual(congestionLevel(networks: 0), "None")
    }

    func testCongestionLevel_Low() {
        XCTAssertEqual(congestionLevel(networks: 1), "Low")
        XCTAssertEqual(congestionLevel(networks: 2), "Low")
        XCTAssertEqual(congestionLevel(networks: 3), "Low")
    }

    func testCongestionLevel_Medium() {
        XCTAssertEqual(congestionLevel(networks: 4), "Medium")
        XCTAssertEqual(congestionLevel(networks: 5), "Medium")
        XCTAssertEqual(congestionLevel(networks: 7), "Medium")
    }

    func testCongestionLevel_High() {
        XCTAssertEqual(congestionLevel(networks: 8), "High")
        XCTAssertEqual(congestionLevel(networks: 15), "High")
        XCTAssertEqual(congestionLevel(networks: 20), "High")
    }

    // MARK: - Helper Functions

    private func classifyRSSI(_ rssi: Int) -> String {
        switch rssi {
        case -50...0: return "excellent"
        case -60..<(-50): return "good"
        case -70..<(-60): return "fair"
        case -80..<(-70): return "weak"
        default: return "veryWeak"
        }
    }

    private func isExcellentSNR(_ snr: Int) -> Bool {
        return snr >= 35
    }

    private func isGoodSNR(_ snr: Int) -> Bool {
        return snr >= 25 && snr < 35
    }

    private func isPoorSNR(_ snr: Int) -> Bool {
        return snr < 15
    }

    private func is2_4GHzChannel(_ channel: Int) -> Bool {
        return channel >= 1 && channel <= 14
    }

    private func is5GHzChannel(_ channel: Int) -> Bool {
        return channel >= 36 && channel <= 177
    }

    private func congestionLevel(networks: Int) -> String {
        switch networks {
        case 0: return "None"
        case 1...3: return "Low"
        case 4...7: return "Medium"
        default: return "High"
        }
    }
}
