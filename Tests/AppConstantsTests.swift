import XCTest
@testable import TooCheapFiCore

/// Tests for application constants
final class AppConstantsTests: XCTestCase {

    // MARK: - Version Tests

    func testVersionFormat() {
        let version = AppConstants.version
        // Should be semver format: major.minor.patch
        let components = version.split(separator: ".")
        XCTAssertEqual(components.count, 3, "Version should have 3 components")
    }

    func testVersionString() {
        let versionString = AppConstants.versionString
        XCTAssertTrue(versionString.contains(AppConstants.appName))
        XCTAssertTrue(versionString.contains(AppConstants.version))
    }

    func testAppName() {
        XCTAssertEqual(AppConstants.appName, "TooCheapFi")
    }

    func testBundleIdentifier() {
        XCTAssertEqual(AppConstants.bundleIdentifier, "com.toocheapfi")
        XCTAssertFalse(AppConstants.bundleIdentifier.contains(" "))
    }

    // MARK: - URL Tests

    func testCaptivePortalURL() {
        let url = AppConstants.captivePortalURL
        XCTAssertTrue(url.hasPrefix("http://"), "Captive portal should use HTTP (not HTTPS)")
        XCTAssertTrue(url.contains("apple.com"))
    }

    func testSpeedTestBaseURL() {
        let url = AppConstants.speedTestBaseURL
        XCTAssertTrue(url.hasPrefix("https://"), "Speed test should use HTTPS")
        XCTAssertTrue(url.contains("cloudflare.com"))
        XCTAssertTrue(url.contains("bytes="), "Should have bytes parameter")
    }

    func testDefaultISPTargets() {
        let targets = AppConstants.defaultISPTargets
        XCTAssertEqual(targets.count, 3)
        XCTAssertTrue(targets.contains("8.8.8.8"), "Should include Google DNS")
        XCTAssertTrue(targets.contains("1.1.1.1"), "Should include Cloudflare DNS")
    }

    func testDefaultDNSTestDomains() {
        let domains = AppConstants.defaultDNSTestDomains
        XCTAssertGreaterThanOrEqual(domains.count, 3)
        for domain in domains {
            XCTAssertTrue(domain.contains("."), "Domain should contain a dot")
            XCTAssertFalse(domain.hasPrefix("http"), "Domain should not have protocol")
        }
    }

    // MARK: - Threshold Tests

    func testSignalDropThreshold() {
        let threshold = AppConstants.signalDropThreshold
        XCTAssertGreaterThan(threshold, 0)
        XCTAssertLessThanOrEqual(threshold, 20, "Signal drop threshold should be reasonable")
    }

    // MARK: - Display Limit Tests

    func testMaxDisplayChannels() {
        let limit = AppConstants.maxDisplayChannels
        XCTAssertGreaterThan(limit, 0)
        XCTAssertLessThanOrEqual(limit, 20)
    }

    func testMaxDisplayIssues() {
        let limit = AppConstants.maxDisplayIssues
        XCTAssertGreaterThan(limit, 0)
        XCTAssertLessThanOrEqual(limit, 10)
    }

    func testMaxDisplayRecommendations() {
        let limit = AppConstants.maxDisplayRecommendations
        XCTAssertGreaterThan(limit, 0)
        XCTAssertLessThanOrEqual(limit, 10)
    }

    func testMaxRecommendationSteps() {
        let limit = AppConstants.maxRecommendationSteps
        XCTAssertGreaterThan(limit, 0)
        XCTAssertLessThanOrEqual(limit, 5)
    }

    // MARK: - Consistency Tests

    func testExpectedCaptivePortalResponse() {
        let response = AppConstants.captivePortalExpectedResponse
        XCTAssertTrue(response.contains("Success"))
        XCTAssertTrue(response.contains("HTML"))
    }
}
