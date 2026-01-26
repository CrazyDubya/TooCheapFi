class Toocheapfi < Formula
  desc "Network connectivity monitor with comprehensive Wi-Fi diagnostics"
  homepage "https://github.com/CrazyDubya/TooCheapFi"
  url "https://github.com/CrazyDubya/TooCheapFi/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/CrazyDubya/TooCheapFi.git", branch: "main"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build",
           "--configuration", "release",
           "--disable-sandbox",
           "-Xswiftc", "-target",
           "-Xswiftc", "arm64-apple-macosx12.0"

    # Create the app bundle structure
    app_bundle = buildpath/"TooCheapFi.app"
    mkdir_p app_bundle/"Contents/MacOS"
    mkdir_p app_bundle/"Contents/Resources"

    # Copy the binary
    cp ".build/release/TooCheapFi", app_bundle/"Contents/MacOS/TooCheapFi"

    # Create Info.plist
    (app_bundle/"Contents/Info.plist").write <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>TooCheapFi</string>
        <key>CFBundleIconFile</key>
        <string>AppIcon</string>
        <key>CFBundleIdentifier</key>
        <string>com.crazydubya.toocheapfi</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>TooCheapFi</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>#{version}</string>
        <key>CFBundleVersion</key>
        <string>#{version}</string>
        <key>LSMinimumSystemVersion</key>
        <string>12.0</string>
        <key>LSUIElement</key>
        <true/>
        <key>NSHighResolutionCapable</key>
        <true/>
        <key>NSPrincipalClass</key>
        <string>NSApplication</string>
      </dict>
      </plist>
    PLIST

    # Install the app bundle to Applications via cask-like behavior
    prefix.install app_bundle

    # Also install the binary to bin for CLI access
    bin.install_symlink prefix/"TooCheapFi.app/Contents/MacOS/TooCheapFi" => "toocheapfi"
  end

  def caveats
    <<~EOS
      TooCheapFi has been installed as an app bundle.

      To launch:
        open #{prefix}/TooCheapFi.app

      Or use the CLI:
        toocheapfi --help

      To start automatically at login:
        1. Open System Settings > General > Login Items
        2. Click + and add TooCheapFi.app

      Note: TooCheapFi requires Location Services permission to scan
      for nearby Wi-Fi networks (for channel analysis). You may be
      prompted to grant this permission on first launch.
    EOS
  end

  test do
    assert_match "TooCheapFi 1.0.0", shell_output("#{bin}/toocheapfi --version")
  end
end
