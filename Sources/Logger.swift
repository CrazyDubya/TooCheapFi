import Foundation
import os.log

/// Log levels for categorizing messages
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

/// Centralized logging for TooCheapFi
/// Uses os_log for system integration and optionally logs to file
final class Logger {
    static let shared = Logger()

    private let osLog = OSLog(subsystem: "com.toocheapfi", category: "general")
    private let fileQueue = DispatchQueue(label: "com.toocheapfi.logger")
    private var logFileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    #if DEBUG
    private let minLevel: LogLevel = .debug
    #else
    private let minLevel: LogLevel = .info
    #endif

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        setupLogFile()
    }

    deinit {
        logFileHandle?.closeFile()
    }

    // MARK: - Public API

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog(level) else { return }

        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(level.rawValue)] \(fileName):\(line) \(function) - \(message)"

        // Log to os_log
        os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)

        // Log to file in debug builds
        #if DEBUG
        writeToFile(formattedMessage)
        #endif
    }

    // MARK: - Private

    private func shouldLog(_ level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        guard let levelIndex = levels.firstIndex(of: level),
              let minIndex = levels.firstIndex(of: minLevel) else {
            return false
        }
        return levelIndex >= minIndex
    }

    private func setupLogFile() {
        #if DEBUG
        let logPath = Preferences.configDirectory.appendingPathComponent("debug.log")

        // Create file if needed
        if !FileManager.default.fileExists(atPath: logPath.path) {
            FileManager.default.createFile(atPath: logPath.path, contents: nil)
        }

        logFileHandle = try? FileHandle(forWritingTo: logPath)
        logFileHandle?.seekToEndOfFile()

        // Write startup marker
        let startMessage = "\n\n=== TooCheapFi Started at \(dateFormatter.string(from: Date())) ===\n"
        if let data = startMessage.data(using: .utf8) {
            logFileHandle?.write(data)
        }
        #endif
    }

    private func writeToFile(_ message: String) {
        fileQueue.async { [weak self] in
            guard let self = self,
                  let data = "\(self.dateFormatter.string(from: Date())) \(message)\n".data(using: .utf8) else {
                return
            }
            self.logFileHandle?.write(data)
        }
    }
}

// MARK: - Convenience Global Functions

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, file: file, function: function, line: line)
}
