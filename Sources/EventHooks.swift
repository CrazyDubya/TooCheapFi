import Foundation

// MARK: - Event Observer Protocol

/// Protocol for receiving network status events
/// All methods have default empty implementations, making them optional
protocol NetworkEventObserver: AnyObject {
    /// Called when network status changes
    func onStatusChanged(from oldStatus: NetworkStatus?, to newStatus: NetworkStatus)

    /// Called when an outage starts
    func onOutageStarted(layer: String, time: Date)

    /// Called when an outage ends
    func onOutageEnded(layer: String, duration: TimeInterval)

    /// Called when connection quality changes
    func onQualityChanged(from oldQuality: ConnectionQuality, to newQuality: ConnectionQuality)

    /// Called when a speed test completes
    func onSpeedTestCompleted(result: SpeedTestResult)

    /// Called when signal strength drops significantly
    func onSignalDrop(from oldRSSI: Int, to newRSSI: Int)
}

// Default implementations (all optional)
extension NetworkEventObserver {
    func onStatusChanged(from oldStatus: NetworkStatus?, to newStatus: NetworkStatus) {}
    func onOutageStarted(layer: String, time: Date) {}
    func onOutageEnded(layer: String, duration: TimeInterval) {}
    func onQualityChanged(from oldQuality: ConnectionQuality, to newQuality: ConnectionQuality) {}
    func onSpeedTestCompleted(result: SpeedTestResult) {}
    func onSignalDrop(from oldRSSI: Int, to newRSSI: Int) {}
}

// MARK: - Event Hook Manager

/// Manages network event observers and dispatches events
final class EventHookManager {
    static let shared = EventHookManager()

    private var observers = NSHashTable<AnyObject>.weakObjects()
    private let queue = DispatchQueue(label: "com.toocheapfi.hooks", qos: .utility)

    private init() {}

    // MARK: - Observer Management

    /// Adds an observer to receive network events
    func addObserver(_ observer: NetworkEventObserver) {
        queue.async {
            self.observers.add(observer)
            logDebug("Added event observer: \(type(of: observer))")
        }
    }

    /// Removes an observer
    func removeObserver(_ observer: NetworkEventObserver) {
        queue.async {
            self.observers.remove(observer)
            logDebug("Removed event observer: \(type(of: observer))")
        }
    }

    /// Returns the current number of observers
    var observerCount: Int {
        queue.sync { observers.count }
    }

    // MARK: - Event Dispatching

    /// Notifies all observers of a status change
    func notifyStatusChanged(from oldStatus: NetworkStatus?, to newStatus: NetworkStatus) {
        dispatchToObservers { observer in
            observer.onStatusChanged(from: oldStatus, to: newStatus)
        }

        // Also check for quality changes
        if let old = oldStatus, old.overallQuality != newStatus.overallQuality {
            notifyQualityChanged(from: old.overallQuality, to: newStatus.overallQuality)
        }

        // Check for signal drops
        if let oldRSSI = oldStatus?.wifiInfo?.rssi,
           let newRSSI = newStatus.wifiInfo?.rssi,
           newRSSI < oldRSSI - AppConstants.signalDropThreshold {
            notifySignalDrop(from: oldRSSI, to: newRSSI)
        }
    }

    /// Notifies all observers that an outage started
    func notifyOutageStarted(layer: String, time: Date) {
        logInfo("Outage started: \(layer)")
        dispatchToObservers { observer in
            observer.onOutageStarted(layer: layer, time: time)
        }
    }

    /// Notifies all observers that an outage ended
    func notifyOutageEnded(layer: String, duration: TimeInterval) {
        logInfo("Outage ended: \(layer), duration: \(Int(duration))s")
        dispatchToObservers { observer in
            observer.onOutageEnded(layer: layer, duration: duration)
        }
    }

    /// Notifies all observers of a quality change
    func notifyQualityChanged(from oldQuality: ConnectionQuality, to newQuality: ConnectionQuality) {
        logInfo("Quality changed: \(oldQuality) -> \(newQuality)")
        dispatchToObservers { observer in
            observer.onQualityChanged(from: oldQuality, to: newQuality)
        }
    }

    /// Notifies all observers of a completed speed test
    func notifySpeedTestCompleted(result: SpeedTestResult) {
        logInfo("Speed test completed: \(result.downloadSpeedDescription)")
        dispatchToObservers { observer in
            observer.onSpeedTestCompleted(result: result)
        }
    }

    /// Notifies all observers of a signal drop
    func notifySignalDrop(from oldRSSI: Int, to newRSSI: Int) {
        logWarning("Signal drop detected: \(oldRSSI) dBm -> \(newRSSI) dBm")
        dispatchToObservers { observer in
            observer.onSignalDrop(from: oldRSSI, to: newRSSI)
        }
    }

    // MARK: - Private

    private func dispatchToObservers(_ action: @escaping (NetworkEventObserver) -> Void) {
        queue.async {
            let allObservers = self.observers.allObjects
            for case let observer as NetworkEventObserver in allObservers {
                DispatchQueue.main.async {
                    action(observer)
                }
            }
        }
    }
}

// MARK: - Script Hook Runner

/// Runs shell scripts in response to network events
final class ScriptHookRunner: NetworkEventObserver {
    private let scriptsPath: URL
    private let scriptQueue = DispatchQueue(label: "com.toocheapfi.scripts", qos: .utility)

    init() {
        scriptsPath = Preferences.configDirectory.appendingPathComponent("hooks")

        // Create hooks directory if needed
        do {
            try FileManager.default.createDirectory(
                at: scriptsPath,
                withIntermediateDirectories: true
            )
        } catch {
            logError("Failed to create hooks directory: \(error)")
        }

        // Register as observer
        EventHookManager.shared.addObserver(self)
        logInfo("Script hook runner initialized at \(scriptsPath.path)")
    }

    // MARK: - NetworkEventObserver

    func onOutageStarted(layer: String, time: Date) {
        let timestamp = ISO8601DateFormatter().string(from: time)
        runScript("on-outage-start", args: [layer, timestamp])
    }

    func onOutageEnded(layer: String, duration: TimeInterval) {
        runScript("on-outage-end", args: [layer, String(Int(duration))])
    }

    func onQualityChanged(from oldQuality: ConnectionQuality, to newQuality: ConnectionQuality) {
        runScript("on-quality-change", args: [oldQuality.rawValue, newQuality.rawValue])
    }

    func onSpeedTestCompleted(result: SpeedTestResult) {
        let speed = result.downloadSpeed.map { String(Int($0)) } ?? "0"
        runScript("on-speed-test", args: [speed, result.testServer])
    }

    func onSignalDrop(from oldRSSI: Int, to newRSSI: Int) {
        runScript("on-signal-drop", args: [String(oldRSSI), String(newRSSI)])
    }

    // MARK: - Private

    private func runScript(_ name: String, args: [String]) {
        let scriptPath = scriptsPath.appendingPathComponent(name)

        guard FileManager.default.isExecutableFile(atPath: scriptPath.path) else {
            return  // Script doesn't exist or isn't executable
        }

        scriptQueue.async {
            logDebug("Running hook script: \(name) with args: \(args)")

            let task = Process()
            task.executableURL = scriptPath
            task.arguments = args

            // Set environment variables
            var env = ProcessInfo.processInfo.environment
            env["TOOCHEAPFI_HOOK"] = name
            env["TOOCHEAPFI_VERSION"] = AppConstants.version
            task.environment = env

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus != 0 {
                    logWarning("Hook script '\(name)' exited with status \(task.terminationStatus)")
                }
            } catch {
                logError("Failed to run hook script '\(name)': \(error)")
            }
        }
    }
}

// MARK: - ConnectionQuality Extension

extension ConnectionQuality {
    var rawValue: String {
        switch self {
        case .excellent: return "excellent"
        case .good: return "good"
        case .fair: return "fair"
        case .poor: return "poor"
        case .none: return "none"
        }
    }
}
