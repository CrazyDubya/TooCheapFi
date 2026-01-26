# TooCheapFi User Interface Guide

## Menu Bar Icon

The app displays an icon in the macOS menu bar (top-right corner of screen):

- **Normal State**: Wi-Fi icon (circle with waves)
- **Problem Detected**: Wi-Fi icon with exclamation mark

## Menu Layout

When you click the menu bar icon, you see:

```
╔═══════════════════════════════════════════════╗
║  TooCheapFi - Network Monitor                 ║
║ ───────────────────────────────────────────── ║
║  ✅ All Systems Operational                   ║
║     (or ⚠️ Connection Issues Detected)        ║
║ ───────────────────────────────────────────── ║
║  ✅ Wi-Fi: Connected (192.168.1.100)         ║
║  ✅ Router: Reachable (192.168.1.1)          ║
║  ✅ ISP/Internet: Connected                   ║
║  ✅ DNS: Working                              ║
║ ───────────────────────────────────────────── ║
║  Refresh Status                                ║
║ ───────────────────────────────────────────── ║
║  Quit                                          ║
╚═══════════════════════════════════════════════╝
```

## When Problems Are Detected

If any component fails, the menu expands to show diagnosis and fixes:

```
╔═══════════════════════════════════════════════╗
║  TooCheapFi - Network Monitor                 ║
║ ───────────────────────────────────────────── ║
║  ⚠️ Connection Issues Detected                ║
║ ───────────────────────────────────────────── ║
║  ✅ Wi-Fi: Connected (192.168.1.100)         ║
║  ❌ Router: Unreachable (192.168.1.1)        ║
║  ❌ ISP/Internet: No Internet                 ║
║  ❌ DNS: Failed                               ║
║ ───────────────────────────────────────────── ║
║  🔍 Diagnosis:                                ║
║     Connected to Wi-Fi but router unreachable ║
║ ───────────────────────────────────────────── ║
║  💡 Suggested Fixes:                          ║
║     1. Check if router is powered on          ║
║     2. Verify router lights indicate normal   ║
║     3. Try restarting your router             ║
║     4. Check Ethernet cable connections       ║
║ ───────────────────────────────────────────── ║
║  Refresh Status                                ║
║ ───────────────────────────────────────────── ║
║  Quit                                          ║
╚═══════════════════════════════════════════════╝
```

## Status Indicators

### Wi-Fi Check
- ✅ **Connected**: Shows your local IP address
- ❌ **Not Connected**: No Wi-Fi connection detected

### Router Check
- ✅ **Reachable**: Shows router IP address (usually 192.168.x.1 or 10.0.0.1)
- ❌ **Unreachable**: Cannot ping default gateway

### ISP/Internet Check
- ✅ **Connected**: Successfully reached external IP (8.8.8.8)
- ❌ **No Internet**: Cannot reach internet (ISP problem)

### DNS Check
- ✅ **Working**: Successfully resolved www.google.com
- ❌ **Failed**: DNS resolution not working

## Automatic Updates

The app automatically:
- Checks status every 5 seconds
- Updates immediately when network changes occur
- Changes menu bar icon based on overall status

## Interactive Elements

- **Refresh Status**: Manually trigger an immediate status check
- **Quit**: Exit the application

## Color Coding

While the menu items are text-based:
- ✅ = Success (green in concept)
- ❌ = Failure (red in concept)
- 🔍 = Diagnosis information (blue in concept)
- 💡 = Suggested fixes (yellow/gold in concept)

## Example Scenarios

### Scenario 1: Everything Working
```
✅ All Systems Operational
✅ Wi-Fi: Connected (192.168.1.45)
✅ Router: Reachable (192.168.1.1)
✅ ISP/Internet: Connected
✅ DNS: Working
```

### Scenario 2: Router Offline
```
⚠️ Connection Issues Detected
✅ Wi-Fi: Connected (192.168.1.45)
❌ Router: Unreachable (192.168.1.1)
❌ ISP/Internet: No Internet
❌ DNS: Failed

🔍 Diagnosis:
   Connected to Wi-Fi but router is unreachable

💡 Suggested Fixes:
   1. Check if router is powered on
   2. Try restarting your router (unplug 30 sec)
```

### Scenario 3: ISP Outage
```
⚠️ Connection Issues Detected
✅ Wi-Fi: Connected (192.168.1.45)
✅ Router: Reachable (192.168.1.1)
❌ ISP/Internet: No Internet
❌ DNS: Failed

🔍 Diagnosis:
   Router works but no internet from ISP

💡 Suggested Fixes:
   1. Restart your modem (unplug 30 sec)
   2. Contact your ISP to check for outages
```

### Scenario 4: DNS Problems Only
```
⚠️ Connection Issues Detected
✅ Wi-Fi: Connected (192.168.1.45)
✅ Router: Reachable (192.168.1.1)
✅ ISP/Internet: Connected
❌ DNS: Failed

🔍 Diagnosis:
   Internet works but DNS resolution is failing

💡 Suggested Fixes:
   1. Try using Google DNS (8.8.8.8, 8.8.4.4)
   2. Open System Settings > Network > Advanced
   3. Go to DNS tab and add 8.8.8.8
```

## Keyboard Shortcuts

- **⌘R**: Refresh Status (when menu is open)
- **⌘Q**: Quit Application (when menu is open)

## Tips for Best Results

1. Keep the app running in the background
2. Click "Refresh Status" if you've just made network changes
3. Follow suggested fixes in order for best results
4. If problems persist after trying all fixes, contact your ISP

## Privacy

TooCheapFi only monitors local network status. It:
- Does NOT collect any personal data
- Does NOT send data to external servers
- Does NOT track your browsing or activity
- Only performs local network diagnostics
