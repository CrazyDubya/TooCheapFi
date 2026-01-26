import Foundation

// MARK: - Enums

enum InterfaceType: String {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case vpn = "VPN"
    case other = "Other"
    case none = "None"
}

enum ConnectionQuality: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case none = "No Connection"

    var score: Int {
        switch self {
        case .excellent: return 100
        case .good: return 75
        case .fair: return 50
        case .poor: return 25
        case .none: return 0
        }
    }
}

enum SignalQuality: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
    case veryWeak = "Very Weak"
    case none = "No Signal"

    static func from(rssi: Int) -> SignalQuality {
        switch rssi {
        case -50...0: return .excellent
        case -60..<(-50): return .good
        case -70..<(-60): return .fair
        case -80..<(-70): return .weak
        case ..<(-80): return .veryWeak
        default: return .none
        }
    }

    static func from(snr: Int) -> SignalQuality {
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

struct WiFiInfo {
    var ssid: String?
    var bssid: String?
    var rssi: Int                    // Signal strength in dBm
    var noise: Int                   // Noise floor in dBm
    var snr: Int { rssi - noise }    // Signal-to-noise ratio
    var channel: Int
    var channelBand: String          // "2.4 GHz", "5 GHz", "6 GHz"
    var channelWidth: Int            // 20, 40, 80, 160 MHz
    var transmitRate: Double         // Mbps
    var phyMode: String              // "802.11n", "802.11ac", etc.
    var security: String             // "WPA2", "WPA3", etc.
    var signalQuality: SignalQuality

    static var unknown: WiFiInfo {
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

struct NeighboringNetwork {
    var ssid: String
    var bssid: String
    var rssi: Int
    var channel: Int
    var channelBand: String
    var security: String
}

// MARK: - Channel Analysis

struct ChannelAnalysis {
    var channel: Int
    var band: String
    var networksOnChannel: Int
    var networksOnAdjacentChannels: Int
    var strongestCompetitorRSSI: Int
    var congestionLevel: String      // "Low", "Medium", "High"
    var isRecommended: Bool
}

// MARK: - Issue

struct NetworkIssue {
    var severity: IssueSeverity
    var title: String
    var description: String
    var category: IssueCategory
}

enum IssueSeverity: Int, Comparable {
    case critical = 3
    case warning = 2
    case info = 1

    static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum IssueCategory {
    case connectivity
    case wifi
    case channel
    case security
    case performance
}

// MARK: - Recommendation

struct NetworkRecommendation {
    var priority: Int
    var title: String
    var steps: [String]
    var category: IssueCategory
}

// MARK: - Speed Test Result

struct SpeedTestResult {
    var downloadSpeed: Double?       // Mbps
    var uploadSpeed: Double?         // Mbps (future)
    var testTime: Date
    var testServer: String
    var status: SpeedTestStatus

    enum SpeedTestStatus: String {
        case notRun = "Not Run"
        case running = "Testing..."
        case completed = "Completed"
        case failed = "Failed"
    }

    var downloadSpeedDescription: String {
        guard let speed = downloadSpeed else { return "N/A" }
        if speed >= 100 {
            return String(format: "%.0f Mbps", speed)
        } else if speed >= 10 {
            return String(format: "%.1f Mbps", speed)
        } else {
            return String(format: "%.2f Mbps", speed)
        }
    }

    var speedQuality: String {
        guard let speed = downloadSpeed else { return "Unknown" }
        switch speed {
        case 100...: return "Excellent"
        case 50..<100: return "Good"
        case 25..<50: return "Fair"
        case 10..<25: return "Slow"
        default: return "Very Slow"
        }
    }

    static var notRun: SpeedTestResult {
        SpeedTestResult(downloadSpeed: nil, uploadSpeed: nil, testTime: Date(), testServer: "", status: .notRun)
    }
}

// MARK: - Main Network Status

struct NetworkStatus {
    // Interface Layer
    var interfaceType: InterfaceType
    var interfaceName: String?
    var localIP: String?
    var hasIPv6: Bool

    // Wi-Fi Details (only populated if on Wi-Fi)
    var wifiInfo: WiFiInfo?

    // Gateway/Router Layer
    var gatewayReachable: Bool
    var gatewayIP: String?
    var gatewayLatency: Double?      // ms

    // Internet Layer
    var internetReachable: Bool
    var internetLatency: Double?     // ms
    var testedTargets: [String]      // Which IPs were tested

    // DNS Layer
    var dnsWorking: Bool
    var dnsServer: String?
    var dnsLatency: Double?          // ms
    var testedDomains: [String]      // Which domains were tested

    // HTTP Layer (captive portal detection)
    var httpWorking: Bool
    var captivePortalDetected: Bool
    var captivePortalURL: String?

    // Speed Test
    var speedTest: SpeedTestResult

    // Channel Analysis (only if Wi-Fi)
    var neighboringNetworks: [NeighboringNetwork]
    var channelAnalysis: [ChannelAnalysis]        // 2.4 GHz
    var channelAnalysis5GHz: [ChannelAnalysis]    // 5 GHz
    var recommendedChannel: Int?
    var recommendedChannel5GHz: Int?

    // Overall Assessment
    var overallQuality: ConnectionQuality
    var qualityScore: Int            // 0-100
    var issues: [NetworkIssue]
    var recommendations: [NetworkRecommendation]

    // Legacy compatibility
    var wifiConnected: Bool { interfaceType != .none }
    var wifiStatus: String {
        guard let wifi = wifiInfo else {
            return interfaceType == .none ? "Not Connected" : "\(interfaceType.rawValue) Connected"
        }
        return "\(wifi.ssid ?? "Unknown") (\(wifi.signalQuality.rawValue))"
    }

    var routerReachable: Bool { gatewayReachable }
    var routerStatus: String {
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

    var ispReachable: Bool { internetReachable }
    var ispStatus: String {
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

    var dnsStatus: String {
        if dnsWorking {
            if let latency = dnsLatency {
                return "Working (\(Int(latency))ms)"
            }
            return "Working"
        }
        return "Failed"
    }

    var isFullyConnected: Bool {
        interfaceType != .none && gatewayReachable && internetReachable && dnsWorking && httpWorking && !captivePortalDetected
    }

    var diagnoses: [String] {
        issues.map { $0.description }
    }

    var suggestedFixes: [String] {
        recommendations.flatMap { rec in
            [rec.title] + rec.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        }
    }

    // MARK: - Static Constructors

    static var unknown: NetworkStatus {
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
