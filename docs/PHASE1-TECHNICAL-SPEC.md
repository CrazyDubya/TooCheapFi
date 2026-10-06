# Phase 1 Technical Specification

> **Goal**: Transform TooCheapFi from prototype to production-ready macOS app
> **Timeline**: Immediate priorities
> **Outcome**: v1.0 release on Homebrew

---

## 1. Unit Tests for NetworkMonitor

### Overview
Add comprehensive unit tests to ensure reliability and enable confident refactoring.

### Test Framework
- **XCTest** (Swift's built-in testing framework)
- Add test target to Package.swift

### Test Cases

#### NetworkStatus Tests (`NetworkStatusTests.swift`)
```swift
// Test status initialization
func testNetworkStatusInitialization()

// Test status equality
func testNetworkStatusEquality()

// Test all status combinations
func testAllLayerCombinations()
```

#### NetworkMonitor Tests (`NetworkMonitorTests.swift`)
```swift
// Test interface detection
func testGetNetworkInterface_WhenConnected()
func testGetNetworkInterface_WhenDisconnected()

// Test gateway detection
func testGetDefaultGateway_WithValidRoute()
func testGetDefaultGateway_NoRoute()

// Test ping functionality (mock)
func testPingHost_Success()
func testPingHost_Timeout()
func testPingHost_Unreachable()

// Test DNS resolution (mock)
func testResolveDNS_Success()
func testResolveDNS_Failure()
func testResolveDNS_Timeout()

// Test diagnostic message generation
func testDiagnosticMessage_AllConnected()
func testDiagnosticMessage_WiFiDown()
func testDiagnosticMessage_RouterDown()
func testDiagnosticMessage_ISPDown()
func testDiagnosticMessage_DNSDown()

// Test fix suggestion generation
func testFixSuggestion_WiFiIssue()
func testFixSuggestion_RouterIssue()
func testFixSuggestion_ISPIssue()
func testFixSuggestion_DNSIssue()
```

### Implementation Steps
1. Add test target to `Package.swift`
2. Create `Tests/` directory structure
3. Implement mock network interfaces for testability
4. Write tests with >80% coverage target
5. Add GitHub Actions CI workflow

### Package.swift Changes
```swift
// Add test target
.testTarget(
    name: "TooCheapFiTests",
    dependencies: ["TooCheapFi"]
)
```

---

## 2. Homebrew Formula

### Overview
Enable one-command installation via Homebrew.

### Approach
1. Create Homebrew tap: `CrazyDubya/homebrew-toocheapfi`
2. Write formula that builds from source
3. Later: Submit to homebrew-core

### Formula Structure (`toocheapfi.rb`)
```ruby
class Toocheapfi < Formula
  desc "Network connectivity monitor with intelligent diagnostics"
  homepage "https://github.com/CrazyDubya/TooCheapFi"
  url "https://github.com/CrazyDubya/TooCheapFi/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "CHECKSUM_HERE"
  license "MIT"

  depends_on xcode: ["14.0", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/TooCheapFi"
  end

  def caveats
    <<~EOS
      TooCheapFi runs in your menu bar. Start it with:
        TooCheapFi &

      Or add to Login Items for automatic startup.
    EOS
  end

  test do
    # Basic test that binary runs
    assert_match "TooCheapFi", shell_output("#{bin}/TooCheapFi --version 2>&1", 1)
  end
end
```

### Implementation Steps
1. Add `--version` flag support to main.swift
2. Create GitHub release with tagged version
3. Create homebrew tap repository
4. Test formula locally
5. Document installation in README

---

## 3. SQLite History Logging

### Overview
Persist connectivity events to enable outage tracking and reporting.

### Database Location
```
~/Library/Application Support/TooCheapFi/history.db
```

### Schema
```sql
-- Connectivity check events
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    wifi_ok INTEGER NOT NULL,
    wifi_ip TEXT,
    router_ok INTEGER NOT NULL,
    router_ip TEXT,
    isp_ok INTEGER NOT NULL,
    dns_ok INTEGER NOT NULL,
    latency_ms INTEGER,
    error_layer TEXT,  -- NULL if all OK, else 'wifi'|'router'|'isp'|'dns'
    error_message TEXT
);

-- Aggregated outage records
CREATE TABLE IF NOT EXISTS outages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time TEXT NOT NULL,
    end_time TEXT,
    duration_seconds INTEGER,
    affected_layer TEXT NOT NULL,
    resolved INTEGER NOT NULL DEFAULT 0
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_outages_start ON outages(start_time);
```

### Swift Implementation

#### New File: `Sources/HistoryStore.swift`
```swift
import Foundation
import SQLite3

class HistoryStore {
    private var db: OpaquePointer?
    private let dbPath: String

    init() throws {
        // Create app support directory
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("TooCheapFi")

        try FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )

        dbPath = appSupport.appendingPathComponent("history.db").path

        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw HistoryError.cannotOpenDatabase
        }

        try createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // Record a connectivity check
    func recordEvent(_ status: NetworkStatus) throws

    // Start tracking an outage
    func startOutage(layer: String, message: String) throws -> Int64

    // End an outage
    func endOutage(id: Int64) throws

    // Get recent events
    func getRecentEvents(limit: Int = 100) throws -> [ConnectivityEvent]

    // Get outages in date range
    func getOutages(from: Date, to: Date) throws -> [Outage]

    // Get uptime percentage
    func getUptimePercentage(hours: Int = 24) throws -> Double

    // Export to CSV
    func exportCSV(from: Date, to: Date) throws -> String
}

enum HistoryError: Error {
    case cannotOpenDatabase
    case queryFailed(String)
}

struct ConnectivityEvent {
    let id: Int64
    let timestamp: Date
    let wifiOk: Bool
    let routerOk: Bool
    let ispOk: Bool
    let dnsOk: Bool
    let latencyMs: Int?
    let errorLayer: String?
    let errorMessage: String?
}

struct Outage {
    let id: Int64
    let startTime: Date
    let endTime: Date?
    let durationSeconds: Int?
    let affectedLayer: String
    let resolved: Bool
}
```

### Integration with NetworkMonitor

```swift
// In NetworkMonitor.swift, after each check:
if let store = historyStore {
    try? store.recordEvent(status)

    // Detect outage start/end
    if !status.isFullyConnected && lastStatus?.isFullyConnected == true {
        currentOutageId = try? store.startOutage(
            layer: status.failedLayer,
            message: status.diagnosticMessage
        )
    } else if status.isFullyConnected && lastStatus?.isFullyConnected == false {
        if let outageId = currentOutageId {
            try? store.endOutage(id: outageId)
            currentOutageId = nil
        }
    }
}
```

### Data Retention
- Keep detailed events for 7 days
- Keep aggregated outages for 1 year
- Automatic cleanup on app start

---

## 4. User Preferences

### Overview
Allow users to customize behavior without code changes.

### Configuration File Location
```
~/Library/Application Support/TooCheapFi/config.json
```

### Configuration Options
```json
{
  "checkIntervalSeconds": 5,
  "pingTimeoutSeconds": 2,
  "dnsServers": ["8.8.8.8", "1.1.1.1"],
  "testDomain": "apple.com",
  "enableNotifications": true,
  "notifyOnRestore": true,
  "notifyOnOutage": true,
  "outageThresholdSeconds": 30,
  "historyRetentionDays": 7,
  "launchAtLogin": false
}
```

### Swift Implementation

#### New File: `Sources/Preferences.swift`
```swift
import Foundation

struct Preferences: Codable {
    var checkIntervalSeconds: Int = 5
    var pingTimeoutSeconds: Int = 2
    var dnsServers: [String] = ["8.8.8.8", "1.1.1.1"]
    var testDomain: String = "apple.com"
    var enableNotifications: Bool = true
    var notifyOnRestore: Bool = true
    var notifyOnOutage: Bool = true
    var outageThresholdSeconds: Int = 30
    var historyRetentionDays: Int = 7
    var launchAtLogin: Bool = false

    static let `default` = Preferences()

    static func load() -> Preferences {
        let configPath = Preferences.configPath

        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data)
        else {
            return .default
        }

        return prefs
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: Preferences.configPath)
    }

    static var configPath: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("TooCheapFi")

        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )

        return appSupport.appendingPathComponent("config.json")
    }
}
```

### Menu Integration
Add preferences submenu:
```
TooCheapFi
├── Status: All Connected ✓
├── ─────────────────────
├── Wi-Fi: Connected (192.168.1.100)
├── Router: Reachable ✓
├── ISP: Online ✓
├── DNS: Working ✓
├── ─────────────────────
├── Preferences ▶
│   ├── Check Interval ▶
│   │   ├── ○ 1 second
│   │   ├── ● 5 seconds (default)
│   │   ├── ○ 10 seconds
│   │   └── ○ 30 seconds
│   ├── Notifications ▶
│   │   ├── ✓ Enable Notifications
│   │   ├── ✓ Notify on Outage
│   │   └── ✓ Notify on Restore
│   └── Open Config File...
├── ─────────────────────
├── Refresh (⌘R)
└── Quit (⌘Q)
```

---

## 5. macOS Notifications

### Overview
Alert users to connectivity changes without requiring them to watch the menu bar.

### Notification Types

| Event | Title | Body | Sound |
|-------|-------|------|-------|
| Outage Start | "Internet Disconnected" | "Router unreachable. Check your Wi-Fi connection." | Default |
| Outage End | "Internet Restored" | "Connection restored after 2m 34s" | None |
| Extended Outage | "Ongoing Outage" | "No internet for 5 minutes. ISP may be down." | Default |

### Implementation

```swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            if granted {
                print("Notifications enabled")
            }
        }
    }

    func notifyOutageStart(layer: String, message: String) {
        guard Preferences.load().enableNotifications,
              Preferences.load().notifyOnOutage else { return }

        let content = UNMutableNotificationContent()
        content.title = "Internet Disconnected"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "outage-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyOutageEnd(duration: TimeInterval) {
        guard Preferences.load().enableNotifications,
              Preferences.load().notifyOnRestore else { return }

        let content = UNMutableNotificationContent()
        content.title = "Internet Restored"
        content.body = "Connection restored after \(formatDuration(duration))"

        let request = UNNotificationRequest(
            identifier: "restore-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}
```

### Smart Notification Logic
- Don't notify for blips < 30 seconds (configurable)
- Group rapid notifications
- Respect Do Not Disturb

---

## 6. Version Flag Support

### Overview
Add `--version` and `--help` flags for CLI compatibility and Homebrew testing.

### Implementation

```swift
// At the start of main.swift
let args = CommandLine.arguments

if args.contains("--version") || args.contains("-v") {
    print("TooCheapFi 1.0.0")
    exit(0)
}

if args.contains("--help") || args.contains("-h") {
    print("""
    TooCheapFi - Network Connectivity Monitor

    Usage: TooCheapFi [options]

    Options:
      --version, -v    Print version and exit
      --help, -h       Print this help message
      --check-once     Run single check and exit (for scripts)
      --json           Output in JSON format (with --check-once)

    TooCheapFi runs in your menu bar and monitors network connectivity.
    It checks Wi-Fi, router, ISP, and DNS layers every 5 seconds.

    Configuration: ~/Library/Application Support/TooCheapFi/config.json
    History: ~/Library/Application Support/TooCheapFi/history.db

    For more information: https://github.com/CrazyDubya/TooCheapFi
    """)
    exit(0)
}

if args.contains("--check-once") {
    // Run single diagnostic and exit
    let monitor = NetworkMonitor()
    let status = monitor.checkNow()

    if args.contains("--json") {
        // Output JSON for scripting
        let json = """
        {
          "wifi": {"connected": \(status.wifiConnected), "ip": "\(status.wifiIP ?? "")"},
          "router": {"reachable": \(status.routerReachable), "ip": "\(status.routerIP ?? "")"},
          "isp": {"online": \(status.ispReachable)},
          "dns": {"working": \(status.dnsWorking)},
          "status": "\(status.isFullyConnected ? "connected" : "disconnected")",
          "message": "\(status.diagnosticMessage)"
        }
        """
        print(json)
    } else {
        print(status.diagnosticMessage)
    }
    exit(status.isFullyConnected ? 0 : 1)
}
```

---

## 7. GitHub Actions CI

### Workflow File: `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, claude/*]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: '5.9'

      - name: Build
        run: swift build -c release

      - name: Run Tests
        run: swift test

      - name: Check Version Flag
        run: .build/release/TooCheapFi --version

  lint:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: SwiftLint
        run: |
          brew install swiftlint
          swiftlint lint --strict
```

### Release Workflow: `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build Release
        run: swift build -c release --arch arm64 --arch x86_64

      - name: Create Archive
        run: |
          cd .build/release
          tar -czvf TooCheapFi-${{ github.ref_name }}-macos.tar.gz TooCheapFi

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: .build/release/TooCheapFi-${{ github.ref_name }}-macos.tar.gz
          generate_release_notes: true
```

---

## Implementation Order

1. **Version flag support** - Simple, enables everything else
2. **GitHub Actions CI** - Catch issues early
3. **Unit tests** - Build confidence for refactoring
4. **User preferences** - Foundation for customization
5. **SQLite history** - Enable outage tracking
6. **Notifications** - User-visible improvement
7. **Homebrew formula** - Distribution ready

---

## File Structure After Phase 1

```
TooCheapFi/
├── Sources/
│   ├── main.swift              (updated with CLI flags)
│   ├── NetworkMonitor.swift    (updated with preferences)
│   ├── NetworkStatus.swift     (unchanged)
│   ├── Preferences.swift       (new)
│   ├── HistoryStore.swift      (new)
│   └── NotificationManager.swift (new)
├── Tests/
│   ├── NetworkStatusTests.swift
│   └── NetworkMonitorTests.swift
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── release.yml
├── Package.swift               (updated with test target)
├── Makefile
├── README.md
├── BUILDING.md
├── UI-GUIDE.md
├── IMPLEMENTATION.md
├── PLANNING.md
├── docs/
│   └── PHASE1-TECHNICAL-SPEC.md
└── LICENSE
```

---

## Success Criteria for Phase 1 Complete

- [ ] All unit tests pass with >80% coverage
- [ ] `brew install` works from tap
- [ ] Preferences file is created and respected
- [ ] History database records events
- [ ] Notifications fire on outage/restore
- [ ] CI pipeline passes on all PRs
- [ ] README updated with new features
