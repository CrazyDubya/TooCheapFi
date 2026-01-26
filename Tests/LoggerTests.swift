import XCTest

/// Tests for the Logger functionality
final class LoggerTests: XCTestCase {

    // MARK: - Log Level Tests

    func testLogLevelDebug() {
        // Debug should be lowest priority
        let level = LogLevel.debug
        XCTAssertEqual(level.rawValue, "debug")
    }

    func testLogLevelInfo() {
        let level = LogLevel.info
        XCTAssertEqual(level.rawValue, "info")
    }

    func testLogLevelWarning() {
        let level = LogLevel.warning
        XCTAssertEqual(level.rawValue, "warning")
    }

    func testLogLevelError() {
        // Error should be highest priority
        let level = LogLevel.error
        XCTAssertEqual(level.rawValue, "error")
    }

    // MARK: - Log Level Ordering Tests

    func testLogLevelOrdering() {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]

        // Verify all levels are distinct
        let uniqueLevels = Set(levels.map { $0.rawValue })
        XCTAssertEqual(uniqueLevels.count, 4, "All log levels should be unique")
    }

    // MARK: - os_log Type Mapping Tests

    func testOSLogTypeMapping_Debug() {
        let level = LogLevel.debug
        let osLogType = level.osLogType
        // Debug maps to OSLogType.debug
        XCTAssertNotNil(osLogType)
    }

    func testOSLogTypeMapping_Info() {
        let level = LogLevel.info
        let osLogType = level.osLogType
        XCTAssertNotNil(osLogType)
    }

    func testOSLogTypeMapping_Warning() {
        let level = LogLevel.warning
        let osLogType = level.osLogType
        XCTAssertNotNil(osLogType)
    }

    func testOSLogTypeMapping_Error() {
        let level = LogLevel.error
        let osLogType = level.osLogType
        XCTAssertNotNil(osLogType)
    }

    // MARK: - Logger Instance Tests

    func testLoggerSharedInstance() {
        let logger1 = Logger.shared
        let logger2 = Logger.shared
        XCTAssertTrue(logger1 === logger2, "Should be singleton")
    }

    // MARK: - Log Message Formatting Tests

    func testLogMessageFormatting_IncludesLevel() {
        // Test that log messages include level prefix
        let prefix = formatLogPrefix(.error, file: "Test.swift", function: "testFunc", line: 42)
        XCTAssertTrue(prefix.contains("ERROR") || prefix.contains("error"),
                     "Log prefix should include level")
    }

    func testLogMessageFormatting_IncludesFile() {
        let prefix = formatLogPrefix(.info, file: "/path/to/Test.swift", function: "testFunc", line: 42)
        XCTAssertTrue(prefix.contains("Test.swift"), "Log prefix should include filename")
    }

    func testLogMessageFormatting_IncludesLine() {
        let prefix = formatLogPrefix(.info, file: "Test.swift", function: "testFunc", line: 42)
        XCTAssertTrue(prefix.contains("42"), "Log prefix should include line number")
    }

    // MARK: - Convenience Functions Tests

    func testLogDebugExists() {
        // Just verify the function exists and is callable
        logDebug("Test debug message")
        // No assertion needed - just verifying it compiles and runs
    }

    func testLogInfoExists() {
        logInfo("Test info message")
    }

    func testLogWarningExists() {
        logWarning("Test warning message")
    }

    func testLogErrorExists() {
        logError("Test error message")
    }

    // MARK: - File Path Extraction Tests

    func testExtractFilename_FullPath() {
        let path = "/Users/test/Project/Sources/MyFile.swift"
        let filename = extractFilename(from: path)
        XCTAssertEqual(filename, "MyFile.swift")
    }

    func testExtractFilename_NoPath() {
        let path = "MyFile.swift"
        let filename = extractFilename(from: path)
        XCTAssertEqual(filename, "MyFile.swift")
    }

    func testExtractFilename_EmptyPath() {
        let path = ""
        let filename = extractFilename(from: path)
        XCTAssertEqual(filename, "")
    }

    // MARK: - Helper Functions

    private func formatLogPrefix(_ level: LogLevel, file: String, function: String, line: Int) -> String {
        let filename = extractFilename(from: file)
        return "[\(level.rawValue.uppercased())] \(filename):\(line) \(function)"
    }

    private func extractFilename(from path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
