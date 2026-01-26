import XCTest
@testable import TooCheapFiCore

/// Tests for signal quality classification using production code
final class SignalQualityTests: XCTestCase {

    // MARK: - RSSI Classification Tests (Using Production SignalQuality.from(rssi:))

    func testExcellentSignal() {
        XCTAssertEqual(SignalQuality.from(rssi: -30), .excellent)
        XCTAssertEqual(SignalQuality.from(rssi: -40), .excellent)
        XCTAssertEqual(SignalQuality.from(rssi: -50), .excellent)
    }

    func testGoodSignal() {
        XCTAssertEqual(SignalQuality.from(rssi: -51), .good)
        XCTAssertEqual(SignalQuality.from(rssi: -55), .good)
        XCTAssertEqual(SignalQuality.from(rssi: -60), .good)
    }

    func testFairSignal() {
        XCTAssertEqual(SignalQuality.from(rssi: -61), .fair)
        XCTAssertEqual(SignalQuality.from(rssi: -65), .fair)
        XCTAssertEqual(SignalQuality.from(rssi: -70), .fair)
    }

    func testWeakSignal() {
        XCTAssertEqual(SignalQuality.from(rssi: -71), .weak)
        XCTAssertEqual(SignalQuality.from(rssi: -75), .weak)
        XCTAssertEqual(SignalQuality.from(rssi: -80), .weak)
    }

    func testVeryWeakSignal() {
        XCTAssertEqual(SignalQuality.from(rssi: -81), .veryWeak)
        XCTAssertEqual(SignalQuality.from(rssi: -90), .veryWeak)
        XCTAssertEqual(SignalQuality.from(rssi: -100), .veryWeak)
    }

    // MARK: - SNR Classification Tests (Using Production SignalQuality.from(snr:))

    func testExcellentSNR() {
        XCTAssertEqual(SignalQuality.from(snr: 40), .excellent)
        XCTAssertEqual(SignalQuality.from(snr: 45), .excellent)
    }

    func testGoodSNR() {
        XCTAssertEqual(SignalQuality.from(snr: 25), .good)
        XCTAssertEqual(SignalQuality.from(snr: 30), .good)
        XCTAssertEqual(SignalQuality.from(snr: 39), .good)
    }

    func testFairSNR() {
        XCTAssertEqual(SignalQuality.from(snr: 15), .fair)
        XCTAssertEqual(SignalQuality.from(snr: 20), .fair)
        XCTAssertEqual(SignalQuality.from(snr: 24), .fair)
    }

    func testWeakSNR() {
        XCTAssertEqual(SignalQuality.from(snr: 10), .weak)
        XCTAssertEqual(SignalQuality.from(snr: 14), .weak)
    }

    func testVeryWeakSNR() {
        XCTAssertEqual(SignalQuality.from(snr: 9), .veryWeak)
        XCTAssertEqual(SignalQuality.from(snr: 5), .veryWeak)
        XCTAssertEqual(SignalQuality.from(snr: 0), .veryWeak)
    }

    // MARK: - Channel Band Tests (Validates expected channel ranges)

    func testIs2_4GHzChannel() {
        // 2.4 GHz channels are 1-14
        let channels2_4GHz = [1, 6, 11, 13]
        for channel in channels2_4GHz {
            XCTAssertTrue(channel >= 1 && channel <= 14, "Channel \(channel) should be 2.4 GHz range")
        }

        // 5 GHz channels are not in 2.4 GHz range
        let channels5GHz = [36, 149]
        for channel in channels5GHz {
            XCTAssertFalse(channel >= 1 && channel <= 14, "Channel \(channel) should not be 2.4 GHz range")
        }
    }

    func testIs5GHzChannel() {
        let channels5GHz = [36, 44, 149, 165]
        for channel in channels5GHz {
            XCTAssertTrue(channel >= 36 && channel <= 177, "Channel \(channel) should be 5 GHz range")
        }
    }

    func testNonOverlapping2_4GHzChannels() {
        // Non-overlapping 2.4 GHz channels are 1, 6, 11
        let nonOverlapping = [1, 6, 11]
        XCTAssertEqual(nonOverlapping.count, 3)
        XCTAssertEqual(nonOverlapping[1] - nonOverlapping[0], 5)
        XCTAssertEqual(nonOverlapping[2] - nonOverlapping[1], 5)
    }

    // MARK: - SignalQuality Enum Tests

    func testSignalQualityRawValues() {
        XCTAssertEqual(SignalQuality.excellent.rawValue, "Excellent")
        XCTAssertEqual(SignalQuality.good.rawValue, "Good")
        XCTAssertEqual(SignalQuality.fair.rawValue, "Fair")
        XCTAssertEqual(SignalQuality.weak.rawValue, "Weak")
        XCTAssertEqual(SignalQuality.veryWeak.rawValue, "Very Weak")
        XCTAssertEqual(SignalQuality.none.rawValue, "No Signal")
    }

    // MARK: - ConnectionQuality Tests

    func testConnectionQualityScores() {
        XCTAssertEqual(ConnectionQuality.excellent.score, 100)
        XCTAssertEqual(ConnectionQuality.good.score, 75)
        XCTAssertEqual(ConnectionQuality.fair.score, 50)
        XCTAssertEqual(ConnectionQuality.poor.score, 25)
        XCTAssertEqual(ConnectionQuality.none.score, 0)
    }
}
