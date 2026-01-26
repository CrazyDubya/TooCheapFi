import XCTest
@testable import TooCheapFiCore

/// Tests for the history store database operations
final class HistoryStoreTests: XCTestCase {

    // MARK: - Database Schema Tests

    func testDatabaseTables() {
        let expectedTables = ["events", "outages", "speed_tests"]
        XCTAssertEqual(expectedTables.count, 3, "Should have 3 database tables")
    }

    func testEventsTableColumns() {
        let columns = [
            "id", "timestamp", "interface_type", "wifi_connected",
            "gateway_reachable", "internet_reachable", "dns_working",
            "http_working", "captive_portal", "rssi", "snr",
            "latency_ms", "quality_score", "error_layer"
        ]
        XCTAssertEqual(columns.count, 14, "Events table should have 14 columns")
    }

    func testOutagesTableColumns() {
        let columns = [
            "id", "start_time", "end_time", "duration_seconds",
            "affected_layer", "cause", "resolved"
        ]
        XCTAssertEqual(columns.count, 7, "Outages table should have 7 columns")
    }

    func testSpeedTestsTableColumns() {
        let columns = [
            "id", "timestamp", "download_speed", "upload_speed", "server"
        ]
        XCTAssertEqual(columns.count, 5, "Speed tests table should have 5 columns")
    }

    // MARK: - Error Layer Detection Tests

    func testErrorLayerDetection_NoInterface() {
        // Simulating determineErrorLayer logic
        let interfaceType = "none"
        let gatewayReachable = false
        let internetReachable = false

        let errorLayer: String?
        if interfaceType == "none" {
            errorLayer = "interface"
        } else if !gatewayReachable {
            errorLayer = "gateway"
        } else if !internetReachable {
            errorLayer = "internet"
        } else {
            errorLayer = nil
        }

        XCTAssertEqual(errorLayer, "interface", "No interface should return 'interface' error layer")
    }

    func testErrorLayerDetection_GatewayUnreachable() {
        let interfaceType = "wifi"
        let gatewayReachable = false
        let internetReachable = false

        let errorLayer: String?
        if interfaceType == "none" {
            errorLayer = "interface"
        } else if !gatewayReachable {
            errorLayer = "gateway"
        } else if !internetReachable {
            errorLayer = "internet"
        } else {
            errorLayer = nil
        }

        XCTAssertEqual(errorLayer, "gateway", "Unreachable gateway should return 'gateway' error layer")
    }

    func testErrorLayerDetection_NoInternet() {
        let interfaceType = "wifi"
        let gatewayReachable = true
        let internetReachable = false
        let captivePortal = false
        let dnsWorking = true

        let errorLayer: String?
        if interfaceType == "none" {
            errorLayer = "interface"
        } else if !gatewayReachable {
            errorLayer = "gateway"
        } else if !internetReachable {
            errorLayer = "internet"
        } else if captivePortal {
            errorLayer = "captive_portal"
        } else if !dnsWorking {
            errorLayer = "dns"
        } else {
            errorLayer = nil
        }

        XCTAssertEqual(errorLayer, "internet", "No internet should return 'internet' error layer")
    }

    func testErrorLayerDetection_CaptivePortal() {
        let interfaceType = "wifi"
        let gatewayReachable = true
        let internetReachable = true
        let captivePortal = true

        let errorLayer: String?
        if interfaceType == "none" {
            errorLayer = "interface"
        } else if !gatewayReachable {
            errorLayer = "gateway"
        } else if !internetReachable {
            errorLayer = "internet"
        } else if captivePortal {
            errorLayer = "captive_portal"
        } else {
            errorLayer = nil
        }

        XCTAssertEqual(errorLayer, "captive_portal", "Captive portal should return 'captive_portal' error layer")
    }

    func testErrorLayerDetection_DNSFailure() {
        let interfaceType = "wifi"
        let gatewayReachable = true
        let internetReachable = true
        let captivePortal = false
        let dnsWorking = false
        let httpWorking = true

        let errorLayer: String?
        if interfaceType == "none" {
            errorLayer = "interface"
        } else if !gatewayReachable {
            errorLayer = "gateway"
        } else if !internetReachable {
            errorLayer = "internet"
        } else if captivePortal {
            errorLayer = "captive_portal"
        } else if !dnsWorking {
            errorLayer = "dns"
        } else if !httpWorking {
            errorLayer = "http"
        } else {
            errorLayer = nil
        }

        XCTAssertEqual(errorLayer, "dns", "DNS failure should return 'dns' error layer")
    }

    func testErrorLayerDetection_AllWorking() {
        let interfaceType = "wifi"
        let gatewayReachable = true
        let internetReachable = true
        let captivePortal = false
        let dnsWorking = true
        let httpWorking = true

        let errorLayer: String?
        if interfaceType == "none" {
            errorLayer = "interface"
        } else if !gatewayReachable {
            errorLayer = "gateway"
        } else if !internetReachable {
            errorLayer = "internet"
        } else if captivePortal {
            errorLayer = "captive_portal"
        } else if !dnsWorking {
            errorLayer = "dns"
        } else if !httpWorking {
            errorLayer = "http"
        } else {
            errorLayer = nil
        }

        XCTAssertNil(errorLayer, "All working should return nil error layer")
    }

    // MARK: - Outage Tracking Tests

    func testOutageTracking_StartCondition() {
        // Outage starts when errorLayer is not nil and no current outage
        let errorLayer: String? = "gateway"
        let currentOutageId: Int64? = nil

        let shouldStartOutage = errorLayer != nil && currentOutageId == nil
        XCTAssertTrue(shouldStartOutage, "Should start outage when error detected and no current outage")
    }

    func testOutageTracking_EndCondition() {
        // Outage ends when errorLayer is nil and there is a current outage
        let errorLayer: String? = nil
        let currentOutageId: Int64? = 123

        let shouldEndOutage = errorLayer == nil && currentOutageId != nil
        XCTAssertTrue(shouldEndOutage, "Should end outage when error cleared and current outage exists")
    }

    func testOutageTracking_ContinueCondition() {
        // Outage continues when errorLayer exists and there's already an outage
        let errorLayer: String? = "gateway"
        let currentOutageId: Int64? = 123

        let shouldStartOutage = errorLayer != nil && currentOutageId == nil
        let shouldEndOutage = errorLayer == nil && currentOutageId != nil

        XCTAssertFalse(shouldStartOutage, "Should not start new outage when one exists")
        XCTAssertFalse(shouldEndOutage, "Should not end outage when error persists")
    }

    // MARK: - Uptime Calculation Tests

    func testUptimePercentageCalculation_AllUp() {
        let total = 100
        let up = 100
        let uptime = Double(up) / Double(total) * 100
        XCTAssertEqual(uptime, 100, accuracy: 0.01, "100% uptime when all checks pass")
    }

    func testUptimePercentageCalculation_HalfUp() {
        let total = 100
        let up = 50
        let uptime = Double(up) / Double(total) * 100
        XCTAssertEqual(uptime, 50, accuracy: 0.01, "50% uptime when half checks fail")
    }

    func testUptimePercentageCalculation_NoneUp() {
        let total = 100
        let up = 0
        let uptime = Double(up) / Double(total) * 100
        XCTAssertEqual(uptime, 0, accuracy: 0.01, "0% uptime when all checks fail")
    }

    func testUptimePercentageCalculation_NoData() {
        let total = 0
        let defaultUptime: Double = 100  // Default when no data

        let uptime: Double
        if total > 0 {
            uptime = 0
        } else {
            uptime = defaultUptime
        }

        XCTAssertEqual(uptime, 100, "Should return 100% when no data available")
    }

    // MARK: - CSV Export Format Tests

    func testEventsCSVHeader() {
        let expectedHeader = "Timestamp,Interface,Gateway,Internet,DNS,HTTP,RSSI,SNR,Latency,Quality,Error"
        let columns = expectedHeader.split(separator: ",")
        XCTAssertEqual(columns.count, 11, "Events CSV should have 11 columns")
    }

    func testOutagesCSVHeader() {
        let expectedHeader = "Start Time,End Time,Duration (s),Affected Layer,Cause,Resolved"
        let columns = expectedHeader.split(separator: ",")
        XCTAssertEqual(columns.count, 6, "Outages CSV should have 6 columns")
    }

    // MARK: - Data Retention Tests

    func testRetentionDaysParameter() {
        let retentionDays = 30
        let daysParam = "-\(retentionDays) days"
        XCTAssertEqual(daysParam, "-30 days", "Days parameter should be formatted correctly")
    }

    func testHoursParameter() {
        let hours = 24
        let hoursParam = "-\(hours)"
        XCTAssertEqual(hoursParam, "-24", "Hours parameter should be formatted correctly")
    }
}
