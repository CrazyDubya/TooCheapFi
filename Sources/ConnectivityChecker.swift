import Foundation

/// Handles multi-layer connectivity checks
public struct ConnectivityChecker {

    private let ispTestTargets: [String]
    private let dnsTestDomains: [String]
    private let captivePortalURL: String
    private let pingTimeout: TimeInterval
    private let httpTimeout: TimeInterval

    public init(
        ispTestTargets: [String] = Preferences.shared.ispTestTargets,
        dnsTestDomains: [String] = Preferences.shared.dnsTestDomains,
        captivePortalURL: String = "http://captive.apple.com/hotspot-detect.html",
        pingTimeout: TimeInterval = TimeInterval(Preferences.shared.pingTimeoutSeconds),
        httpTimeout: TimeInterval = 5.0
    ) {
        self.ispTestTargets = ispTestTargets
        self.dnsTestDomains = dnsTestDomains
        self.captivePortalURL = captivePortalURL
        self.pingTimeout = pingTimeout
        self.httpTimeout = httpTimeout
    }

    // MARK: - Gateway Check (Layer 2)

    public struct GatewayResult {
        public let reachable: Bool
        public let gatewayIP: String?
        public let latency: Double?

        public init(reachable: Bool, gatewayIP: String?, latency: Double?) {
            self.reachable = reachable
            self.gatewayIP = gatewayIP
            self.latency = latency
        }
    }

    /// Checks if the default gateway is reachable
    /// Falls back to TCP if ICMP is blocked
    public func checkGateway() -> GatewayResult {
        guard let gateway = NetworkUtilities.getDefaultGateway() else {
            return GatewayResult(reachable: false, gatewayIP: nil, latency: nil)
        }

        // Try ICMP ping first
        let pingResult = NetworkUtilities.ping(gateway, timeout: pingTimeout)
        if pingResult.reachable {
            return GatewayResult(reachable: true, gatewayIP: gateway, latency: pingResult.latency)
        }

        // Fallback: Try TCP connection to common ports (80, 443, 53)
        // Many routers block ICMP but respond to TCP
        for port in [80, 443, 53] {
            if NetworkUtilities.tcpConnect(host: gateway, port: port, timeout: pingTimeout) {
                return GatewayResult(reachable: true, gatewayIP: gateway, latency: nil)
            }
        }

        return GatewayResult(reachable: false, gatewayIP: gateway, latency: nil)
    }

    // MARK: - Internet Check (Layer 3)

    public struct InternetResult {
        public let reachable: Bool
        public let latency: Double?
        public let testedTargets: [String]

        public init(reachable: Bool, latency: Double?, testedTargets: [String]) {
            self.reachable = reachable
            self.latency = latency
            self.testedTargets = testedTargets
        }
    }

    /// Checks internet connectivity using multiple targets
    /// Tests ICMP first, falls back to TCP
    public func checkInternet() -> InternetResult {
        var testedTargets: [String] = []
        var bestLatency: Double?

        // Try ICMP ping to each target
        for target in ispTestTargets {
            testedTargets.append(target)
            let result = NetworkUtilities.ping(target, timeout: pingTimeout)

            if result.reachable {
                if let lat = result.latency {
                    bestLatency = min(lat, bestLatency ?? .infinity)
                }
                return InternetResult(reachable: true, latency: bestLatency, testedTargets: testedTargets)
            }
        }

        // All ICMP tests failed - try TCP as fallback
        for target in ispTestTargets {
            if NetworkUtilities.tcpConnect(host: target, port: 53, timeout: pingTimeout) {
                return InternetResult(reachable: true, latency: nil, testedTargets: testedTargets)
            }
        }

        return InternetResult(reachable: false, latency: nil, testedTargets: testedTargets)
    }

    // MARK: - DNS Check (Layer 4)

    public struct DNSResult {
        public let working: Bool
        public let latency: Double?
        public let testedDomains: [String]

        public init(working: Bool, latency: Double?, testedDomains: [String]) {
            self.working = working
            self.latency = latency
            self.testedDomains = testedDomains
        }
    }

    /// Checks DNS resolution using multiple domains
    public func checkDNS() -> DNSResult {
        var testedDomains: [String] = []
        var bestLatency: Double?

        for domain in dnsTestDomains {
            testedDomains.append(domain)
            let result = NetworkUtilities.resolveDNS(domain, timeout: pingTimeout)

            if result.resolved {
                if let lat = result.latency {
                    bestLatency = min(lat, bestLatency ?? .infinity)
                }
                return DNSResult(working: true, latency: bestLatency, testedDomains: testedDomains)
            }
        }

        return DNSResult(working: false, latency: nil, testedDomains: testedDomains)
    }

    // MARK: - HTTP / Captive Portal Check (Layer 5)

    public struct HTTPResult {
        public let httpWorking: Bool
        public let captivePortalDetected: Bool
        public let captivePortalURL: String?

        public init(httpWorking: Bool, captivePortalDetected: Bool, captivePortalURL: String?) {
            self.httpWorking = httpWorking
            self.captivePortalDetected = captivePortalDetected
            self.captivePortalURL = captivePortalURL
        }
    }

    /// Checks HTTP connectivity and detects captive portals
    public func checkHTTP() -> HTTPResult {
        let result = NetworkUtilities.httpGet(captivePortalURL, timeout: httpTimeout)

        guard result.success, let statusCode = result.statusCode else {
            return HTTPResult(httpWorking: false, captivePortalDetected: false, captivePortalURL: nil)
        }

        // Redirect = captive portal
        if statusCode == 302 || statusCode == 303 {
            return HTTPResult(
                httpWorking: false,
                captivePortalDetected: true,
                captivePortalURL: result.redirectURL
            )
        }

        // Check 200 response content
        if statusCode == 200 {
            if let body = result.body,
               body.contains("<TITLE>Success</TITLE>") || body.contains("Success") {
                return HTTPResult(httpWorking: true, captivePortalDetected: false, captivePortalURL: nil)
            } else {
                // Got 200 but wrong content = captive portal
                return HTTPResult(httpWorking: false, captivePortalDetected: true, captivePortalURL: nil)
            }
        }

        return HTTPResult(httpWorking: false, captivePortalDetected: false, captivePortalURL: nil)
    }
}
