# Building TooCheapFi on macOS

This document provides detailed instructions for building and running TooCheapFi on macOS.

## Prerequisites

- **macOS 13.0 (Ventura) or later**
- **Xcode Command Line Tools** (includes Swift compiler)
- **Swift 5.9 or later**

### Installing Xcode Command Line Tools

If you don't have Xcode Command Line Tools installed:

```bash
xcode-select --install
```

Verify Swift is installed:

```bash
swift --version
```

You should see something like:
```
Apple Swift version 5.9.x (swiftlang-x.x.x.x clang-x.x.x.x)
Target: arm64-apple-macosx13.0
```

## Building the App

### Option 1: Using Make (Recommended)

```bash
# Clone the repository
git clone https://github.com/CrazyDubya/TooCheapFi.git
cd TooCheapFi

# Build release version
make build

# Run the app
make run
```

### Option 2: Using Swift Package Manager directly

```bash
# Debug build
swift build

# Release build (optimized)
swift build -c release

# Run debug version
swift run

# Run release version
./.build/release/TooCheapFi
```

## Installing System-wide

After building, you can install the app to `/usr/local/bin`:

```bash
make install
```

Then run from anywhere:

```bash
toocheapfi
```

## Build Output

The built executable will be located at:
- **Debug**: `./.build/debug/TooCheapFi`
- **Release**: `./.build/release/TooCheapFi`

## Troubleshooting Build Issues

### Issue: "No such module 'Cocoa'"

**Cause**: You're trying to build on a non-macOS system (Linux, Windows, etc.)

**Solution**: This app can only be built on macOS as it uses macOS-specific frameworks.

### Issue: Swift version too old

**Cause**: Your Swift version is older than 5.9

**Solution**: Update Xcode or install a newer version of Swift toolchain from swift.org

### Issue: Build succeeds but app won't run

**Cause**: You may be running an older version of macOS

**Solution**: Ensure you're running macOS 13.0 (Ventura) or later. Check with:
```bash
sw_vers
```

### Issue: Permission errors when installing

**Cause**: `/usr/local/bin` requires elevated permissions

**Solution**: Use sudo:
```bash
sudo make install
```

## Running the App

Once built, simply run the executable:

```bash
./.build/release/TooCheapFi
```

The app will:
1. Start in the background
2. Create an icon in your menu bar (top-right of screen)
3. Begin monitoring your network connection
4. Update status every 5 seconds

## Development Build

For development with faster compile times:

```bash
swift build  # No -c release flag
swift run    # Builds and runs in debug mode
```

## Clean Build

To remove all build artifacts:

```bash
make clean
# or
swift package clean
```

## Next Steps

After building successfully:
1. Check the menu bar for the Wi-Fi icon
2. Click the icon to see your network status
3. Read the main README.md for usage instructions
4. Report any issues on GitHub

## Platform Notes

This is a **macOS-only** application because it uses:
- `Cocoa` framework for menu bar integration
- `SystemConfiguration` for network information
- macOS-specific system calls for network diagnostics

It cannot be built or run on Linux, Windows, or other operating systems.
