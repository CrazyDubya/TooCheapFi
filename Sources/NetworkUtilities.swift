import Foundation
import Network
import SystemConfiguration

/// Low-level network utility functions
enum NetworkUtilities {

    private static let monitorQueue = DispatchQueue(label: "com.toocheapfi.utilities")

    // MARK: - ICMP Ping

    /// Pings a host and returns reachability status with latency
    /// - Parameters:
    ///   - host: IP address or hostname to ping
    ///   - timeout: Maximum time to wait for response
    /// - Returns: Tuple of (isReachable, latencyInMs)
    static func ping(_ host: String, timeout: TimeInterval) -> (reachable: Bool, latency: Double?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let semaphore = DispatchSemaphore(value: 0)
        var isReachable = false

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "1", "-t", String(Int(timeout)), host]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.terminationHandler = { process in
            isReachable = process.terminationStatus == 0
            semaphore.signal()
        }

        do {
            try task.run()
        } catch {
            semaphore.signal()
            return (false, nil)
        }

        _ = semaphore.wait(timeout: .now() + timeout + 1.0)

        if task.isRunning {
            task.terminate()
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000  // ms
        return (isReachable, isReachable ? elapsed : nil)
    }

    // MARK: - TCP Connection

    /// Attempts a TCP connection to verify host reachability
    /// - Parameters:
    ///   - host: IP address or hostname
    ///   - port: TCP port number
    ///   - timeout: Maximum time to wait for connection
    /// - Returns: True if connection succeeded
    static func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var connected = false

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connected = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: monitorQueue)

        _ = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()

        return connected
    }

    // MARK: - DNS Resolution

    /// Resolves a domain name and returns success status with latency
    /// - Parameters:
    ///   - domain: Domain name to resolve
    ///   - timeout: Maximum time to wait for resolution
    /// - Returns: Tuple of (resolved, latencyInMs)
    static func resolveDNS(_ domain: String, timeout: TimeInterval) -> (resolved: Bool, latency: Double?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let semaphore = DispatchSemaphore(value: 0)
        var resolved = false

        let host = CFHostCreateWithName(nil, domain as CFString).takeRetainedValue()

        // Timeout handler
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            CFHostCancelInfoResolution(host, .addresses)
            semaphore.signal()
        }

        CFHostStartInfoResolution(host, .addresses, nil)

        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data],
           !addresses.isEmpty, success.boolValue {
            resolved = true
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        CFHostCancelInfoResolution(host, .addresses)

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000  // ms
        return (resolved, resolved ? elapsed : nil)
    }

    // MARK: - Gateway Detection

    /// Returns the default gateway IP address
    static func getDefaultGateway() -> String? {
        guard let routeInfo = SCDynamicStoreCopyValue(
            nil,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any],
              let routerAddress = routeInfo["Router"] as? String else {
            return nil
        }
        return routerAddress
    }

    // MARK: - HTTP Request

    /// HTTP request result
    struct HTTPResult {
        let success: Bool
        let statusCode: Int?
        let body: String?
        let redirectURL: String?
    }

    /// Performs an HTTP GET request
    /// - Parameters:
    ///   - urlString: URL to fetch
    ///   - timeout: Maximum time to wait
    /// - Returns: HTTP result with status code and body
    static func httpGet(_ urlString: String, timeout: TimeInterval) -> HTTPResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result = HTTPResult(success: false, statusCode: nil, body: nil, redirectURL: nil)

        guard let url = URL(string: urlString) else {
            return result
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"

        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse else {
                return
            }

            let body = data.flatMap { String(data: $0, encoding: .utf8) }
            let redirectURL = httpResponse.value(forHTTPHeaderField: "Location")

            result = HTTPResult(
                success: true,
                statusCode: httpResponse.statusCode,
                body: body,
                redirectURL: redirectURL
            )
        }.resume()

        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        session.invalidateAndCancel()

        return result
    }
}
