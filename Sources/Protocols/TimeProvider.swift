import Foundation

/// Protocol for time-related operations
/// Allows mocking time in tests for deterministic behavior
public protocol TimeProvider {
    /// Returns the current date/time
    var now: Date { get }

    /// Returns the current time interval since reference date
    var timeIntervalSinceReferenceDate: TimeInterval { get }
}

/// Default implementation using system time
public struct SystemTimeProvider: TimeProvider {
    public init() {}
    public var now: Date { Date() }
    public var timeIntervalSinceReferenceDate: TimeInterval { Date.timeIntervalSinceReferenceDate }
}

/// Mock implementation for testing
public class MockTimeProvider: TimeProvider {
    public var mockDate: Date

    public init(date: Date = Date()) {
        self.mockDate = date
    }

    public var now: Date { mockDate }
    public var timeIntervalSinceReferenceDate: TimeInterval { mockDate.timeIntervalSinceReferenceDate }

    /// Advances the mock time by the specified interval
    public func advance(by interval: TimeInterval) {
        mockDate = mockDate.addingTimeInterval(interval)
    }

    /// Sets the mock time to a specific date
    public func set(to date: Date) {
        mockDate = date
    }
}
