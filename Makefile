.PHONY: build clean run

build:
	swift build -c release

clean:
	swift package clean
	rm -rf .build

run: build
	./.build/release/TooCheapFi

install: build
	cp ./.build/release/TooCheapFi /usr/local/bin/toocheapfi

help:
	@echo "TooCheapFi - Network Monitor for macOS"
	@echo ""
	@echo "Available targets:"
	@echo "  build    - Build the application"
	@echo "  clean    - Clean build artifacts"
	@echo "  run      - Build and run the application"
	@echo "  install  - Install to /usr/local/bin"
	@echo "  help     - Show this help message"
