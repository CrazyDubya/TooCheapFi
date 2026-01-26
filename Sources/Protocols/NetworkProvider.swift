import Foundation

/// Protocol for network request operations
/// Allows mocking network calls in tests
protocol NetworkRequestProvider {
    /// Pings a host and returns success status and latency
    func ping(host: String, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?)

    /// Attempts TCP connection to host:port
    func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?)

    /// Resolves DNS for a domain
    func resolveDNS(domain: String) -> (success: Bool, latency: TimeInterval?)

    /// Performs HTTP check for captive portal detection
    func httpCheck(url: String) -> (success: Bool, isCaptivePortal: Bool, responseBody: String?)
}

/// Default implementation using system network utilities
class SystemNetworkProvider: NetworkRequestProvider {

    func ping(host: String, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        NetworkUtilities.ping(host: host, timeout: timeout)
    }

    func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        NetworkUtilities.tcpConnect(host: host, port: port, timeout: timeout)
    }

    func resolveDNS(domain: String) -> (success: Bool, latency: TimeInterval?) {
        NetworkUtilities.resolveDNS(domain: domain)
    }

    func httpCheck(url: String) -> (success: Bool, isCaptivePortal: Bool, responseBody: String?) {
        NetworkUtilities.httpCheck(url: url)
    }
}

/// Mock implementation for testing
class MockNetworkProvider: NetworkRequestProvider {
    var pingResult: (success: Bool, latency: TimeInterval?) = (true, 10.0)
    var tcpResult: (success: Bool, latency: TimeInterval?) = (true, 15.0)
    var dnsResult: (success: Bool, latency: TimeInterval?) = (true, 5.0)
    var httpResult: (success: Bool, isCaptivePortal: Bool, responseBody: String?) = (true, false, nil)

    var pingCallCount = 0
    var tcpCallCount = 0
    var dnsCallCount = 0
    var httpCallCount = 0

    func ping(host: String, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        pingCallCount += 1
        return pingResult
    }

    func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        tcpCallCount += 1
        return tcpResult
    }

    func resolveDNS(domain: String) -> (success: Bool, latency: TimeInterval?) {
        dnsCallCount += 1
        return dnsResult
    }

    func httpCheck(url: String) -> (success: Bool, isCaptivePortal: Bool, responseBody: String?) {
        httpCallCount += 1
        return httpResult
    }

    func reset() {
        pingCallCount = 0
        tcpCallCount = 0
        dnsCallCount = 0
        httpCallCount = 0
    }
}
