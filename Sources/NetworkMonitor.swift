import Foundation
import SystemConfiguration
import Network
import CoreWLAN

class NetworkMonitor {
    var onStatusChange: ((NetworkStatus) -> Void)?
    private(set) var currentStatus: NetworkStatus = .unknown
    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.toocheapfi.networkmonitor")

    // Configuration - multiple targets to avoid single points of failure
    private let ispTestTargets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]  // Google, Cloudflare, OpenDNS
    private let dnsTestDomains = ["apple.com", "cloudflare.com", "microsoft.com"]
    private let captivePortalURL = "http://captive.apple.com/hotspot-detect.html"
    private let pingTimeout: TimeInterval = 2.0
    private let httpTimeout: TimeInterval = 5.0

    func startMonitoring() {
        // Initial check
        checkStatus()

        // Set up periodic checks every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }

        // Also monitor for network path changes
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

    func checkStatus() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var status = NetworkStatus.unknown

            // Layer 1: Check interface
            let (interfaceType, interfaceName, localIP, hasIPv6) = self.checkInterface()
            status.interfaceType = interfaceType
            status.interfaceName = interfaceName
            status.localIP = localIP
            status.hasIPv6 = hasIPv6

            // Layer 1.5: If Wi-Fi, get Wi-Fi details
            if interfaceType == .wifi {
                status.wifiInfo = self.getWiFiInfo()
            }

            // Layer 2: Check gateway/router
            let (gatewayReachable, gatewayIP, gatewayLatency) = self.checkGateway()
            status.gatewayReachable = gatewayReachable
            status.gatewayIP = gatewayIP
            status.gatewayLatency = gatewayLatency

            // Layer 3: Check internet (multiple targets)
            let (internetReachable, internetLatency, testedTargets) = self.checkInternet()
            status.internetReachable = internetReachable
            status.internetLatency = internetLatency
            status.testedTargets = testedTargets

            // Layer 4: Check DNS (multiple domains)
            let (dnsWorking, dnsLatency, testedDomains) = self.checkDNS()
            status.dnsWorking = dnsWorking
            status.dnsLatency = dnsLatency
            status.testedDomains = testedDomains

            // Layer 5: Check HTTP / captive portal
            let (httpWorking, captiveDetected, captiveURL) = self.checkHTTP()
            status.httpWorking = httpWorking
            status.captivePortalDetected = captiveDetected
            status.captivePortalURL = captiveURL

            // Wi-Fi channel analysis (if on Wi-Fi)
            if interfaceType == .wifi {
                let (neighbors, analysis, recommended) = self.analyzeChannels()
                status.neighboringNetworks = neighbors
                status.channelAnalysis = analysis
                status.recommendedChannel = recommended
            }

            // Generate issues and recommendations
            let (issues, recommendations) = self.analyzeStatus(status)
            status.issues = issues
            status.recommendations = recommendations

            // Calculate overall quality
            status.qualityScore = self.calculateQualityScore(status)
            status.overallQuality = self.qualityFromScore(status.qualityScore)

            DispatchQueue.main.async {
                self.currentStatus = status
                self.onStatusChange?(status)
            }
        }
    }

    // MARK: - Layer 1: Interface Detection

    private func checkInterface() -> (InterfaceType, String?, String?, Bool) {
        var interfaceType: InterfaceType = .none
        var interfaceName: String?
        var localIP: String?
        var hasIPv6 = false

        // First, check if we're on Wi-Fi using CoreWLAN
        if let wifiClient = CWWiFiClient.shared().interface(),
           wifiClient.ssid() != nil {
            interfaceType = .wifi
            interfaceName = wifiClient.interfaceName
        }

        // Get IP addresses
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else {
            return (.none, nil, nil, false)
        }
        defer { freeifaddrs(addrs) }

        var ptr = addrs
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)

            // Skip loopback
            if name == "lo0" { continue }

            let flags = Int32(interface.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) else { continue }

            let family = interface.ifa_addr?.pointee.sa_family

            if family == UInt8(AF_INET) {
                // IPv4
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    let address = String(cString: hostname)

                    // Skip link-local addresses
                    if address.hasPrefix("169.254.") { continue }

                    if localIP == nil {
                        localIP = address
                    }

                    // Determine interface type if not already Wi-Fi
                    if interfaceType == .none {
                        if name.hasPrefix("en") {
                            interfaceType = .ethernet
                            interfaceName = name
                        } else if name.hasPrefix("utun") || name.hasPrefix("ipsec") {
                            interfaceType = .vpn
                            interfaceName = name
                        } else if name.hasPrefix("pdp_ip") {
                            interfaceType = .cellular
                            interfaceName = name
                        } else {
                            interfaceType = .other
                            interfaceName = name
                        }
                    }
                }
            } else if family == UInt8(AF_INET6) {
                // IPv6
                hasIPv6 = true
            }
        }

        return (interfaceType, interfaceName, localIP, hasIPv6)
    }

    // MARK: - Layer 1.5: Wi-Fi Info

    private func getWiFiInfo() -> WiFiInfo? {
        guard let interface = CWWiFiClient.shared().interface() else {
            return nil
        }

        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let signalQuality = SignalQuality.from(rssi: rssi)

        var channelBand = "Unknown"
        var channelNum = 0
        var channelWidth = 0

        if let channel = interface.wlanChannel() {
            channelNum = channel.channelNumber

            switch channel.channelBand {
            case .band2GHz: channelBand = "2.4 GHz"
            case .band5GHz: channelBand = "5 GHz"
            case .band6GHz: channelBand = "6 GHz"
            @unknown default: channelBand = "Unknown"
            }

            switch channel.channelWidth {
            case .width20MHz: channelWidth = 20
            case .width40MHz: channelWidth = 40
            case .width80MHz: channelWidth = 80
            case .width160MHz: channelWidth = 160
            @unknown default: channelWidth = 0
            }
        }

        var phyMode = "Unknown"
        switch interface.activePHYMode() {
        case .mode11a: phyMode = "802.11a"
        case .mode11b: phyMode = "802.11b"
        case .mode11g: phyMode = "802.11g"
        case .mode11n: phyMode = "802.11n (Wi-Fi 4)"
        case .mode11ac: phyMode = "802.11ac (Wi-Fi 5)"
        case .mode11ax: phyMode = "802.11ax (Wi-Fi 6)"
        case .modeNone: phyMode = "None"
        @unknown default: phyMode = "Unknown"
        }

        var security = "Unknown"
        switch interface.security() {
        case .none: security = "Open (No Security)"
        case .WEP: security = "WEP (Insecure)"
        case .wpaPersonal: security = "WPA Personal"
        case .wpaEnterprise: security = "WPA Enterprise"
        case .wpa2Personal: security = "WPA2 Personal"
        case .wpa2Enterprise: security = "WPA2 Enterprise"
        case .wpa3Personal: security = "WPA3 Personal"
        case .wpa3Enterprise: security = "WPA3 Enterprise"
        case .wpa3Transition: security = "WPA3 Transition"
        case .dynamicWEP: security = "Dynamic WEP"
        case .unknown: security = "Unknown"
        @unknown default: security = "Unknown"
        }

        return WiFiInfo(
            ssid: interface.ssid(),
            bssid: interface.bssid(),
            rssi: rssi,
            noise: noise,
            channel: channelNum,
            channelBand: channelBand,
            channelWidth: channelWidth,
            transmitRate: interface.transmitRate(),
            phyMode: phyMode,
            security: security,
            signalQuality: signalQuality
        )
    }

    // MARK: - Layer 2: Gateway Check

    private func checkGateway() -> (Bool, String?, Double?) {
        guard let gateway = getDefaultGateway() else {
            return (false, nil, nil)
        }

        // Try ICMP ping first
        let (reachable, latency) = pingHostWithLatency(gateway, timeout: pingTimeout)

        if reachable {
            return (true, gateway, latency)
        }

        // Fallback: Try TCP connection to common ports (80, 443, 53)
        // Many routers block ICMP but respond to TCP
        for port in [80, 443, 53] {
            if tcpConnect(host: gateway, port: port, timeout: pingTimeout) {
                return (true, gateway, nil)  // TCP worked but no latency measurement
            }
        }

        return (false, gateway, nil)
    }

    private func getDefaultGateway() -> String? {
        guard let routeInfo = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let routerAddress = routeInfo["Router"] as? String else {
            return nil
        }
        return routerAddress
    }

    // MARK: - Layer 3: Internet Check (Multiple Targets)

    private func checkInternet() -> (Bool, Double?, [String]) {
        var testedTargets: [String] = []
        var bestLatency: Double?

        for target in ispTestTargets {
            testedTargets.append(target)
            let (reachable, latency) = pingHostWithLatency(target, timeout: pingTimeout)

            if reachable {
                if let lat = latency {
                    if bestLatency == nil || lat < bestLatency! {
                        bestLatency = lat
                    }
                }
                return (true, bestLatency, testedTargets)
            }
        }

        // All ICMP tests failed - try TCP as fallback
        // (Some networks block ICMP but allow TCP)
        for target in ispTestTargets {
            if tcpConnect(host: target, port: 53, timeout: pingTimeout) {
                return (true, nil, testedTargets)
            }
        }

        return (false, nil, testedTargets)
    }

    // MARK: - Layer 4: DNS Check (Multiple Domains)

    private func checkDNS() -> (Bool, Double?, [String]) {
        var testedDomains: [String] = []
        var bestLatency: Double?

        for domain in dnsTestDomains {
            testedDomains.append(domain)
            let (resolved, latency) = resolveDNSWithLatency(domain)

            if resolved {
                if let lat = latency {
                    if bestLatency == nil || lat < bestLatency! {
                        bestLatency = lat
                    }
                }
                return (true, bestLatency, testedDomains)
            }
        }

        return (false, nil, testedDomains)
    }

    private func resolveDNSWithLatency(_ domain: String) -> (Bool, Double?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let semaphore = DispatchSemaphore(value: 0)
        var resolved = false

        let host = CFHostCreateWithName(nil, domain as CFString).takeRetainedValue()

        // Timeout handler
        DispatchQueue.global().asyncAfter(deadline: .now() + pingTimeout) {
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

        _ = semaphore.wait(timeout: .now() + pingTimeout + 1.0)
        CFHostCancelInfoResolution(host, .addresses)

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000  // ms
        return (resolved, resolved ? elapsed : nil)
    }

    // MARK: - Layer 5: HTTP / Captive Portal Check

    private func checkHTTP() -> (Bool, Bool, String?) {
        let semaphore = DispatchSemaphore(value: 0)
        var httpWorking = false
        var captiveDetected = false
        var captiveURL: String?

        guard let url = URL(string: captivePortalURL) else {
            return (false, false, nil)
        }

        var request = URLRequest(url: url, timeoutInterval: httpTimeout)
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

            if httpResponse.statusCode == 302 || httpResponse.statusCode == 303 {
                // Redirect = captive portal
                captiveDetected = true
                captiveURL = httpResponse.value(forHTTPHeaderField: "Location")
                httpWorking = false
            } else if httpResponse.statusCode == 200 {
                // Check if it's Apple's success page or a captive portal page
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    if body.contains("<TITLE>Success</TITLE>") || body.contains("Success") {
                        httpWorking = true
                        captiveDetected = false
                    } else {
                        // Got 200 but wrong content = captive portal
                        captiveDetected = true
                        httpWorking = false
                    }
                }
            }
        }.resume()

        _ = semaphore.wait(timeout: .now() + httpTimeout + 1.0)
        session.invalidateAndCancel()

        return (httpWorking, captiveDetected, captiveURL)
    }

    // MARK: - Channel Analysis

    private func analyzeChannels() -> ([NeighboringNetwork], [ChannelAnalysis], Int?) {
        guard let interface = CWWiFiClient.shared().interface() else {
            return ([], [], nil)
        }

        var neighbors: [NeighboringNetwork] = []

        // Scan for networks (this can take a few seconds)
        do {
            let networks = try interface.scanForNetworks(withSSID: nil)

            for network in networks {
                var band = "Unknown"
                var channelNum = 0

                if let channel = network.wlanChannel {
                    channelNum = channel.channelNumber
                    switch channel.channelBand {
                    case .band2GHz: band = "2.4 GHz"
                    case .band5GHz: band = "5 GHz"
                    case .band6GHz: band = "6 GHz"
                    @unknown default: band = "Unknown"
                    }
                }

                var security = "Unknown"
                // Note: CWNetwork doesn't expose security directly in newer APIs
                // We'll mark as "Unknown" for now

                neighbors.append(NeighboringNetwork(
                    ssid: network.ssid ?? "(Hidden)",
                    bssid: network.bssid ?? "",
                    rssi: network.rssiValue,
                    channel: channelNum,
                    channelBand: band,
                    security: security
                ))
            }
        } catch {
            // Scan failed - return empty
            return ([], [], nil)
        }

        // Analyze channels (for 2.4 GHz only - channels 1, 6, 11)
        let currentChannel = interface.wlanChannel()?.channelNumber ?? 0
        let currentBand = interface.wlanChannel()?.channelBand

        var analysis: [ChannelAnalysis] = []
        var recommendedChannel: Int?
        var lowestCongestion = Int.max

        // Analyze 2.4 GHz channels 1, 6, 11
        for channel in [1, 6, 11] {
            let onChannel = neighbors.filter {
                $0.channel == channel && $0.channelBand == "2.4 GHz"
            }

            let adjacent = neighbors.filter {
                $0.channelBand == "2.4 GHz" &&
                abs($0.channel - channel) <= 2 &&
                $0.channel != channel
            }

            let strongest = onChannel.map { $0.rssi }.max() ?? -100

            let congestion: String
            let totalInterference = onChannel.count + adjacent.count
            if totalInterference == 0 {
                congestion = "None"
            } else if totalInterference <= 3 {
                congestion = "Low"
            } else if totalInterference <= 7 {
                congestion = "Medium"
            } else {
                congestion = "High"
            }

            let isRecommended = totalInterference < lowestCongestion
            if isRecommended && currentBand == .band2GHz {
                lowestCongestion = totalInterference
                recommendedChannel = channel
            }

            analysis.append(ChannelAnalysis(
                channel: channel,
                band: "2.4 GHz",
                networksOnChannel: onChannel.count,
                networksOnAdjacentChannels: adjacent.count,
                strongestCompetitorRSSI: strongest,
                congestionLevel: congestion,
                isRecommended: channel == recommendedChannel
            ))
        }

        // If current channel is already the best, no recommendation needed
        if currentChannel == recommendedChannel {
            recommendedChannel = nil
        }

        return (neighbors, analysis, recommendedChannel)
    }

    // MARK: - Issue Analysis

    private func analyzeStatus(_ status: NetworkStatus) -> ([NetworkIssue], [NetworkRecommendation]) {
        var issues: [NetworkIssue] = []
        var recommendations: [NetworkRecommendation] = []

        // Check connectivity issues
        if status.interfaceType == .none {
            issues.append(NetworkIssue(
                severity: .critical,
                title: "No Network Interface",
                description: "Your device is not connected to any network",
                category: .connectivity
            ))
            recommendations.append(NetworkRecommendation(
                priority: 1,
                title: "Connect to a network",
                steps: [
                    "Check if Wi-Fi is enabled in System Settings",
                    "Select a Wi-Fi network to connect to",
                    "Or connect an Ethernet cable"
                ],
                category: .connectivity
            ))
        } else if !status.gatewayReachable {
            issues.append(NetworkIssue(
                severity: .critical,
                title: "Router Unreachable",
                description: "Connected to network but cannot reach your router at \(status.gatewayIP ?? "unknown")",
                category: .connectivity
            ))
            recommendations.append(NetworkRecommendation(
                priority: 1,
                title: "Check your router",
                steps: [
                    "Verify router is powered on",
                    "Check router lights indicate normal operation",
                    "Restart router (unplug for 30 seconds)",
                    "Check cable connections"
                ],
                category: .connectivity
            ))
        } else if !status.internetReachable {
            issues.append(NetworkIssue(
                severity: .critical,
                title: "No Internet Connection",
                description: "Router works but cannot reach the internet",
                category: .connectivity
            ))
            recommendations.append(NetworkRecommendation(
                priority: 1,
                title: "Check internet connection",
                steps: [
                    "Restart your modem (unplug for 30 seconds)",
                    "Check if other devices have internet",
                    "Contact your ISP to check for outages",
                    "Verify your ISP account is active"
                ],
                category: .connectivity
            ))
        } else if status.captivePortalDetected {
            issues.append(NetworkIssue(
                severity: .critical,
                title: "Captive Portal Detected",
                description: "You need to log in to use this network",
                category: .connectivity
            ))
            recommendations.append(NetworkRecommendation(
                priority: 1,
                title: "Complete network login",
                steps: [
                    "Open a web browser",
                    "Navigate to any website",
                    "Complete the login/agreement page",
                    status.captivePortalURL != nil ? "Or go directly to: \(status.captivePortalURL!)" : ""
                ].filter { !$0.isEmpty },
                category: .connectivity
            ))
        } else if !status.dnsWorking {
            issues.append(NetworkIssue(
                severity: .critical,
                title: "DNS Not Working",
                description: "Internet works but cannot resolve domain names",
                category: .connectivity
            ))
            recommendations.append(NetworkRecommendation(
                priority: 1,
                title: "Fix DNS settings",
                steps: [
                    "Try using Cloudflare DNS (1.1.1.1) or Google DNS (8.8.8.8)",
                    "Open System Settings > Network > Advanced > DNS",
                    "Add 1.1.1.1 as a DNS server",
                    "Restart your computer"
                ],
                category: .connectivity
            ))
        }

        // Check Wi-Fi specific issues
        if let wifi = status.wifiInfo {
            // Signal strength
            if wifi.rssi < -80 {
                issues.append(NetworkIssue(
                    severity: .critical,
                    title: "Very Weak Signal",
                    description: "Signal strength is \(wifi.rssi) dBm - connection will be unreliable",
                    category: .wifi
                ))
                recommendations.append(NetworkRecommendation(
                    priority: 2,
                    title: "Improve signal strength",
                    steps: [
                        "Move closer to your router",
                        "Remove obstacles between you and the router",
                        "Consider a Wi-Fi extender or mesh system"
                    ],
                    category: .wifi
                ))
            } else if wifi.rssi < -70 {
                issues.append(NetworkIssue(
                    severity: .warning,
                    title: "Weak Signal",
                    description: "Signal strength is \(wifi.rssi) dBm - may experience slowdowns",
                    category: .wifi
                ))
                recommendations.append(NetworkRecommendation(
                    priority: 3,
                    title: "Consider improving signal",
                    steps: [
                        "Move closer to your router if possible",
                        "Check for interference sources"
                    ],
                    category: .wifi
                ))
            }

            // SNR
            let snr = wifi.snr
            if snr < 10 {
                issues.append(NetworkIssue(
                    severity: .warning,
                    title: "High Interference",
                    description: "Signal-to-noise ratio is \(snr) dB - there may be interference",
                    category: .wifi
                ))
            }

            // Security
            if wifi.security.contains("WEP") || wifi.security.contains("Open") {
                issues.append(NetworkIssue(
                    severity: .warning,
                    title: "Weak Security",
                    description: "Your network uses \(wifi.security) which is not secure",
                    category: .security
                ))
                recommendations.append(NetworkRecommendation(
                    priority: 4,
                    title: "Upgrade network security",
                    steps: [
                        "Access your router settings",
                        "Change security to WPA2 or WPA3",
                        "Update the Wi-Fi password"
                    ],
                    category: .security
                ))
            }

            // Channel congestion
            if let recommended = status.recommendedChannel, wifi.channel != recommended {
                let currentAnalysis = status.channelAnalysis.first { $0.channel == wifi.channel }
                let networksOnChannel = currentAnalysis?.networksOnChannel ?? 0

                if networksOnChannel > 5 {
                    issues.append(NetworkIssue(
                        severity: .warning,
                        title: "Channel Congestion",
                        description: "Channel \(wifi.channel) has \(networksOnChannel) competing networks",
                        category: .channel
                    ))
                    recommendations.append(NetworkRecommendation(
                        priority: 3,
                        title: "Change Wi-Fi channel",
                        steps: [
                            "Access your router settings (usually 192.168.1.1)",
                            "Find wireless/Wi-Fi settings",
                            "Change channel from \(wifi.channel) to \(recommended)",
                            "Save and restart router"
                        ],
                        category: .channel
                    ))
                }
            }

            // 5 GHz recommendation
            if wifi.channelBand == "2.4 GHz" {
                let has5GHz = status.neighboringNetworks.contains {
                    $0.channelBand == "5 GHz" && $0.ssid == wifi.ssid
                }
                if has5GHz {
                    issues.append(NetworkIssue(
                        severity: .info,
                        title: "5 GHz Available",
                        description: "Your router supports 5 GHz which may be faster",
                        category: .performance
                    ))
                    recommendations.append(NetworkRecommendation(
                        priority: 5,
                        title: "Try 5 GHz band",
                        steps: [
                            "Your router has a 5 GHz network available",
                            "Connect to the 5 GHz version for potentially faster speeds",
                            "Note: 5 GHz has shorter range than 2.4 GHz"
                        ],
                        category: .performance
                    ))
                }
            }

            // Speed check
            if wifi.transmitRate < 50 && wifi.transmitRate > 0 {
                issues.append(NetworkIssue(
                    severity: .warning,
                    title: "Slow Connection Speed",
                    description: "Current speed is \(Int(wifi.transmitRate)) Mbps - below typical performance",
                    category: .performance
                ))
            }
        }

        // Sort issues by severity
        issues.sort { $0.severity > $1.severity }
        recommendations.sort { $0.priority < $1.priority }

        return (issues, recommendations)
    }

    // MARK: - Quality Score

    private func calculateQualityScore(_ status: NetworkStatus) -> Int {
        var score = 100

        // Connectivity penalties
        if status.interfaceType == .none { return 0 }
        if !status.gatewayReachable { return 10 }
        if !status.internetReachable { return 20 }
        if status.captivePortalDetected { return 25 }
        if !status.dnsWorking { return 30 }
        if !status.httpWorking { score -= 10 }

        // Latency penalties
        if let latency = status.internetLatency {
            if latency > 100 { score -= 20 }
            else if latency > 50 { score -= 10 }
            else if latency > 30 { score -= 5 }
        }

        // Wi-Fi specific
        if let wifi = status.wifiInfo {
            // Signal strength
            switch wifi.signalQuality {
            case .excellent: break
            case .good: score -= 5
            case .fair: score -= 15
            case .weak: score -= 30
            case .veryWeak: score -= 50
            case .none: score -= 60
            }

            // SNR
            let snr = wifi.snr
            if snr < 15 { score -= 20 }
            else if snr < 25 { score -= 10 }

            // Channel congestion
            if let analysis = status.channelAnalysis.first(where: { $0.channel == wifi.channel }) {
                if analysis.networksOnChannel > 10 { score -= 15 }
                else if analysis.networksOnChannel > 5 { score -= 10 }
                else if analysis.networksOnChannel > 2 { score -= 5 }
            }
        }

        return max(0, min(100, score))
    }

    private func qualityFromScore(_ score: Int) -> ConnectionQuality {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 1..<40: return .poor
        default: return .none
        }
    }

    // MARK: - Network Utilities

    private func pingHostWithLatency(_ host: String, timeout: TimeInterval) -> (Bool, Double?) {
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

    private func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var connected = false

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
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
}
