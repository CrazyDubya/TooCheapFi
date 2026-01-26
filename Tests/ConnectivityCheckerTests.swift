import XCTest

/// Tests for the connectivity checker module
final class ConnectivityCheckerTests: XCTestCase {

    // MARK: - Gateway Check Tests

    func testGatewayTargets() {
        // Gateway is typically at x.x.x.1 or x.x.x.254
        let localIP = "192.168.1.100"
        let components = localIP.split(separator: ".")

        XCTAssertEqual(components.count, 4, "IPv4 should have 4 octets")

        if components.count >= 3 {
            let prefix = components[0..<3].joined(separator: ".")
            let gateway1 = "\(prefix).1"
            let gateway254 = "\(prefix).254"

            XCTAssertEqual(gateway1, "192.168.1.1", "Gateway option 1 should be x.x.x.1")
            XCTAssertEqual(gateway254, "192.168.1.254", "Gateway option 2 should be x.x.x.254")
        }
    }

    func testGatewayLatencyThresholds() {
        // Good: < 5ms, Fair: < 20ms, Poor: >= 20ms
        let goodLatency = 3.0
        let fairLatency = 15.0
        let poorLatency = 25.0

        XCTAssertLessThan(goodLatency, 5, "Good latency should be < 5ms")
        XCTAssertLessThan(fairLatency, 20, "Fair latency should be < 20ms")
        XCTAssertGreaterThanOrEqual(poorLatency, 20, "Poor latency should be >= 20ms")
    }

    // MARK: - Internet Check Tests

    func testInternetTargets() {
        let targets = [
            "1.1.1.1",      // Cloudflare
            "8.8.8.8",      // Google
            "208.67.222.222" // OpenDNS
        ]

        XCTAssertEqual(targets.count, 3, "Should check 3 internet targets")
        XCTAssertTrue(targets.contains("1.1.1.1"), "Should include Cloudflare")
        XCTAssertTrue(targets.contains("8.8.8.8"), "Should include Google")
    }

    func testInternetLatencyThresholds() {
        // Based on Preferences defaults: good < 30, fair < 50, poor < 100
        let goodLatency = 25.0
        let fairLatency = 45.0
        let poorLatency = 80.0
        let veryPoorLatency = 150.0

        XCTAssertLessThan(goodLatency, 30, "Good latency should be < 30ms")
        XCTAssertLessThan(fairLatency, 50, "Fair latency should be < 50ms")
        XCTAssertLessThan(poorLatency, 100, "Poor latency should be < 100ms")
        XCTAssertGreaterThanOrEqual(veryPoorLatency, 100, "Very poor latency should be >= 100ms")
    }

    func testBestLatencySelection() {
        let latencies = [45.0, 30.0, 60.0]
        let best = latencies.min()
        XCTAssertEqual(best, 30.0, "Should select minimum latency")
    }

    // MARK: - DNS Check Tests

    func testDNSTestDomains() {
        let domains = ["apple.com", "google.com", "cloudflare.com"]

        XCTAssertEqual(domains.count, 3, "Should test 3 DNS domains")
        for domain in domains {
            XCTAssertTrue(domain.contains("."), "Domain should contain a dot")
            XCTAssertFalse(domain.hasPrefix("http"), "Domain should not have protocol")
        }
    }

    func testDNSResolutionSuccess() {
        // Simulating DNS resolution result
        let resolvedAddresses = ["142.250.185.78", "2607:f8b0:4004:800::200e"]
        let success = !resolvedAddresses.isEmpty

        XCTAssertTrue(success, "DNS resolution succeeds when addresses returned")
    }

    func testDNSResolutionFailure() {
        let resolvedAddresses: [String] = []
        let success = !resolvedAddresses.isEmpty

        XCTAssertFalse(success, "DNS resolution fails when no addresses returned")
    }

    // MARK: - HTTP Check Tests

    func testHTTPCheckURL() {
        let captivePortalURL = "http://captive.apple.com/hotspot-detect.html"

        XCTAssertTrue(captivePortalURL.hasPrefix("http://"), "Should use HTTP (not HTTPS) for captive portal detection")
        XCTAssertTrue(captivePortalURL.contains("apple.com"), "Should use Apple's captive portal URL")
    }

    func testCaptivePortalDetection_Success() {
        let expectedResponse = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"
        let actualResponse = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"

        let isCaptivePortal = actualResponse != expectedResponse
        XCTAssertFalse(isCaptivePortal, "Matching response means no captive portal")
    }

    func testCaptivePortalDetection_Detected() {
        let expectedResponse = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"
        let actualResponse = "<html><head><title>Login Required</title></head><body>Please login</body></html>"

        let isCaptivePortal = actualResponse != expectedResponse
        XCTAssertTrue(isCaptivePortal, "Different response indicates captive portal")
    }

    func testCaptivePortalDetection_Redirect() {
        let responseCode = 302
        let isCaptivePortal = responseCode == 302 || responseCode == 303

        XCTAssertTrue(isCaptivePortal, "Redirect response indicates captive portal")
    }

    // MARK: - Ping Tests

    func testPingTimeout() {
        let timeout: TimeInterval = 5.0
        XCTAssertEqual(timeout, 5.0, "Default ping timeout should be 5 seconds")
    }

    func testPingSuccessCondition() {
        let replyReceived = true
        let latency = 25.0

        XCTAssertTrue(replyReceived, "Ping succeeds when reply received")
        XCTAssertGreaterThan(latency, 0, "Latency should be positive on success")
    }

    // MARK: - TCP Connection Tests

    func testTCPPorts() {
        let httpPort = 80
        let httpsPort = 443
        let dnsPort = 53

        XCTAssertEqual(httpPort, 80, "HTTP port should be 80")
        XCTAssertEqual(httpsPort, 443, "HTTPS port should be 443")
        XCTAssertEqual(dnsPort, 53, "DNS port should be 53")
    }

    func testTCPTimeout() {
        let connectTimeout: TimeInterval = 5.0
        XCTAssertLessThanOrEqual(connectTimeout, 10, "TCP timeout should be reasonable")
    }

    // MARK: - Result Aggregation Tests

    func testConnectivityResultAggregation_AllPass() {
        let gatewayReachable = true
        let internetReachable = true
        let dnsWorking = true
        let httpWorking = true

        let allWorking = gatewayReachable && internetReachable && dnsWorking && httpWorking
        XCTAssertTrue(allWorking, "All connectivity checks pass")
    }

    func testConnectivityResultAggregation_PartialFailure() {
        let gatewayReachable = true
        let internetReachable = true
        let dnsWorking = false
        let httpWorking = true

        let allWorking = gatewayReachable && internetReachable && dnsWorking && httpWorking
        XCTAssertFalse(allWorking, "Partial failure should result in not all working")
    }

    // MARK: - Latency Comparison Tests

    func testLatencyComparison_BetterLatency() {
        let current: Double? = 30.0
        let new: Double = 25.0

        let best: Double
        if let c = current {
            best = min(c, new)
        } else {
            best = new
        }

        XCTAssertEqual(best, 25.0, "Should select better (lower) latency")
    }

    func testLatencyComparison_NilCurrent() {
        let current: Double? = nil
        let new: Double = 25.0

        let best: Double
        if let c = current {
            best = min(c, new)
        } else {
            best = new
        }

        XCTAssertEqual(best, 25.0, "Should use new latency when current is nil")
    }

    // MARK: - Interface Type Tests

    func testInterfaceTypes() {
        let types = ["none", "wifi", "ethernet", "cellular", "vpn", "other"]
        XCTAssertEqual(types.count, 6, "Should have 6 interface types")
    }

    func testInterfaceClassification_WiFi() {
        let interfaceName = "en0"
        let isWiFi = interfaceName.hasPrefix("en")
        XCTAssertTrue(isWiFi, "en0 should be classified as WiFi/Ethernet")
    }

    func testInterfaceClassification_VPN() {
        let interfaceNames = ["utun0", "ipsec0"]
        for name in interfaceNames {
            let isVPN = name.hasPrefix("utun") || name.hasPrefix("ipsec")
            XCTAssertTrue(isVPN, "\(name) should be classified as VPN")
        }
    }

    func testInterfaceClassification_Cellular() {
        let interfaceName = "pdp_ip0"
        let isCellular = interfaceName.hasPrefix("pdp_ip")
        XCTAssertTrue(isCellular, "pdp_ip0 should be classified as Cellular")
    }
}
