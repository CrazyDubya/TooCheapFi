import Foundation
import SystemConfiguration
import Network

class NetworkMonitor {
    var onStatusChange: ((NetworkStatus) -> Void)?
    private(set) var currentStatus: NetworkStatus = .unknown
    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.toocheapfi.networkmonitor")
    
    func startMonitoring() {
        // Initial check
        checkStatus()
        
        // Set up periodic checks every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
        
        // Also monitor for network path changes
        pathMonitor.pathUpdateHandler = { [weak self] path in
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
            
            // Check Wi-Fi
            let (wifiConnected, wifiStatus) = self.checkWiFi()
            
            // Check Router (local gateway)
            let (routerReachable, routerStatus) = self.checkRouter()
            
            // Check ISP (internet connectivity)
            let (ispReachable, ispStatus) = self.checkISP()
            
            // Check DNS
            let (dnsWorking, dnsStatus) = self.checkDNS()
            
            // Generate diagnoses and fixes
            let diagnoses = self.generateDiagnoses(
                wifi: wifiConnected,
                router: routerReachable,
                isp: ispReachable,
                dns: dnsWorking
            )
            
            let fixes = self.generateFixes(
                wifi: wifiConnected,
                router: routerReachable,
                isp: ispReachable,
                dns: dnsWorking
            )
            
            let status = NetworkStatus(
                wifiConnected: wifiConnected,
                wifiStatus: wifiStatus,
                routerReachable: routerReachable,
                routerStatus: routerStatus,
                ispReachable: ispReachable,
                ispStatus: ispStatus,
                dnsWorking: dnsWorking,
                dnsStatus: dnsStatus,
                diagnoses: diagnoses,
                suggestedFixes: fixes
            )
            
            DispatchQueue.main.async {
                self.currentStatus = status
                self.onStatusChange?(status)
            }
        }
    }
    
    // MARK: - Network Checks
    
    private func checkWiFi() -> (Bool, String) {
        // Check if network interface is up and has an IP address
        var addrs: UnsafeMutablePointer<ifaddrs>?
        var connected = false
        
        guard getifaddrs(&addrs) == 0 else {
            return (false, "Unable to check")
        }
        
        defer { freeifaddrs(addrs) }
        
        var ptr = addrs
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            
            // Check for common network interfaces (en0, en1, en2 are typical on macOS)
            // Skip loopback (lo0) and bridge interfaces
            if name.hasPrefix("en") && !name.contains("bridge") {
                let flags = Int32(interface.ifa_flags)
                // Check if interface is up and running
                if (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) {
                    if interface.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                        connected = true
                        // Get IP address
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                     &hostname, socklen_t(hostname.count),
                                     nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            let address = String(cString: hostname)
                            return (true, "Connected (\(address))")
                        }
                    }
                }
            }
        }
        
        return (connected, connected ? "Connected" : "Not Connected")
    }
    
    private func checkRouter() -> (Bool, String) {
        // Try to ping the default gateway
        guard let gateway = getDefaultGateway() else {
            return (false, "No gateway found")
        }
        
        let reachable = pingHost(gateway, timeout: 2.0)
        return (reachable, reachable ? "Reachable (\(gateway))" : "Unreachable (\(gateway))")
    }
    
    private func checkISP() -> (Bool, String) {
        // Try to reach a well-known internet host (using IP to bypass DNS)
        // Using Google's public DNS IP
        let testIP = "8.8.8.8"
        let reachable = pingHost(testIP, timeout: 3.0)
        return (reachable, reachable ? "Connected" : "No Internet")
    }
    
    private func checkDNS() -> (Bool, String) {
        // Try to resolve a well-known domain
        let semaphore = DispatchSemaphore(value: 0)
        var resolved = false
        
        let host = CFHostCreateWithName(nil, "www.google.com" as CFString).takeRetainedValue()
        
        // Set timeout using dispatch
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
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
        
        _ = semaphore.wait(timeout: .now() + 3.0)
        
        // Ensure cleanup
        CFHostCancelInfoResolution(host, .addresses)
        
        return (resolved, resolved ? "Working" : "Failed")
    }
    
    // MARK: - Helper Functions
    
    private func getDefaultGateway() -> String? {
        // Get default gateway using SystemConfiguration
        guard let routeInfo = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let routerAddress = routeInfo["Router"] as? String else {
            return nil
        }
        return routerAddress
    }
    
    private func pingHost(_ host: String, timeout: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var isReachable = false
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "1", "-t", "2", host]
        
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
            return false
        }
        
        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        
        if task.isRunning {
            task.terminate()
        }
        
        return isReachable
    }
    
    // MARK: - Diagnosis and Fixes
    
    private func generateDiagnoses(wifi: Bool, router: Bool, isp: Bool, dns: Bool) -> [String] {
        var diagnoses: [String] = []
        
        if !wifi {
            diagnoses.append("Your device is not connected to Wi-Fi")
        } else if !router {
            diagnoses.append("Connected to Wi-Fi but router is unreachable")
        } else if !isp {
            diagnoses.append("Router works but no internet from ISP")
        } else if !dns {
            diagnoses.append("Internet works but DNS resolution is failing")
        }
        
        return diagnoses
    }
    
    private func generateFixes(wifi: Bool, router: Bool, isp: Bool, dns: Bool) -> [String] {
        var fixes: [String] = []
        
        if !wifi {
            fixes.append("1. Check if Wi-Fi is enabled in System Settings")
            fixes.append("2. Select a Wi-Fi network to connect to")
            fixes.append("3. Check if Airplane Mode is off")
        } else if !router {
            fixes.append("1. Check if router is powered on")
            fixes.append("2. Verify router lights indicate normal operation")
            fixes.append("3. Try restarting your router (unplug for 30 sec)")
            fixes.append("4. Check Ethernet cable connections")
        } else if !isp {
            fixes.append("1. Restart your modem (unplug for 30 sec)")
            fixes.append("2. Check if other devices have internet")
            fixes.append("3. Contact your ISP to check for outages")
            fixes.append("4. Check if your ISP bill is paid")
        } else if !dns {
            fixes.append("1. Try using Google DNS (8.8.8.8, 8.8.4.4)")
            fixes.append("2. Open System Settings > Network > Advanced")
            fixes.append("3. Go to DNS tab and add 8.8.8.8")
            fixes.append("4. Restart your computer")
        }
        
        return fixes
    }
}
