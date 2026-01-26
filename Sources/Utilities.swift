import Foundation

// MARK: - Duration Formatting

/// Formats a duration in seconds to a human-readable string
/// - Parameter seconds: Duration in seconds (accepts both Int and TimeInterval)
/// - Returns: Formatted string like "1h 30m", "5m 30s", or "45s"
func formatDuration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let mins = (seconds % 3600) / 60
    let secs = seconds % 60

    if hours > 0 {
        return "\(hours)h \(mins)m"
    } else if mins > 0 {
        return "\(mins)m \(secs)s"
    } else {
        return "\(secs)s"
    }
}

/// Overload for TimeInterval (Double) input
func formatDuration(_ seconds: TimeInterval) -> String {
    formatDuration(Int(seconds))
}

// MARK: - Byte Formatting

/// Formats bytes to a human-readable string
/// - Parameter bytes: Number of bytes
/// - Returns: Formatted string like "1.5 MB" or "256 KB"
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: bytes)
}

/// Formats bytes to a human-readable string
func formatBytes(_ bytes: Int) -> String {
    formatBytes(Int64(bytes))
}

// MARK: - Speed Formatting

/// Formats speed in Mbps to a human-readable string
/// - Parameter mbps: Speed in megabits per second
/// - Returns: Formatted string like "125.5 Mbps" or "1.2 Gbps"
func formatSpeed(_ mbps: Double) -> String {
    if mbps >= 1000 {
        return String(format: "%.1f Gbps", mbps / 1000)
    } else if mbps >= 100 {
        return String(format: "%.0f Mbps", mbps)
    } else if mbps >= 10 {
        return String(format: "%.1f Mbps", mbps)
    } else {
        return String(format: "%.2f Mbps", mbps)
    }
}

// MARK: - Quality Emoji

/// Returns an emoji representing connection quality
func qualityEmoji(for quality: ConnectionQuality) -> String {
    switch quality {
    case .excellent: return "🟢"
    case .good: return "🟡"
    case .fair: return "🟠"
    case .poor: return "🔴"
    case .none: return "⚫"
    }
}

/// Returns an emoji representing signal quality
func signalEmoji(for quality: SignalQuality) -> String {
    switch quality {
    case .excellent, .good, .fair:
        return "📶"
    case .weak, .veryWeak:
        return "📉"
    case .none:
        return "❌"
    }
}

// MARK: - Congestion Emoji

/// Returns an emoji representing congestion level
func congestionEmoji(for level: String) -> String {
    switch level {
    case "None": return "🟢"
    case "Low": return "🟡"
    case "Medium": return "🟠"
    default: return "🔴"
    }
}
