# TooCheapFi

**macOS Menu Bar Network Monitor**

Don't want to pay for expensive network diagnostic tools? TooCheapFi is a free macOS menu bar app that continuously monitors your connection and tells you exactly what's wrong and how to fix it.

## Features

🔍 **Continuous Monitoring**: Runs quietly in your menu bar, constantly checking your connection

📊 **Detailed Diagnostics**: Separates issues into four distinct categories:
- **Wi-Fi Connection**: Are you connected to a wireless network?
- **Router Status**: Can you reach your local router/gateway?
- **ISP/Internet**: Does your ISP provide internet access?
- **DNS Resolution**: Can you resolve domain names?

💡 **Actionable Fixes**: Get specific, step-by-step instructions on how to fix detected issues

⚡ **Real-time Updates**: Status updates automatically when network conditions change

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9 or later

## Installation

### Build from Source

**Note**: This application requires macOS to build and run. It uses macOS-specific frameworks (Cocoa, SystemConfiguration) that are not available on other platforms.

```bash
# Clone the repository (on macOS)
git clone https://github.com/CrazyDubya/TooCheapFi.git
cd TooCheapFi

# Build the app
make build

# Run the app
make run
```

### Optional: Install System-wide

```bash
make install
```

This installs the binary to `/usr/local/bin/toocheapfi` so you can run it from anywhere.

## Usage

1. **Launch the App**: Run `./.build/release/TooCheapFi` or `make run`
2. **Check the Menu Bar**: Look for the Wi-Fi icon in your menu bar
3. **Click the Icon**: View detailed connection status
4. **Follow Suggestions**: If issues are detected, follow the suggested fixes

### Status Indicators

- ✅ Green checkmark: Component is working correctly
- ❌ Red X: Component has issues
- 🔍 Magnifying glass: Diagnosis information
- 💡 Light bulb: Suggested fixes

## How It Works

TooCheapFi performs systematic checks to pinpoint connection issues:

1. **Wi-Fi Check**: Verifies your device has an active network interface with an IP address
2. **Router Check**: Pings your default gateway to ensure local network connectivity
3. **ISP Check**: Attempts to reach external IP addresses (like 8.8.8.8) to verify internet access
4. **DNS Check**: Tests domain name resolution to ensure DNS is working

By checking each layer independently, TooCheapFi can tell you exactly where the problem is—no more guessing!

## Example Scenarios

### Scenario 1: Router is Off
```
✅ Wi-Fi: Connected (192.168.1.100)
❌ Router: Unreachable (192.168.1.1)
❌ ISP/Internet: No Internet
❌ DNS: Failed

Diagnosis: Connected to Wi-Fi but router is unreachable

Suggested Fixes:
1. Check if router is powered on
2. Verify router lights indicate normal operation
3. Try restarting your router (unplug for 30 sec)
4. Check Ethernet cable connections
```

### Scenario 2: ISP Outage
```
✅ Wi-Fi: Connected (192.168.1.100)
✅ Router: Reachable (192.168.1.1)
❌ ISP/Internet: No Internet
❌ DNS: Failed

Diagnosis: Router works but no internet from ISP

Suggested Fixes:
1. Restart your modem (unplug for 30 sec)
2. Check if other devices have internet
3. Contact your ISP to check for outages
4. Check if your ISP bill is paid
```

### Scenario 3: DNS Issues
```
✅ Wi-Fi: Connected (192.168.1.100)
✅ Router: Reachable (192.168.1.1)
✅ ISP/Internet: Connected
❌ DNS: Failed

Diagnosis: Internet works but DNS resolution is failing

Suggested Fixes:
1. Try using Google DNS (8.8.8.8, 8.8.4.4)
2. Open System Settings > Network > Advanced
3. Go to DNS tab and add 8.8.8.8
4. Restart your computer
```

## Development

### Project Structure

```
TooCheapFi/
├── Package.swift           # Swift Package Manager configuration
├── Makefile               # Build automation
├── Sources/
│   ├── main.swift         # App entry point and menu bar UI
│   ├── NetworkMonitor.swift   # Network diagnostics logic
│   └── NetworkStatus.swift    # Status data model
└── README.md
```

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Clean build artifacts
make clean
```

## Troubleshooting

### App won't launch
- Ensure you have macOS 13+ installed
- Check that Swift 5.9+ is available: `swift --version`
- Try rebuilding: `make clean && make build`

### Incorrect status shown
- Click "Refresh Status" in the menu
- Check System Settings > Network for actual network configuration
- The app checks every 5 seconds automatically

### Permission issues
- The app requires network access permissions
- macOS may prompt you to allow network access on first run

## Roadmap

TooCheapFi is evolving from a simple monitor into a comprehensive network diagnostic tool. See our [Planning Document](PLANNING.md) for the full vision.

### Current Status: v0.1 (Prototype)

Working features:
- [x] Four-layer connectivity diagnostics
- [x] Menu bar integration
- [x] Actionable fix suggestions
- [x] Auto-refresh on network changes

### Coming in v1.0

- [ ] **Homebrew installation**: `brew install toocheapfi`
- [ ] **User preferences**: Customize check intervals, DNS servers
- [ ] **Outage history**: Track connectivity over time
- [ ] **Notifications**: Get alerted when connection drops/restores
- [ ] **ISP reports**: Export outage history to prove issues to your ISP

### Future Plans

- [ ] **Cross-platform**: Linux and Windows support (Rust core)
- [ ] **Latency tracking**: Monitor network quality over time
- [ ] **Advanced diagnostics**: Bandwidth testing, traceroute

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Documentation

- [PLANNING.md](PLANNING.md) - Strategic vision and roadmap
- [docs/PHASE1-TECHNICAL-SPEC.md](docs/PHASE1-TECHNICAL-SPEC.md) - Technical specifications
- [docs/ACTION-ITEMS.md](docs/ACTION-ITEMS.md) - Prioritized task list
- [BUILDING.md](BUILDING.md) - Build instructions
- [UI-GUIDE.md](UI-GUIDE.md) - UI documentation

## License

MIT License - See [LICENSE](LICENSE) for details.

## Why "TooCheapFi"?

Because why pay for expensive network diagnostic tools when you can build one yourself? This app gives you professional-grade network diagnostics completely free!
