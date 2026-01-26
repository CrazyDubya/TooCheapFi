import Foundation

/// Centralized constants for the application
public enum AppConstants {
    /// App version - single source of truth
    public static let version = "1.6.0"

    /// Bundle identifier
    public static let bundleIdentifier = "com.toocheapfi"

    /// App name
    public static let appName = "TooCheapFi"

    /// Full version string for display
    public static var versionString: String {
        "\(appName) \(version)"
    }

    // MARK: - Network Targets

    /// URL for captive portal detection
    public static let captivePortalURL = "http://captive.apple.com/hotspot-detect.html"

    /// Expected response from captive portal check
    public static let captivePortalExpectedResponse = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"

    /// Base URL for speed test
    public static let speedTestBaseURL = "https://speed.cloudflare.com/__down?bytes="

    /// Default ISP test targets
    public static let defaultISPTargets = ["8.8.8.8", "1.1.1.1", "208.67.222.222"]

    /// Default DNS test domains
    public static let defaultDNSTestDomains = ["apple.com", "cloudflare.com", "microsoft.com"]

    // MARK: - Signal Drop Threshold

    /// Minimum RSSI drop (in dB) to trigger signal drop notification
    public static let signalDropThreshold = 10

    // MARK: - Display Limits

    /// Maximum number of channels to display in menu
    public static let maxDisplayChannels = 5

    /// Maximum number of issues to display
    public static let maxDisplayIssues = 5

    /// Maximum number of recommendations to display
    public static let maxDisplayRecommendations = 3

    /// Maximum recommendation steps to show
    public static let maxRecommendationSteps = 2
}
