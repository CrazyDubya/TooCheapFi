import XCTest

/// Tests for quality score calculations
final class QualityScoreTests: XCTestCase {

    // MARK: - Quality Level Tests

    func testQualityFromScore_Excellent() {
        let quality = qualityFromScore(85)
        XCTAssertEqual(quality, "excellent", "Score 85 should be excellent")

        let quality100 = qualityFromScore(100)
        XCTAssertEqual(quality100, "excellent", "Score 100 should be excellent")

        let quality80 = qualityFromScore(80)
        XCTAssertEqual(quality80, "excellent", "Score 80 should be excellent")
    }

    func testQualityFromScore_Good() {
        let quality = qualityFromScore(70)
        XCTAssertEqual(quality, "good", "Score 70 should be good")

        let quality79 = qualityFromScore(79)
        XCTAssertEqual(quality79, "good", "Score 79 should be good")

        let quality60 = qualityFromScore(60)
        XCTAssertEqual(quality60, "good", "Score 60 should be good")
    }

    func testQualityFromScore_Fair() {
        let quality = qualityFromScore(50)
        XCTAssertEqual(quality, "fair", "Score 50 should be fair")

        let quality59 = qualityFromScore(59)
        XCTAssertEqual(quality59, "fair", "Score 59 should be fair")

        let quality40 = qualityFromScore(40)
        XCTAssertEqual(quality40, "fair", "Score 40 should be fair")
    }

    func testQualityFromScore_Poor() {
        let quality = qualityFromScore(30)
        XCTAssertEqual(quality, "poor", "Score 30 should be poor")

        let quality1 = qualityFromScore(1)
        XCTAssertEqual(quality1, "poor", "Score 1 should be poor")
    }

    func testQualityFromScore_None() {
        let quality = qualityFromScore(0)
        XCTAssertEqual(quality, "none", "Score 0 should be none")
    }

    // MARK: - Signal Penalty Tests

    func testSignalPenalty_Excellent() {
        let penalty = signalPenalty(rssi: -45)
        XCTAssertEqual(penalty, 0, "Excellent signal should have no penalty")
    }

    func testSignalPenalty_Good() {
        let penalty = signalPenalty(rssi: -60)
        XCTAssertEqual(penalty, 5, "Good signal should have 5 point penalty")
    }

    func testSignalPenalty_Fair() {
        let penalty = signalPenalty(rssi: -68)
        XCTAssertEqual(penalty, 15, "Fair signal should have 15 point penalty")
    }

    func testSignalPenalty_Weak() {
        let penalty = signalPenalty(rssi: -75)
        XCTAssertEqual(penalty, 30, "Weak signal should have 30 point penalty")
    }

    func testSignalPenalty_VeryWeak() {
        let penalty = signalPenalty(rssi: -85)
        XCTAssertEqual(penalty, 50, "Very weak signal should have 50 point penalty")
    }

    // MARK: - Latency Penalty Tests

    func testLatencyPenalty_Low() {
        let penalty = latencyPenalty(ms: 20)
        XCTAssertEqual(penalty, 0, "Low latency should have no penalty")
    }

    func testLatencyPenalty_Medium() {
        let penalty = latencyPenalty(ms: 40)
        XCTAssertEqual(penalty, 5, "Medium latency should have 5 point penalty")
    }

    func testLatencyPenalty_High() {
        let penalty = latencyPenalty(ms: 75)
        XCTAssertEqual(penalty, 10, "High latency should have 10 point penalty")
    }

    func testLatencyPenalty_VeryHigh() {
        let penalty = latencyPenalty(ms: 150)
        XCTAssertEqual(penalty, 20, "Very high latency should have 20 point penalty")
    }

    // MARK: - SNR Penalty Tests

    func testSNRPenalty_Good() {
        let penalty = snrPenalty(snr: 30)
        XCTAssertEqual(penalty, 0, "Good SNR should have no penalty")
    }

    func testSNRPenalty_Moderate() {
        let penalty = snrPenalty(snr: 20)
        XCTAssertEqual(penalty, 10, "Moderate SNR should have 10 point penalty")
    }

    func testSNRPenalty_Poor() {
        let penalty = snrPenalty(snr: 10)
        XCTAssertEqual(penalty, 20, "Poor SNR should have 20 point penalty")
    }

    // MARK: - Combined Score Tests

    func testPerfectScore() {
        let score = calculateScore(
            connected: true,
            gatewayReachable: true,
            internetReachable: true,
            dnsWorking: true,
            httpWorking: true,
            rssi: -45,
            snr: 35,
            latency: 15,
            congestion: 0
        )
        XCTAssertEqual(score, 100, "Perfect conditions should yield score of 100")
    }

    func testNoConnection() {
        let score = calculateScore(
            connected: false,
            gatewayReachable: false,
            internetReachable: false,
            dnsWorking: false,
            httpWorking: false,
            rssi: nil,
            snr: nil,
            latency: nil,
            congestion: 0
        )
        XCTAssertEqual(score, 0, "No connection should yield score of 0")
    }

    func testGatewayUnreachable() {
        let score = calculateScore(
            connected: true,
            gatewayReachable: false,
            internetReachable: false,
            dnsWorking: false,
            httpWorking: false,
            rssi: -50,
            snr: 30,
            latency: nil,
            congestion: 0
        )
        XCTAssertEqual(score, 10, "Gateway unreachable should yield score of 10")
    }

    func testNoInternet() {
        let score = calculateScore(
            connected: true,
            gatewayReachable: true,
            internetReachable: false,
            dnsWorking: false,
            httpWorking: false,
            rssi: -50,
            snr: 30,
            latency: nil,
            congestion: 0
        )
        XCTAssertEqual(score, 20, "No internet should yield score of 20")
    }

    // MARK: - Helper Functions (mirroring production logic)

    private func qualityFromScore(_ score: Int) -> String {
        switch score {
        case 80...100: return "excellent"
        case 60..<80: return "good"
        case 40..<60: return "fair"
        case 1..<40: return "poor"
        default: return "none"
        }
    }

    private func signalPenalty(rssi: Int) -> Int {
        switch rssi {
        case -50...0: return 0       // Excellent
        case -60..<(-50): return 5   // Good
        case -70..<(-60): return 15  // Fair
        case -80..<(-70): return 30  // Weak
        default: return 50           // Very weak
        }
    }

    private func latencyPenalty(ms: Double) -> Int {
        if ms > 100 { return 20 }
        else if ms > 50 { return 10 }
        else if ms > 30 { return 5 }
        return 0
    }

    private func snrPenalty(snr: Int) -> Int {
        if snr < 15 { return 20 }
        else if snr < 25 { return 10 }
        return 0
    }

    private func calculateScore(
        connected: Bool,
        gatewayReachable: Bool,
        internetReachable: Bool,
        dnsWorking: Bool,
        httpWorking: Bool,
        rssi: Int?,
        snr: Int?,
        latency: Double?,
        congestion: Int
    ) -> Int {
        if !connected { return 0 }
        if !gatewayReachable { return 10 }
        if !internetReachable { return 20 }
        if !dnsWorking { return 30 }

        var score = 100
        if !httpWorking { score -= 10 }

        if let lat = latency {
            score -= latencyPenalty(ms: lat)
        }

        if let r = rssi {
            score -= signalPenalty(rssi: r)
        }

        if let s = snr {
            score -= snrPenalty(snr: s)
        }

        // Congestion penalty
        if congestion > 10 { score -= 15 }
        else if congestion > 5 { score -= 10 }
        else if congestion > 2 { score -= 5 }

        return max(0, min(100, score))
    }
}
