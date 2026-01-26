import Foundation
import SystemConfiguration
import Network
import CoreWLAN

/// Main network monitoring coordinator
/// Delegates to specialized modules for specific checks
class NetworkMonitor {
    var onStatusChange: ((NetworkStatus) -> Void)?
    @ThreadSafe private(set) var currentStatus: NetworkStatus = .unknown
    @ThreadSafe private var previousStatus: NetworkStatus?
    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.toocheapfi.networkmonitor")

    // Specialized analyzers
    private let connectivityChecker = ConnectivityChecker()
    private let wifiAnalyzer = WiFiAnalyzer()
    private let issueAnalyzer = IssueAnalyzer()

    // Speed test state (thread-safe)
    @ThreadSafe private var lastSpeedTest: SpeedTestResult = .notRun
    @ThreadSafe private var speedTestInProgress = false

    // Pause/resume state
    @ThreadSafe private(set) var isPaused = false
    @ThreadSafe private var pauseEndTime: Date?

    // Reusable URLSession for speed tests
    private lazy var speedTestSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    deinit {
        stopMonitoring()
    }

    private var speedTestURL: String {
        let bytes = Preferences.shared.speedTestSizeMB * 1_000_000
        return "https://speed.cloudflare.com/__down?bytes=\(bytes)"
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        checkStatus()

        let interval = TimeInterval(Preferences.shared.checkIntervalSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }

        pathMonitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.checkStatus()
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        pathMonitor.cancel()
    }

    // MARK: - Pause/Resume

    /// Pauses monitoring for the specified number of minutes
    func pauseMonitoring(minutes: Int) {
        isPaused = true
        pauseEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        logInfo("Monitoring paused for \(minutes) minutes")
    }

    /// Resumes monitoring immediately
    func resumeMonitoring() {
        isPaused = false
        pauseEndTime = nil
        logInfo("Monitoring resumed")
        checkStatus()
    }

    /// Returns the remaining pause time in seconds, or nil if not paused
    var remainingPauseTime: TimeInterval? {
        guard isPaused, let endTime = pauseEndTime else { return nil }
        let remaining = endTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Checks if pause has expired and auto-resumes if needed
    private func checkPauseExpiry() {
        guard isPaused else { return }
        if let endTime = pauseEndTime, Date() >= endTime {
            logInfo("Pause expired, auto-resuming")
            isPaused = false
            pauseEndTime = nil
        }
    }

    // MARK: - Status Check

    func checkStatus() {
        // Check if pause has expired
        checkPauseExpiry()

        // Skip check if paused
        guard !isPaused else {
            logDebug("Status check skipped (monitoring paused)")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var status = NetworkStatus.unknown

            // Layer 1: Check interface
            let interfaceResult = self.checkInterface()
            status.interfaceType = interfaceResult.type
            status.interfaceName = interfaceResult.name
            status.localIP = interfaceResult.localIP
            status.hasIPv6 = interfaceResult.hasIPv6

            // Layer 1.5: Wi-Fi details
            if interfaceResult.type == .wifi {
                status.wifiInfo = self.wifiAnalyzer.getWiFiInfo()
            }

            // Layer 2: Gateway
            let gatewayResult = self.connectivityChecker.checkGateway()
            status.gatewayReachable = gatewayResult.reachable
            status.gatewayIP = gatewayResult.gatewayIP
            status.gatewayLatency = gatewayResult.latency

            // Layer 3: Internet
            let internetResult = self.connectivityChecker.checkInternet()
            status.internetReachable = internetResult.reachable
            status.internetLatency = internetResult.latency
            status.testedTargets = internetResult.testedTargets

            // Layer 4: DNS
            let dnsResult = self.connectivityChecker.checkDNS()
            status.dnsWorking = dnsResult.working
            status.dnsLatency = dnsResult.latency
            status.testedDomains = dnsResult.testedDomains

            // Layer 5: HTTP / Captive portal
            let httpResult = self.connectivityChecker.checkHTTP()
            status.httpWorking = httpResult.httpWorking
            status.captivePortalDetected = httpResult.captivePortalDetected
            status.captivePortalURL = httpResult.captivePortalURL

            // Wi-Fi channel analysis
            if interfaceResult.type == .wifi {
                let channelResult = self.wifiAnalyzer.analyzeChannels()
                status.neighboringNetworks = channelResult.neighbors
                status.channelAnalysis = channelResult.analysis2GHz
                status.recommendedChannel = channelResult.recommended2GHz
                status.channelAnalysis5GHz = channelResult.analysis5GHz
                status.recommendedChannel5GHz = channelResult.recommended5GHz
            }

            // Speed test result
            status.speedTest = self.lastSpeedTest

            // Issue analysis and quality scoring
            let analysisResult = self.issueAnalyzer.analyze(status)
            status.issues = analysisResult.issues
            status.recommendations = analysisResult.recommendations
            status.qualityScore = analysisResult.qualityScore
            status.overallQuality = analysisResult.overallQuality

            DispatchQueue.main.async {
                let oldStatus = self.previousStatus

                NotificationManager.shared.handleStatusChange(from: oldStatus, to: status)
                HistoryStore.shared.recordStatus(status)

                // Fire event hooks
                EventHookManager.shared.notifyStatusChanged(from: oldStatus, to: status)

                self.previousStatus = self.currentStatus
                self.currentStatus = status
                self.onStatusChange?(status)
            }
        }
    }

    // MARK: - Speed Test

    func runSpeedTest(completion: @escaping (SpeedTestResult) -> Void) {
        guard !speedTestInProgress else {
            completion(lastSpeedTest)
            return
        }

        speedTestInProgress = true
        lastSpeedTest = SpeedTestResult(
            downloadSpeed: nil,
            uploadSpeed: nil,
            testTime: Date(),
            testServer: "Cloudflare",
            status: .running
        )

        DispatchQueue.main.async {
            var status = self.currentStatus
            status.speedTest = self.lastSpeedTest
            self.onStatusChange?(status)
        }

        guard let url = URL(string: speedTestURL) else {
            logError("Speed test failed: Invalid URL - \(speedTestURL)")
            lastSpeedTest.status = .failed
            speedTestInProgress = false
            completion(lastSpeedTest)
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        speedTestSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            defer {
                self.speedTestInProgress = false
            }

            if let error = error {
                logError("Speed test failed: \(error.localizedDescription)")
                self.lastSpeedTest.status = .failed
                completion(self.lastSpeedTest)
                return
            }

            guard let data = data else {
                logError("Speed test failed: No data received")
                self.lastSpeedTest.status = .failed
                completion(self.lastSpeedTest)
                return
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let bytesDownloaded = Double(data.count)
            let megabits = (bytesDownloaded * 8) / 1_000_000
            let speedMbps = megabits / elapsed

            self.lastSpeedTest = SpeedTestResult(
                downloadSpeed: speedMbps,
                uploadSpeed: nil,
                testTime: Date(),
                testServer: "Cloudflare",
                status: .completed
            )

            HistoryStore.shared.recordSpeedTest(self.lastSpeedTest)

            // Fire event hook
            EventHookManager.shared.notifySpeedTestCompleted(result: self.lastSpeedTest)

            DispatchQueue.main.async {
                var status = self.currentStatus
                status.speedTest = self.lastSpeedTest
                self.currentStatus = status
                self.onStatusChange?(status)
            }

            completion(self.lastSpeedTest)
        }.resume()
    }

    // MARK: - Interface Detection

    private struct InterfaceResult {
        let type: InterfaceType
        let name: String?
        let localIP: String?
        let hasIPv6: Bool
    }

    private func checkInterface() -> InterfaceResult {
        var interfaceType: InterfaceType = .none
        var interfaceName: String?
        var localIP: String?
        var hasIPv6 = false

        // Check Wi-Fi using CoreWLAN
        if let wifiClient = CWWiFiClient.shared().interface(),
           wifiClient.ssid() != nil {
            interfaceType = .wifi
            interfaceName = wifiClient.interfaceName
        }

        // Get IP addresses
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else {
            return InterfaceResult(type: .none, name: nil, localIP: nil, hasIPv6: false)
        }
        defer { freeifaddrs(addrs) }

        var ptr = addrs
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)

            if name == "lo0" { continue }

            let flags = Int32(interface.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) else { continue }

            let family = interface.ifa_addr?.pointee.sa_family

            if family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST
                ) == 0 {
                    let address = String(cString: hostname)

                    if address.hasPrefix("169.254.") { continue }

                    if localIP == nil {
                        localIP = address
                    }

                    if interfaceType == .none {
                        (interfaceType, interfaceName) = classifyInterface(name)
                    }
                }
            } else if family == UInt8(AF_INET6) {
                hasIPv6 = true
            }
        }

        return InterfaceResult(type: interfaceType, name: interfaceName, localIP: localIP, hasIPv6: hasIPv6)
    }

    private func classifyInterface(_ name: String) -> (InterfaceType, String) {
        if name.hasPrefix("en") {
            return (.ethernet, name)
        } else if name.hasPrefix("utun") || name.hasPrefix("ipsec") {
            return (.vpn, name)
        } else if name.hasPrefix("pdp_ip") {
            return (.cellular, name)
        } else {
            return (.other, name)
        }
    }
}
