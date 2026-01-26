import Cocoa
import SystemConfiguration
import Network

@main
class TooCheapFiApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var networkMonitor: NetworkMonitor!

    private var currentStatus: NetworkStatus {
        networkMonitor?.currentStatus ?? .unknown
    }

    static func main() {
        // Handle command line arguments
        let args = CommandLine.arguments

        if args.contains("--version") || args.contains("-v") {
            print("TooCheapFi 1.0.0")
            exit(0)
        }

        if args.contains("--help") || args.contains("-h") {
            print("""
            TooCheapFi - Network Connectivity Monitor with Wi-Fi Diagnostics

            Usage: TooCheapFi [options]

            Options:
              --version, -v    Print version and exit
              --help, -h       Print this help message

            TooCheapFi runs in your menu bar and monitors network connectivity.
            It provides comprehensive diagnostics including:
              - Multi-layer connectivity testing (Interface, Gateway, Internet, DNS, HTTP)
              - Wi-Fi signal strength and quality analysis
              - Channel congestion detection and recommendations
              - Captive portal detection
              - Latency measurements

            For more information: https://github.com/CrazyDubya/TooCheapFi
            """)
            exit(0)
        }

        let app = NSApplication.shared
        let delegate = TooCheapFiApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wifi.circle", accessibilityDescription: "Network Status")
            button.image?.isTemplate = true
        }

        // Create menu
        menu = NSMenu()
        statusItem.menu = menu

        // Request notification permissions
        NotificationManager.shared.requestPermission { granted in
            print("Notifications \(granted ? "enabled" : "disabled")")
        }

        // Initialize network monitor
        networkMonitor = NetworkMonitor()
        networkMonitor.onStatusChange = { [weak self] status in
            self?.updateMenu(with: status)
        }

        // Start monitoring
        networkMonitor.startMonitoring()

        // Initial menu update
        updateMenu(with: networkMonitor.currentStatus)
    }

    func updateMenu(with status: NetworkStatus) {
        menu.removeAllItems()

        // Header with quality score
        let qualityEmoji = qualityEmoji(for: status.overallQuality)
        let headerTitle = "TooCheapFi - \(qualityEmoji) \(status.overallQuality.rawValue) (\(status.qualityScore)/100)"
        let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // Connection type
        let interfaceEmoji = status.interfaceType == .none ? "❌" : "📶"
        let interfaceTitle = "\(interfaceEmoji) \(status.interfaceType.rawValue)"
        if let ip = status.localIP {
            menu.addItem(createMenuItem("\(interfaceTitle): \(ip)"))
        } else {
            menu.addItem(createMenuItem("\(interfaceTitle): Not Connected"))
        }

        // Wi-Fi Details (if on Wi-Fi)
        if let wifi = status.wifiInfo {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(createSectionHeader("Wi-Fi Details"))

            // SSID and signal
            let signalEmoji = signalEmoji(for: wifi.signalQuality)
            menu.addItem(createMenuItem("   \(signalEmoji) \(wifi.ssid ?? "Unknown") (\(wifi.signalQuality.rawValue))"))

            // Signal metrics
            menu.addItem(createMenuItem("   Signal: \(wifi.rssi) dBm | Noise: \(wifi.noise) dBm | SNR: \(wifi.snr) dB"))

            // Channel and band
            menu.addItem(createMenuItem("   Channel: \(wifi.channel) (\(wifi.channelBand), \(wifi.channelWidth) MHz)"))

            // Speed and standard
            menu.addItem(createMenuItem("   Speed: \(Int(wifi.transmitRate)) Mbps | \(wifi.phyMode)"))

            // Security
            let securityEmoji = wifi.security.contains("WPA3") ? "🔒" : (wifi.security.contains("WPA2") ? "🔐" : "⚠️")
            menu.addItem(createMenuItem("   \(securityEmoji) Security: \(wifi.security)"))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(createSectionHeader("Connectivity"))

        // Gateway/Router
        let gatewayEmoji = status.gatewayReachable ? "✅" : "❌"
        var gatewayText = "\(gatewayEmoji) Router: "
        if let ip = status.gatewayIP {
            gatewayText += status.gatewayReachable ? "Reachable (\(ip))" : "Unreachable (\(ip))"
            if let latency = status.gatewayLatency {
                gatewayText += " - \(Int(latency))ms"
            }
        } else {
            gatewayText += "No Gateway"
        }
        menu.addItem(createMenuItem(gatewayText))

        // Internet
        let internetEmoji = status.internetReachable ? "✅" : "❌"
        var internetText = "\(internetEmoji) Internet: "
        if status.captivePortalDetected {
            internetText += "Captive Portal (login required)"
        } else if status.internetReachable {
            internetText += "Connected"
            if let latency = status.internetLatency {
                internetText += " - \(Int(latency))ms"
            }
        } else {
            internetText += "No Connection"
        }
        menu.addItem(createMenuItem(internetText))

        // DNS
        let dnsEmoji = status.dnsWorking ? "✅" : "❌"
        var dnsText = "\(dnsEmoji) DNS: "
        if status.dnsWorking {
            dnsText += "Working"
            if let latency = status.dnsLatency {
                dnsText += " - \(Int(latency))ms"
            }
        } else {
            dnsText += "Failed"
        }
        menu.addItem(createMenuItem(dnsText))

        // HTTP
        let httpEmoji = status.httpWorking ? "✅" : (status.captivePortalDetected ? "🔐" : "❌")
        let httpText = "\(httpEmoji) HTTP: \(status.httpWorking ? "Working" : (status.captivePortalDetected ? "Captive Portal" : "Failed"))"
        menu.addItem(createMenuItem(httpText))

        // Speed Test Result
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createSectionHeader("Speed Test"))

        switch status.speedTest.status {
        case .notRun:
            menu.addItem(createMenuItem("   No speed test run yet"))
        case .running:
            menu.addItem(createMenuItem("   ⏳ Testing download speed..."))
        case .completed:
            let speedEmoji: String
            switch status.speedTest.speedQuality {
            case "Excellent": speedEmoji = "🚀"
            case "Good": speedEmoji = "✅"
            case "Fair": speedEmoji = "🟡"
            case "Slow": speedEmoji = "🟠"
            default: speedEmoji = "🔴"
            }
            menu.addItem(createMenuItem("   \(speedEmoji) Download: \(status.speedTest.downloadSpeedDescription) (\(status.speedTest.speedQuality))"))
        case .failed:
            menu.addItem(createMenuItem("   ❌ Speed test failed"))
        }

        // Channel Analysis (if on Wi-Fi and we have data)
        if !status.channelAnalysis.isEmpty {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(createSectionHeader("Channel Analysis (2.4 GHz)"))

            for analysis in status.channelAnalysis {
                let congestionEmoji: String
                switch analysis.congestionLevel {
                case "None": congestionEmoji = "🟢"
                case "Low": congestionEmoji = "🟡"
                case "Medium": congestionEmoji = "🟠"
                default: congestionEmoji = "🔴"
                }

                var channelText = "   \(congestionEmoji) Ch \(analysis.channel): \(analysis.networksOnChannel) networks"
                if analysis.isRecommended {
                    channelText += " ⭐"
                }
                if let wifi = status.wifiInfo, wifi.channel == analysis.channel && wifi.channelBand == "2.4 GHz" {
                    channelText += " (current)"
                }
                menu.addItem(createMenuItem(channelText))
            }

            if let recommended = status.recommendedChannel {
                menu.addItem(createMenuItem("   💡 Consider switching to channel \(recommended)"))
            }
        }

        // 5 GHz Channel Analysis
        if !status.channelAnalysis5GHz.isEmpty {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(createSectionHeader("Channel Analysis (5 GHz)"))

            // Only show channels that have networks or are recommended
            let relevantChannels = status.channelAnalysis5GHz.filter {
                $0.networksOnChannel > 0 || $0.isRecommended
            }

            if relevantChannels.isEmpty {
                menu.addItem(createMenuItem("   🟢 All channels clear"))
            } else {
                for analysis in relevantChannels.prefix(5) {  // Limit display
                    let congestionEmoji: String
                    switch analysis.congestionLevel {
                    case "None": congestionEmoji = "🟢"
                    case "Low": congestionEmoji = "🟡"
                    case "Medium": congestionEmoji = "🟠"
                    default: congestionEmoji = "🔴"
                    }

                    var channelText = "   \(congestionEmoji) Ch \(analysis.channel): \(analysis.networksOnChannel) networks"
                    if analysis.isRecommended {
                        channelText += " ⭐"
                    }
                    if let wifi = status.wifiInfo, wifi.channel == analysis.channel && wifi.channelBand == "5 GHz" {
                        channelText += " (current)"
                    }
                    menu.addItem(createMenuItem(channelText))
                }
            }

            if let recommended = status.recommendedChannel5GHz {
                menu.addItem(createMenuItem("   💡 Consider switching to channel \(recommended)"))
            }
        }

        // Issues and Recommendations
        if !status.issues.isEmpty {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(createSectionHeader("Issues Detected"))

            for issue in status.issues.prefix(5) {  // Limit to top 5 issues
                let severityEmoji: String
                switch issue.severity {
                case .critical: severityEmoji = "🔴"
                case .warning: severityEmoji = "🟡"
                case .info: severityEmoji = "🔵"
                }
                menu.addItem(createMenuItem("   \(severityEmoji) \(issue.title)"))
            }
        }

        if !status.recommendations.isEmpty {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(createSectionHeader("Recommendations"))

            for rec in status.recommendations.prefix(3) {  // Limit to top 3 recommendations
                menu.addItem(createMenuItem("   💡 \(rec.title)"))
                for step in rec.steps.prefix(2) {  // Show first 2 steps
                    menu.addItem(createMenuItem("      • \(step)"))
                }
            }
        }

        // Update status bar icon
        updateStatusBarIcon(for: status)

        menu.addItem(NSMenuItem.separator())

        // Actions
        let refreshItem = NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let speedTestItem = NSMenuItem(title: "Run Speed Test", action: #selector(runSpeedTest), keyEquivalent: "s")
        speedTestItem.target = self
        if status.speedTest.status == .running {
            speedTestItem.isEnabled = false
            speedTestItem.title = "Speed Test Running..."
        }
        menu.addItem(speedTestItem)

        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsMenu = NSMenu()

        let notificationItem = NSMenuItem(
            title: NotificationManager.shared.isEnabled ? "✓ Notifications Enabled" : "  Notifications Disabled",
            action: #selector(toggleNotifications),
            keyEquivalent: ""
        )
        notificationItem.target = self
        settingsMenu.addItem(notificationItem)

        let settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsMenuItem.submenu = settingsMenu
        menu.addItem(settingsMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func createMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func createSectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func qualityEmoji(for quality: ConnectionQuality) -> String {
        switch quality {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .fair: return "🟠"
        case .poor: return "🔴"
        case .none: return "⚫"
        }
    }

    private func signalEmoji(for quality: SignalQuality) -> String {
        switch quality {
        case .excellent: return "📶"
        case .good: return "📶"
        case .fair: return "📶"
        case .weak: return "📉"
        case .veryWeak: return "📉"
        case .none: return "❌"
        }
    }

    private func updateStatusBarIcon(for status: NetworkStatus) {
        guard let button = statusItem.button else { return }

        let iconName: String
        switch status.overallQuality {
        case .excellent, .good:
            iconName = "wifi.circle"
        case .fair:
            iconName = "wifi.circle"
        case .poor:
            iconName = "wifi.exclamationmark"
        case .none:
            iconName = "wifi.slash"
        }

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Network Status")
        button.image?.isTemplate = true
    }

    @objc func refreshStatus() {
        networkMonitor.checkStatus()
    }

    @objc func runSpeedTest() {
        networkMonitor.runSpeedTest { [weak self] result in
            // Menu will be updated automatically via onStatusChange
            print("Speed test completed: \(result.downloadSpeedDescription)")
        }
    }

    @objc func toggleNotifications() {
        let currentState = NotificationManager.shared.isEnabled
        if currentState {
            NotificationManager.shared.setEnabled(false)
        } else {
            // Request permission if enabling
            NotificationManager.shared.requestPermission { granted in
                NotificationManager.shared.setEnabled(granted)
            }
        }
        // Refresh menu to show updated state
        updateMenu(with: currentStatus)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
