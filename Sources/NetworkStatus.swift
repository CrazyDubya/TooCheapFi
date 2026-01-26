import Foundation

// MARK: - Enums

public enum InterfaceType: String {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case vpn = "VPN"
    case other = "Other"
    case none = "None"
}

public enum ConnectionQuality: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case none = "No Connection"

    public var score: Int {
        switch self {
        case .excellent: return 100
        case .good: return 75
        case .fair: return 50
        case .poor: return 25
        case .none: return 0
        }
    }
}

public enum SignalQuality: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
    case veryWeak = "Very Weak"
    case none = "No Signal"

    public static func from(rssi: Int) -> SignalQuality {
        switch rssi {
        case -50...0: return .excellent
        case -60..<(-50): return .good
        case -70..<(-60): return .fair
        case -80..<(-70): return .weak
        case ..<(-80): return .veryWeak
        default: return .none
        }
    }

    public static func from(snr: Int) -> SignalQuality {
        switch snr {
        case 40...: return .excellent
        case 25..<40: return .good
        case 15..<25: return .fair
        case 10..<15: return .weak
        default: return .veryWeak
        }
    }
}

// MARK: - Wi-Fi Info

public struct WiFiInfo {
    public var ssid: String?
    public var bssid: String?
    public var rssi: Int                    // Signal strength in dBm
    public var noise: Int                   // Noise floor in dBm
    public var snr: Int { rssi - noise }    // Signal-to-noise ratio
    public var channel: Int
    public var channelBand: String          // "2.4 GHz", "5 GHz", "6 GHz"
    public var channelWidth: Int            // 20, 40, 80, 160 MHz
    public var transmitRate: Double         // Mbps
    public var phyMode: String              // "802.11n", "802.11ac", etc.
    public var security: String             // "WPA2", "WPA3", etc.
    public var signalQuality: SignalQuality

    public static var unknown: WiFiInfo {
        WiFiInfo(
            ssid: nil,
            bssid: nil,
            rssi: -100,
            noise: -100,
            channel: 0,
            channelBand: "Unknown",
            channelWidth: 0,
            transmitRate: 0,
            phyMode: "Unknown",
            security: "Unknown",
            signalQuality: .none
        )
    }
}

// MARK: - Neighboring Network

public struct NeighboringNetwork {
    public var ssid: String
    public var bssid: String
    public var rssi: Int
    public var channel: Int
    public var channelBand: String
    public var security: String
}

// MARK: - Channel Analysis

public struct ChannelAnalysis {
    public var channel: Int
    public var band: String
    public var networksOnChannel: Int
    public var networksOnAdjacentChannels: Int
    public var strongestCompetitorRSSI: Int
    public var congestionLevel: String      // "Low", "Medium", "High"
    public var isRecommended: Bool
}

// MARK: - Issue

public struct NetworkIssue {
    public var severity: IssueSeverity
    public var title: String
    public var description: String
    public var category: IssueCategory
}

public enum IssueSeverity: Int, Comparable {
    case critical = 3
    case warning = 2
    case info = 1

    public static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum IssueCategory {
    case connectivity
    case wifi
    case channel
    case security
    case performance
}

// MARK: - Recommendation

public struct NetworkRecommendation {
    public var priority: Int
    public var title: String
    public var steps: [String]
    public var category: IssueCategory
}

// MARK: - Speed Test Result

public struct SpeedTestResult {
    public var downloadSpeed: Double?       // Mbps
    public var uploadSpeed: Double?         // Mbps (future)
    public var testTime: Date
    public var testServer: String
    public var status: SpeedTestStatus

    public enum SpeedTestStatus: String {
        case notRun = "Not Run"
        case running = "Testing..."
        case completed = "Completed"
        case failed = "Failed"
    }

    public var downloadSpeedDescription: String {
        guard let speed = downloadSpeed else { return "N/A" }
        if speed >= 100 {
            return String(format: "%.0f Mbps", speed)
        } else if speed >= 10 {
            return String(format: "%.1f Mbps", speed)
        } else {
            return String(format: "%.2f Mbps", speed)
        }
    }

    public var speedQuality: String {
        guard let speed = downloadSpeed else { return "Unknown" }
        switch speed {
        case 100...: return "Excellent"
        case 50..<100: return "Good"
        case 25..<50: return "Fair"
        case 10..<25: return "Slow"
        default: return "Very Slow"
        }
    }

    public static var notRun: SpeedTestResult {
        SpeedTestResult(downloadSpeed: nil, uploadSpeed: nil, testTime: Date(), testServer: "", status: .notRun)
    }
}

// MARK: - Main Network Status

public struct NetworkStatus {
    // Interface Layer
    public var interfaceType: InterfaceType
    public var interfaceName: String?
    public var localIP: String?
    public var hasIPv6: Bool

    // Wi-Fi Details (only populated if on Wi-Fi)
    public var wifiInfo: WiFiInfo?

    // Gateway/Router Layer
    public var gatewayReachable: Bool
    public var gatewayIP: String?
    public var gatewayLatency: Double?      // ms

    // Internet Layer
    public var internetReachable: Bool
    public var internetLatency: Double?     // ms
    public var testedTargets: [String]      // Which IPs were tested

    // DNS Layer
    public var dnsWorking: Bool
    public var dnsServer: String?
    public var dnsLatency: Double?          // ms
    public var testedDomains: [String]      // Which domains were tested

    // HTTP Layer (captive portal detection)
    public var httpWorking: Bool
    public var captivePortalDetected: Bool
    public var captivePortalURL: String?

    // Speed Test
    public var speedTest: SpeedTestResult

    // Channel Analysis (only if Wi-Fi)
    public var neighboringNetworks: [NeighboringNetwork]
    public var channelAnalysis: [ChannelAnalysis]        // 2.4 GHz
    public var channelAnalysis5GHz: [ChannelAnalysis]    // 5 GHz
    public var recommendedChannel: Int?
    public var recommendedChannel5GHz: Int?

    // Overall Assessment
    public var overallQuality: ConnectionQuality
    public var qualityScore: Int            // 0-100
    public var issues: [NetworkIssue]
    public var recommendations: [NetworkRecommendation]

    // Legacy compatibility
    public var wifiConnected: Bool { interfaceType != .none }
    public var wifiStatus: String {
        guard let wifi = wifiInfo else {
            return interfaceType == .none ? "Not Connected" : "\(interfaceType.rawValue) Connected"
        }
        return "\(wifi.ssid ?? "Unknown") (\(wifi.signalQuality.rawValue))"
    }

    public var routerReachable: Bool { gatewayReachable }
    public var routerStatus: String {
        if let ip = gatewayIP {
            if gatewayReachable {
                if let latency = gatewayLatency {
                    return "Reachable (\(ip), \(Int(latency))ms)"
                }
                return "Reachable (\(ip))"
            }
            return "Unreachable (\(ip))"
        }
        return "No Gateway"
    }

    public var ispReachable: Bool { internetReachable }
    public var ispStatus: String {
        if internetReachable {
            if let latency = internetLatency {
                return "Connected (\(Int(latency))ms)"
            }
            return "Connected"
        }
        if captivePortalDetected {
            return "Captive Portal (login required)"
        }
        return "No Internet"
    }

    public var dnsStatus: String {
        if dnsWorking {
            if let latency = dnsLatency {
                return "Working (\(Int(latency))ms)"
            }
            return "Working"
        }
        return "Failed"
    }

    public var isFullyConnected: Bool {
        interfaceType != .none && gatewayReachable && internetReachable && dnsWorking && httpWorking && !captivePortalDetected
    }

    public var diagnoses: [String] {
        issues.map { $0.description }
    }

    public var suggestedFixes: [String] {
        recommendations.flatMap { rec in
            [rec.title] + rec.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        }
    }

    // MARK: - Static Constructors

    public static var unknown: NetworkStatus {
        NetworkStatus(
            interfaceType: .none,
            interfaceName: nil,
            localIP: nil,
            hasIPv6: false,
            wifiInfo: nil,
            gatewayReachable: false,
            gatewayIP: nil,
            gatewayLatency: nil,
            internetReachable: false,
            internetLatency: nil,
            testedTargets: [],
            dnsWorking: false,
            dnsServer: nil,
            dnsLatency: nil,
            testedDomains: [],
            httpWorking: false,
            captivePortalDetected: false,
            captivePortalURL: nil,
            speedTest: .notRun,
            neighboringNetworks: [],
            channelAnalysis: [],
            channelAnalysis5GHz: [],
            recommendedChannel: nil,
            recommendedChannel5GHz: nil,
            overallQuality: .none,
            qualityScore: 0,
            issues: [],
            recommendations: []
        )
    }
}
