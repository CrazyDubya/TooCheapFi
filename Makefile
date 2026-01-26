.PHONY: build clean run app install help

build:
	swift build -c release

clean:
	swift package clean
	rm -rf .build
	rm -rf TooCheapFi.app

run: build
	./.build/release/TooCheapFi

app: build
	@echo "Creating app bundle..."
	@mkdir -p TooCheapFi.app/Contents/MacOS
	@mkdir -p TooCheapFi.app/Contents/Resources
	@cp .build/release/TooCheapFi TooCheapFi.app/Contents/MacOS/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > TooCheapFi.app/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> TooCheapFi.app/Contents/Info.plist
	@echo '<plist version="1.0">' >> TooCheapFi.app/Contents/Info.plist
	@echo '<dict>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleDevelopmentRegion</key><string>en</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleExecutable</key><string>TooCheapFi</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleIdentifier</key><string>com.crazydubya.toocheapfi</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleName</key><string>TooCheapFi</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundlePackageType</key><string>APPL</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleShortVersionString</key><string>1.0.0</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>CFBundleVersion</key><string>1.0.0</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>LSMinimumSystemVersion</key><string>12.0</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>LSUIElement</key><true/>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>NSHighResolutionCapable</key><true/>' >> TooCheapFi.app/Contents/Info.plist
	@echo '  <key>NSPrincipalClass</key><string>NSApplication</string>' >> TooCheapFi.app/Contents/Info.plist
	@echo '</dict>' >> TooCheapFi.app/Contents/Info.plist
	@echo '</plist>' >> TooCheapFi.app/Contents/Info.plist
	@echo "Created TooCheapFi.app"

install: build
	cp ./.build/release/TooCheapFi /usr/local/bin/toocheapfi

help:
	@echo "TooCheapFi - Network Monitor for macOS"
	@echo ""
	@echo "Available targets:"
	@echo "  build    - Build the application (release)"
	@echo "  clean    - Clean build artifacts"
	@echo "  run      - Build and run the application"
	@echo "  app      - Create macOS app bundle"
	@echo "  install  - Install to /usr/local/bin"
	@echo "  help     - Show this help message"
