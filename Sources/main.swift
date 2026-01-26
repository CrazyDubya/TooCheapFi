import Cocoa
import SystemConfiguration
import Network

@main
class TooCheapFiApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var networkMonitor: NetworkMonitor!
    
    static func main() {
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
        
        // Title
        let titleItem = NSMenuItem(title: "TooCheapFi - Network Monitor", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Overall status
        let statusText = status.isFullyConnected ? "✅ All Systems Operational" : "⚠️ Connection Issues Detected"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        
        // Wi-Fi Status
        let wifiStatus = status.wifiConnected ? "✅" : "❌"
        menu.addItem(createMenuItem("\(wifiStatus) Wi-Fi: \(status.wifiStatus)"))
        
        // Router Status
        let routerStatus = status.routerReachable ? "✅" : "❌"
        menu.addItem(createMenuItem("\(routerStatus) Router: \(status.routerStatus)"))
        
        // ISP Status
        let ispStatus = status.ispReachable ? "✅" : "❌"
        menu.addItem(createMenuItem("\(ispStatus) ISP/Internet: \(status.ispStatus)"))
        
        // DNS Status
        let dnsStatus = status.dnsWorking ? "✅" : "❌"
        menu.addItem(createMenuItem("\(dnsStatus) DNS: \(status.dnsStatus)"))
        
        menu.addItem(NSMenuItem.separator())
        
        // Diagnostic information
        if !status.isFullyConnected {
            let diagnosticItem = NSMenuItem(title: "🔍 Diagnosis:", action: nil, keyEquivalent: "")
            diagnosticItem.isEnabled = false
            menu.addItem(diagnosticItem)
            
            for diagnosis in status.diagnoses {
                let diagItem = NSMenuItem(title: "   \(diagnosis)", action: nil, keyEquivalent: "")
                diagItem.isEnabled = false
                menu.addItem(diagItem)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // Fix suggestions
            let fixItem = NSMenuItem(title: "💡 Suggested Fixes:", action: nil, keyEquivalent: "")
            fixItem.isEnabled = false
            menu.addItem(fixItem)
            
            for fix in status.suggestedFixes {
                let fixSuggestion = NSMenuItem(title: "   \(fix)", action: nil, keyEquivalent: "")
                fixSuggestion.isEnabled = false
                menu.addItem(fixSuggestion)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Update status bar icon
        if let button = statusItem.button {
            let iconName = status.isFullyConnected ? "wifi.circle" : "wifi.exclamationmark"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Network Status")
            button.image?.isTemplate = true
        }
        
        // Refresh option
        menu.addItem(NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "r"))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    private func createMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
    
    @objc func refreshStatus() {
        networkMonitor.checkStatus()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
