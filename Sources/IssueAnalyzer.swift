import Foundation

/// Analyzes network status to identify issues and generate recommendations
struct IssueAnalyzer {

    // MARK: - Analysis Result

    struct AnalysisResult {
        let issues: [NetworkIssue]
        let recommendations: [NetworkRecommendation]
        let qualityScore: Int
        let overallQuality: ConnectionQuality
    }

    // MARK: - Main Analysis

    /// Analyzes the network status and returns issues, recommendations, and quality score
    func analyze(_ status: NetworkStatus) -> AnalysisResult {
        var issues: [NetworkIssue] = []
        var recommendations: [NetworkRecommendation] = []

        // Analyze connectivity issues
        analyzeConnectivity(status, issues: &issues, recommendations: &recommendations)

        // Analyze Wi-Fi specific issues
        if let wifi = status.wifiInfo {
            analyzeWiFi(wifi, status: status, issues: &issues, recommendations: &recommendations)
        }

        // Sort by priority
        issues.sort { $0.severity > $1.severity }
        recommendations.sort { $0.priority < $1.priority }

        // Calculate quality
        let score = calculateQualityScore(status)
        let quality = qualityFromScore(score)

        return AnalysisResult(
            issues: issues,
            recommendations: recommendations,
            qualityScore: score,
            overallQuality: quality
        )
    }

    // MARK: - Connectivity Analysis

    private func analyzeConnectivity(
        _ status: NetworkStatus,
        issues: inout [NetworkIssue],
        recommendations: inout [NetworkRecommendation]
    ) {
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
            return
        }

        if !status.gatewayReachable {
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
            return
        }

        if !status.internetReachable {
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
            return
        }

        if status.captivePortalDetected {
            var steps = [
                "Open a web browser",
                "Navigate to any website",
                "Complete the login/agreement page"
            ]
            if let portalURL = status.captivePortalURL {
                steps.append("Or go directly to: \(portalURL)")
            }

            issues.append(NetworkIssue(
                severity: .critical,
                title: "Captive Portal Detected",
                description: "You need to log in to use this network",
                category: .connectivity
            ))
            recommendations.append(NetworkRecommendation(
                priority: 1,
                title: "Complete network login",
                steps: steps,
                category: .connectivity
            ))
            return
        }

        if !status.dnsWorking {
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
    }

    // MARK: - Wi-Fi Analysis

    private func analyzeWiFi(
        _ wifi: WiFiInfo,
        status: NetworkStatus,
        issues: inout [NetworkIssue],
        recommendations: inout [NetworkRecommendation]
    ) {
        analyzeSignalStrength(wifi, issues: &issues, recommendations: &recommendations)
        analyzeSNR(wifi, issues: &issues)
        analyzeSecurity(wifi, issues: &issues, recommendations: &recommendations)
        analyzeChannelCongestion(wifi, status: status, issues: &issues, recommendations: &recommendations)
        analyze5GHzAvailability(wifi, status: status, issues: &issues, recommendations: &recommendations)
        analyzeSpeed(wifi, issues: &issues)
    }

    private func analyzeSignalStrength(
        _ wifi: WiFiInfo,
        issues: inout [NetworkIssue],
        recommendations: inout [NetworkRecommendation]
    ) {
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
    }

    private func analyzeSNR(_ wifi: WiFiInfo, issues: inout [NetworkIssue]) {
        let snr = wifi.snr
        if snr < 10 {
            issues.append(NetworkIssue(
                severity: .warning,
                title: "High Interference",
                description: "Signal-to-noise ratio is \(snr) dB - there may be interference",
                category: .wifi
            ))
        }
    }

    private func analyzeSecurity(
        _ wifi: WiFiInfo,
        issues: inout [NetworkIssue],
        recommendations: inout [NetworkRecommendation]
    ) {
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
    }

    private func analyzeChannelCongestion(
        _ wifi: WiFiInfo,
        status: NetworkStatus,
        issues: inout [NetworkIssue],
        recommendations: inout [NetworkRecommendation]
    ) {
        guard let recommended = status.recommendedChannel, wifi.channel != recommended else {
            return
        }

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

    private func analyze5GHzAvailability(
        _ wifi: WiFiInfo,
        status: NetworkStatus,
        issues: inout [NetworkIssue],
        recommendations: inout [NetworkRecommendation]
    ) {
        guard wifi.channelBand == "2.4 GHz" else { return }

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

    private func analyzeSpeed(_ wifi: WiFiInfo, issues: inout [NetworkIssue]) {
        if wifi.transmitRate < 50 && wifi.transmitRate > 0 {
            issues.append(NetworkIssue(
                severity: .warning,
                title: "Slow Connection Speed",
                description: "Current speed is \(Int(wifi.transmitRate)) Mbps - below typical performance",
                category: .performance
            ))
        }
    }

    // MARK: - Quality Score

    private func calculateQualityScore(_ status: NetworkStatus) -> Int {
        var score = 100

        // Connectivity penalties (early returns for critical failures)
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

        // Wi-Fi specific penalties
        if let wifi = status.wifiInfo {
            score -= signalPenalty(wifi.signalQuality)
            score -= snrPenalty(wifi.snr)
            score -= congestionPenalty(wifi.channel, analysis: status.channelAnalysis)
        }

        return max(0, min(100, score))
    }

    private func signalPenalty(_ quality: SignalQuality) -> Int {
        switch quality {
        case .excellent: return 0
        case .good: return 5
        case .fair: return 15
        case .weak: return 30
        case .veryWeak: return 50
        case .none: return 60
        }
    }

    private func snrPenalty(_ snr: Int) -> Int {
        if snr < 15 { return 20 }
        else if snr < 25 { return 10 }
        return 0
    }

    private func congestionPenalty(_ channel: Int, analysis: [ChannelAnalysis]) -> Int {
        guard let channelAnalysis = analysis.first(where: { $0.channel == channel }) else {
            return 0
        }
        if channelAnalysis.networksOnChannel > 10 { return 15 }
        else if channelAnalysis.networksOnChannel > 5 { return 10 }
        else if channelAnalysis.networksOnChannel > 2 { return 5 }
        return 0
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
}
