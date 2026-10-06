import XCTest
@testable import TooCheapFiCore

/// Tests for quality score calculations using production IssueAnalyzer
final class QualityScoreTests: XCTestCase {

    private var analyzer: IssueAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = IssueAnalyzer()
    }

    // MARK: - Quality Level Tests (Using Production ConnectionQuality)

    func testQualityFromScore_Excellent() {
        // ConnectionQuality.excellent requires score 80-100
        XCTAssertEqual(ConnectionQuality.excellent.score, 100)
    }

    func testQualityFromScore_Good() {
        XCTAssertEqual(ConnectionQuality.good.score, 75)
    }

    func testQualityFromScore_Fair() {
        XCTAssertEqual(ConnectionQuality.fair.score, 50)
    }

    func testQualityFromScore_Poor() {
        XCTAssertEqual(ConnectionQuality.poor.score, 25)
    }

    func testQualityFromScore_None() {
        XCTAssertEqual(ConnectionQuality.none.score, 0)
    }

    // MARK: - Signal Penalty Tests (Using Production SignalQuality)

    func testSignalPenalty_Excellent() {
        let quality = SignalQuality.from(rssi: -45)
        XCTAssertEqual(quality, .excellent, "RSSI -45 should be excellent signal")
    }

    func testSignalPenalty_Good() {
        let quality = SignalQuality.from(rssi: -55)
        XCTAssertEqual(quality, .good, "RSSI -55 should be good signal")
    }

    func testSignalPenalty_Fair() {
        let quality = SignalQuality.from(rssi: -68)
        XCTAssertEqual(quality, .fair, "RSSI -68 should be fair signal")
    }

    func testSignalPenalty_Weak() {
        let quality = SignalQuality.from(rssi: -75)
        XCTAssertEqual(quality, .weak, "RSSI -75 should be weak signal")
    }

    func testSignalPenalty_VeryWeak() {
        let quality = SignalQuality.from(rssi: -85)
        XCTAssertEqual(quality, .veryWeak, "RSSI -85 should be very weak signal")
    }

    // MARK: - IssueAnalyzer Integration Tests

    func testAnalyze_PerfectConnection() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = true
        status.internetReachable = true
        status.dnsWorking = true
        status.httpWorking = true
        status.captivePortalDetected = false
        status.internetLatency = 15.0
        status.wifiInfo = WiFiInfo(
            ssid: "TestNetwork",
            bssid: "00:11:22:33:44:55",
            rssi: -45,
            noise: -90,
            channel: 6,
            channelBand: "2.4 GHz",
            channelWidth: 40,
            transmitRate: 300.0,
            phyMode: "802.11n",
            security: "WPA2",
            signalQuality: .excellent
        )

        let result = analyzer.analyze(status)

        XCTAssertGreaterThanOrEqual(result.qualityScore, 80, "Perfect connection should have high score")
        XCTAssertEqual(result.overallQuality, .excellent, "Perfect connection should be excellent quality")
        XCTAssertTrue(result.issues.isEmpty || result.issues.allSatisfy { $0.severity == .info },
                     "Perfect connection should have no critical issues")
    }

    func testAnalyze_NoConnection() {
        var status = NetworkStatus.unknown
        status.interfaceType = .none

        let result = analyzer.analyze(status)

        XCTAssertEqual(result.qualityScore, 0, "No connection should yield score of 0")
        XCTAssertEqual(result.overallQuality, .none, "No connection should be none quality")
        XCTAssertFalse(result.issues.isEmpty, "No connection should have issues")
    }

    func testAnalyze_GatewayUnreachable() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = false
        status.internetReachable = false
        status.dnsWorking = false
        status.httpWorking = false

        let result = analyzer.analyze(status)

        XCTAssertEqual(result.qualityScore, 10, "Gateway unreachable should yield score of 10")
        XCTAssertTrue(result.issues.contains { $0.severity == .critical },
                     "Gateway unreachable should have critical issues")
    }

    func testAnalyze_NoInternet() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = true
        status.internetReachable = false
        status.dnsWorking = false
        status.httpWorking = false

        let result = analyzer.analyze(status)

        XCTAssertEqual(result.qualityScore, 20, "No internet should yield score of 20")
    }

    func testAnalyze_CaptivePortal() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = true
        status.internetReachable = true
        status.captivePortalDetected = true
        status.dnsWorking = false
        status.httpWorking = false

        let result = analyzer.analyze(status)

        XCTAssertEqual(result.qualityScore, 25, "Captive portal should yield score of 25")
        XCTAssertTrue(result.issues.contains { $0.title.contains("Captive Portal") },
                     "Should detect captive portal issue")
    }

    func testAnalyze_DNSFailure() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = true
        status.internetReachable = true
        status.captivePortalDetected = false
        status.dnsWorking = false
        status.httpWorking = false

        let result = analyzer.analyze(status)

        XCTAssertEqual(result.qualityScore, 30, "DNS failure should yield score of 30")
        XCTAssertTrue(result.issues.contains { $0.title.contains("DNS") },
                     "Should detect DNS issue")
    }

    func testAnalyze_WeakSignal() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = true
        status.internetReachable = true
        status.dnsWorking = true
        status.httpWorking = true
        status.captivePortalDetected = false
        status.wifiInfo = WiFiInfo(
            ssid: "TestNetwork",
            bssid: "00:11:22:33:44:55",
            rssi: -85,
            noise: -90,
            channel: 6,
            channelBand: "2.4 GHz",
            channelWidth: 20,
            transmitRate: 54.0,
            phyMode: "802.11n",
            security: "WPA2",
            signalQuality: .veryWeak
        )

        let result = analyzer.analyze(status)

        XCTAssertLessThan(result.qualityScore, 80, "Weak signal should reduce score")
        XCTAssertTrue(result.issues.contains { $0.category == .wifi },
                     "Should detect WiFi signal issue")
    }

    func testAnalyze_HighLatency() {
        var status = NetworkStatus.unknown
        status.interfaceType = .wifi
        status.gatewayReachable = true
        status.internetReachable = true
        status.dnsWorking = true
        status.httpWorking = true
        status.captivePortalDetected = false
        status.internetLatency = 150.0  // High latency

        let result = analyzer.analyze(status)

        XCTAssertLessThan(result.qualityScore, 100, "High latency should reduce score")
    }

    // MARK: - Issue Severity Tests

    func testIssueSeverity_Comparable() {
        XCTAssertLessThan(IssueSeverity.info, IssueSeverity.warning)
        XCTAssertLessThan(IssueSeverity.warning, IssueSeverity.critical)
        XCTAssertGreaterThan(IssueSeverity.critical, IssueSeverity.info)
    }

    // MARK: - NetworkIssue Tests

    func testNetworkIssueCreation() {
        let issue = NetworkIssue(
            severity: .critical,
            title: "Test Issue",
            description: "Test description",
            category: .connectivity
        )

        XCTAssertEqual(issue.severity, .critical)
        XCTAssertEqual(issue.title, "Test Issue")
        XCTAssertEqual(issue.category, .connectivity)
    }

    // MARK: - NetworkRecommendation Tests

    func testNetworkRecommendationCreation() {
        let recommendation = NetworkRecommendation(
            priority: 1,
            title: "Fix connection",
            steps: ["Step 1", "Step 2", "Step 3"],
            category: .connectivity
        )

        XCTAssertEqual(recommendation.priority, 1)
        XCTAssertEqual(recommendation.title, "Fix connection")
        XCTAssertEqual(recommendation.steps.count, 3)
    }
}
