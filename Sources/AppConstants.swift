import Foundation

/// Centralized constants for the application
enum AppConstants {
    /// App version - single source of truth
    static let version = "1.5.0"

    /// Bundle identifier
    static let bundleIdentifier = "com.toocheapfi"

    /// App name
    static let appName = "TooCheapFi"

    /// Full version string for display
    static var versionString: String {
        "\(appName) \(version)"
    }

    // MARK: - Network Targets

    /// URL for captive portal detection
    static let captivePortalURL = "http://captive.apple.com/hotspot-detect.html"

    /// Expected response from captive portal check
    static let captivePortalExpectedResponse = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"

    /// Base URL for speed test
    static let speedTestBaseURL = "https://speed.cloudflare.com/__down?bytes="

    /// Default ISP test targets
    static let defaultISPTargets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]

    /// Default DNS test domains
    static let defaultDNSTestDomains = ["apple.com", "cloudflare.com", "microsoft.com"]

    // MARK: - Signal Drop Threshold

    /// Minimum RSSI drop (in dB) to trigger signal drop notification
    static let signalDropThreshold = 10

    // MARK: - Display Limits

    /// Maximum number of channels to display in menu
    static let maxDisplayChannels = 5

    /// Maximum number of issues to display
    static let maxDisplayIssues = 5

    /// Maximum number of recommendations to display
    static let maxDisplayRecommendations = 3

    /// Maximum recommendation steps to show
    static let maxRecommendationSteps = 2
}
