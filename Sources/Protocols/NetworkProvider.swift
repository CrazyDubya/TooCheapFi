import Foundation

/// Protocol for network request operations
/// Allows mocking network calls in tests
public protocol NetworkRequestProvider {
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
public class SystemNetworkProvider: NetworkRequestProvider {
    public init() {}

    public func ping(host: String, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        let result = NetworkUtilities.ping(host, timeout: timeout)
        return (result.reachable, result.latency)
    }

    public func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let connected = NetworkUtilities.tcpConnect(host: host, port: port, timeout: timeout)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        return (connected, connected ? elapsed : nil)
    }

    public func resolveDNS(domain: String) -> (success: Bool, latency: TimeInterval?) {
        let result = NetworkUtilities.resolveDNS(domain, timeout: 5.0)
        return (result.resolved, result.latency)
    }

    public func httpCheck(url: String) -> (success: Bool, isCaptivePortal: Bool, responseBody: String?) {
        let result = NetworkUtilities.httpGet(url, timeout: 10.0)
        let isCaptive = result.statusCode == 302 ||
                        result.statusCode == 303 ||
                        (result.body != nil && result.body != AppConstants.captivePortalExpectedResponse)
        return (result.success, isCaptive, result.body)
    }
}

/// Mock implementation for testing
public class MockNetworkProvider: NetworkRequestProvider {
    public var pingResult: (success: Bool, latency: TimeInterval?) = (true, 10.0)
    public var tcpResult: (success: Bool, latency: TimeInterval?) = (true, 15.0)
    public var dnsResult: (success: Bool, latency: TimeInterval?) = (true, 5.0)
    public var httpResult: (success: Bool, isCaptivePortal: Bool, responseBody: String?) = (true, false, nil)

    public var pingCallCount = 0
    public var tcpCallCount = 0
    public var dnsCallCount = 0
    public var httpCallCount = 0

    public init() {}

    public func ping(host: String, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        pingCallCount += 1
        return pingResult
    }

    public func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> (success: Bool, latency: TimeInterval?) {
        tcpCallCount += 1
        return tcpResult
    }

    public func resolveDNS(domain: String) -> (success: Bool, latency: TimeInterval?) {
        dnsCallCount += 1
        return dnsResult
    }

    public func httpCheck(url: String) -> (success: Bool, isCaptivePortal: Bool, responseBody: String?) {
        httpCallCount += 1
        return httpResult
    }

    public func reset() {
        pingCallCount = 0
        tcpCallCount = 0
        dnsCallCount = 0
        httpCallCount = 0
    }
}
