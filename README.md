# TooCheapFi

**macOS Menu Bar Network Monitor with Comprehensive Wi-Fi Diagnostics**

Don't want to pay for expensive network diagnostic tools? TooCheapFi is a free macOS menu bar app that continuously monitors your connection and tells you exactly what's wrong and how to fix it.

## Features

### Multi-Layer Connectivity Testing
- **Interface Detection**: Identifies Wi-Fi, Ethernet, VPN, and cellular connections
- **Gateway Reachability**: Tests router connectivity with ICMP and TCP fallback
- **Internet Connectivity**: Multiple target testing (Google, Cloudflare, OpenDNS)
- **DNS Resolution**: Tests against multiple domains for reliability
- **HTTP/Captive Portal**: Detects hotel/airport login pages automatically

### Wi-Fi Signal Diagnostics
- **Signal Strength (RSSI)**: Real-time signal quality monitoring
- **Noise Floor**: Environmental interference measurement
- **Signal-to-Noise Ratio (SNR)**: True signal quality assessment
- **Wi-Fi Standard Detection**: 802.11n/ac/ax (Wi-Fi 4/5/6)
- **Security Analysis**: WPA2/WPA3 security assessment

### Channel Analysis
- **2.4 GHz Scanning**: Analysis of channels 1, 6, and 11
- **5 GHz Scanning**: Non-DFS channel analysis (36-165)
- **Congestion Detection**: Identifies overcrowded channels
- **Recommendations**: Suggests optimal channel changes

### Speed Testing
- **Download Speed**: One-click speed measurement using Cloudflare
- **Quality Assessment**: Categorizes as Excellent/Good/Fair/Slow

### Notifications
- **Outage Alerts**: Get notified when internet goes down
- **Restoration Alerts**: Know when connectivity is restored
- **Signal Warnings**: Alerts for significant signal drops
- **Captive Portal Detection**: Prompts for login-required networks

### History & Statistics
- **Event Logging**: SQLite database tracks connectivity over time
- **Uptime Tracking**: 24-hour uptime percentage
- **Outage History**: Duration and cause of each outage
- **CSV Export**: Export data for ISP disputes or analysis

### User Preferences
- **Configurable Intervals**: Adjust check frequency
- **Custom DNS Servers**: Use your preferred DNS targets
- **Notification Control**: Enable/disable alert types
- **History Retention**: Configure data retention period
- **Quality Thresholds**: Customize RSSI, latency, and congestion thresholds

### Event Hooks
- **Observer Pattern**: Register Swift objects to receive network events
- **Shell Script Hooks**: Execute custom scripts on network events
- **Supported Events**: Outage start/end, quality changes, speed tests, signal drops

## Requirements

- macOS 12.0 (Monterey) or later
- Swift 5.9 or later

## Installation

### Homebrew (Recommended)

```bash
brew tap CrazyDubya/toocheapfi
brew install toocheapfi
```

### Build from Source

**Note**: This application requires macOS to build and run.

```bash
# Clone the repository
git clone https://github.com/CrazyDubya/TooCheapFi.git
cd TooCheapFi

# Build the app
make build

# Run the app
make run
```

### Create App Bundle

```bash
make app
open TooCheapFi.app
```

### Install System-wide

```bash
make install
```

This installs the binary to `/usr/local/bin/toocheapfi`.

## Command Line Options

```bash
toocheapfi --help      # Show help
toocheapfi --version   # Show version
toocheapfi             # Launch the menu bar app
```

## Usage

1. **Launch the App**: Run the app or use `make run`
2. **Check the Menu Bar**: Look for the Wi-Fi icon
3. **Click the Icon**: View detailed connection status
4. **Run Speed Test**: Click "Run Speed Test" for bandwidth measurement
5. **Export Data**: Use Export menu to save CSV reports

### Quality Indicators

The menu bar icon and header show overall connection quality:
- 🟢 **Excellent** (80-100): All systems working optimally
- 🟡 **Good** (60-79): Minor issues or slight latency
- 🟠 **Fair** (40-59): Notable issues affecting performance
- 🔴 **Poor** (1-39): Significant connectivity problems
- ⚫ **None** (0): No connection

## How It Works

TooCheapFi performs systematic multi-layer checks:

1. **Interface Layer**: Detects active network interface using CoreWLAN
2. **Wi-Fi Analysis**: Collects RSSI, noise, SNR, channel, security via CoreWLAN
3. **Gateway Check**: Pings router with ICMP, falls back to TCP if blocked
4. **Internet Check**: Tests multiple IPs (8.8.8.8, 1.1.1.1, 208.67.222.222)
5. **DNS Check**: Resolves multiple domains (apple.com, cloudflare.com, microsoft.com)
6. **HTTP Check**: Fetches Apple's captive portal page to detect login walls
7. **Channel Scan**: Scans for neighboring networks to assess congestion
8. **Quality Score**: Calculates 0-100 score based on all factors

## Configuration

Preferences are stored in `~/Library/Application Support/TooCheapFi/config.json`:

```json
{
  "checkIntervalSeconds": 5,
  "pingTimeoutSeconds": 2,
  "ispTestTargets": ["8.8.8.8", "1.1.1.1", "208.67.222.222"],
  "dnsTestDomains": ["apple.com", "cloudflare.com", "microsoft.com"],
  "notificationsEnabled": true,
  "historyEnabled": true,
  "historyRetentionDays": 30,
  "speedTestSizeMB": 10
}
```

Access via menu: **Settings > Open Config File...**

### Configurable Thresholds

You can customize quality thresholds in `config.json`:

```json
{
  "rssiExcellent": -50,
  "rssiGood": -60,
  "rssiFair": -70,
  "rssiWeak": -80,
  "snrGood": 25,
  "snrPoor": 15,
  "latencyGood": 30,
  "latencyFair": 50,
  "latencyPoor": 100,
  "congestionLow": 3,
  "congestionMedium": 7,
  "speedSlow": 50
}
```

## Event Hooks

TooCheapFi supports event hooks for automation and integration.

### Shell Script Hooks

Create executable scripts in `~/.config/toocheapfi/hooks/`:

| Script Name | Arguments | Description |
|-------------|-----------|-------------|
| `on-outage-start` | `[layer] [timestamp]` | Called when outage begins |
| `on-outage-end` | `[layer] [duration_seconds]` | Called when outage ends |
| `on-quality-change` | `[old_quality] [new_quality]` | Called when quality changes |
| `on-speed-test` | `[speed_mbps] [server]` | Called after speed test |
| `on-signal-drop` | `[old_rssi] [new_rssi]` | Called on significant signal drop |

**Example hook script** (`~/.config/toocheapfi/hooks/on-outage-start`):

```bash
#!/bin/bash
LAYER=$1
TIMESTAMP=$2
echo "[$TIMESTAMP] Outage detected at $LAYER layer" >> ~/network-outages.log

# Send notification via external service
curl -X POST "https://your-webhook.example/notify" \
  -d "message=Network outage: $LAYER layer down"
```

Make scripts executable: `chmod +x ~/.config/toocheapfi/hooks/on-outage-start`

### Swift Observer API

For programmatic integration, implement `NetworkEventObserver`:

```swift
class MyObserver: NetworkEventObserver {
    func onOutageStarted(layer: String, time: Date) {
        print("Outage started: \(layer)")
    }

    func onQualityChanged(from old: ConnectionQuality, to new: ConnectionQuality) {
        print("Quality: \(old) -> \(new)")
    }
}

// Register observer
let observer = MyObserver()
EventHookManager.shared.addObserver(observer)
```

## Data Storage

History is stored in `~/Library/Application Support/TooCheapFi/history.db`:

- **events**: Timestamped connectivity snapshots
- **outages**: Start/end times, duration, affected layer
- **speed_tests**: Speed test results over time

Export via menu: **Export Data > Export History to CSV...**

## Project Structure

```
TooCheapFi/
├── Package.swift                 # Swift Package Manager configuration
├── Makefile                      # Build automation
├── .swiftlint.yml                # SwiftLint configuration
├── Formula/
│   └── toocheapfi.rb             # Homebrew formula
├── Sources/
│   ├── main.swift                # App entry point and menu bar UI
│   ├── AppConstants.swift        # Centralized app constants (v1.3)
│   ├── Utilities.swift           # Shared utility functions (v1.3)
│   ├── NetworkMonitor.swift      # Main monitoring coordinator
│   ├── NetworkStatus.swift       # Status data models
│   ├── NetworkUtilities.swift    # Low-level ping/TCP/DNS utilities
│   ├── ConnectivityChecker.swift # Multi-layer connectivity tests
│   ├── WiFiAnalyzer.swift        # Wi-Fi info and channel analysis
│   ├── IssueAnalyzer.swift       # Issue detection and quality scoring
│   ├── NotificationManager.swift # macOS notifications
│   ├── Preferences.swift         # User configuration with thresholds
│   ├── HistoryStore.swift        # SQLite history logging
│   ├── EventHooks.swift          # Event observer system and script hooks
│   ├── ThreadSafe.swift          # Thread-safe property wrapper
│   └── Logger.swift              # Centralized logging (os_log)
├── Tests/
│   ├── PreferencesTests.swift
│   ├── QualityScoreTests.swift
│   ├── SignalQualityTests.swift
│   ├── EventHooksTests.swift
│   ├── HistoryStoreTests.swift
│   ├── ConnectivityCheckerTests.swift
│   ├── WiFiAnalyzerTests.swift   # WiFi analysis tests (v1.3)
│   ├── UtilitiesTests.swift      # Shared utilities tests (v1.3)
│   ├── AppConstantsTests.swift   # Constants tests (v1.3)
│   └── LoggerTests.swift         # Logger tests (v1.3)
├── .github/
│   └── workflows/
│       └── ci.yml                # GitHub Actions (lint, test, build, release)
└── docs/
    ├── PLANNING.md               # Strategic vision
    ├── V1.2-PLAN.md              # v1.2 implementation plan
    ├── PHASE1-TECHNICAL-SPEC.md
    ├── LOGIC-ANALYSIS.md         # Network checking analysis
    └── WIFI-DIAGNOSTICS-ANALYSIS.md
```

## Troubleshooting

### App won't launch
- Ensure macOS 12+ is installed
- Check Swift 5.9+: `swift --version`
- Rebuild: `make clean && make build`

### No Wi-Fi diagnostics
- Grant Location Services permission when prompted
- Check System Settings > Privacy & Security > Location Services

### Channel analysis empty
- Location Services required for Wi-Fi scanning
- Some enterprise networks block scanning

### Permission issues
- macOS may prompt for network access on first run
- Grant permission in System Settings > Privacy & Security

## Version History

### v1.3.0 (Current)
- **Stability**: Eliminated Implicitly Unwrapped Optionals (IUOs) in main.swift
- **Centralized Constants**: `AppConstants.swift` with single source for version, URLs, thresholds
- **Shared Utilities**: `Utilities.swift` with consolidated formatting functions
- **Enhanced Linting**: IUO detection, stricter thresholds, force cast warnings
- **CI/CD Hardening**: Removed test skip flag, added code coverage, macOS 13/14 matrix
- **Test Coverage**: Added tests for WiFiAnalyzer, Utilities, AppConstants, Logger
- **Error Handling**: Proper logging for database and file operations
- **Code Quality**: Print statements migrated to Logger

### v1.2.0
- **Security**: Fixed SQL injection vulnerabilities with parameterized queries
- **Stability**: Eliminated force unwraps throughout codebase
- **Thread Safety**: Added `ThreadSafe` property wrapper and database queue
- **Logging**: Centralized logging via `os_log` integration
- **Event Hooks**: Observer pattern and shell script hooks for automation
- **Configurable Thresholds**: Customize RSSI, latency, SNR, and congestion limits
- **Memory Management**: Proper cleanup with `deinit` handlers
- **Tests**: Comprehensive test suite for hooks, history, and connectivity

### v1.1.0
- **Code Quality**: SwiftLint integration with custom rules
- **CI/CD**: Enhanced GitHub Actions (lint, test, DMG creation)
- **Modularization**: Split NetworkMonitor into focused modules:
  - `ConnectivityChecker` - Multi-layer connectivity tests
  - `WiFiAnalyzer` - Wi-Fi info and channel analysis
  - `IssueAnalyzer` - Issue detection and scoring
  - `NetworkUtilities` - Low-level network operations
- **Tests**: Added unit tests for preferences, quality scoring, signal quality

### v1.0.0
- Multi-layer connectivity testing with fallbacks
- Comprehensive Wi-Fi diagnostics (RSSI, SNR, channel)
- 2.4 GHz and 5 GHz channel analysis
- Captive portal detection
- Speed testing via Cloudflare
- macOS notifications for outages
- SQLite history logging
- CSV export functionality
- User preferences system
- Homebrew formula

### v0.1.0 (Prototype)
- Basic four-layer connectivity checks
- Menu bar integration
- Simple fix suggestions

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Documentation

- [PLANNING.md](PLANNING.md) - Strategic vision and roadmap
- [docs/LOGIC-ANALYSIS.md](docs/LOGIC-ANALYSIS.md) - Network checking logic analysis
- [docs/WIFI-DIAGNOSTICS-ANALYSIS.md](docs/WIFI-DIAGNOSTICS-ANALYSIS.md) - Wi-Fi diagnostics design
- [BUILDING.md](BUILDING.md) - Build instructions
- [UI-GUIDE.md](UI-GUIDE.md) - UI documentation

## License

MIT License - See [LICENSE](LICENSE) for details.

## Why "TooCheapFi"?

Because why pay for expensive network diagnostic tools when you can build one yourself? This app gives you professional-grade network diagnostics completely free!
