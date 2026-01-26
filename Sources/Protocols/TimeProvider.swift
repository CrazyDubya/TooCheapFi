import Foundation

/// Protocol for time-related operations
/// Allows mocking time in tests for deterministic behavior
protocol TimeProvider {
    /// Returns the current date/time
    var now: Date { get }

    /// Returns the current time interval since reference date
    var timeIntervalSinceReferenceDate: TimeInterval { get }
}

/// Default implementation using system time
struct SystemTimeProvider: TimeProvider {
    var now: Date { Date() }
    var timeIntervalSinceReferenceDate: TimeInterval { Date.timeIntervalSinceReferenceDate }
}

/// Mock implementation for testing
class MockTimeProvider: TimeProvider {
    var mockDate: Date

    init(date: Date = Date()) {
        self.mockDate = date
    }

    var now: Date { mockDate }
    var timeIntervalSinceReferenceDate: TimeInterval { mockDate.timeIntervalSinceReferenceDate }

    /// Advances the mock time by the specified interval
    func advance(by interval: TimeInterval) {
        mockDate = mockDate.addingTimeInterval(interval)
    }

    /// Sets the mock time to a specific date
    func set(to date: Date) {
        mockDate = date
    }
}
