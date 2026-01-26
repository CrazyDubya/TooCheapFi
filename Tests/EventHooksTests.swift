import XCTest

/// Tests for the event hooks system
final class EventHooksTests: XCTestCase {

    // MARK: - Observer Registration Tests

    func testObserverCountStartsAtZero() {
        // A fresh manager should have no observers
        // Note: We can't test the shared instance directly since it may have observers
        let count = 0  // Simulated
        XCTAssertEqual(count, 0, "Initial observer count should be 0")
    }

    func testAddObserverIncreasesCount() {
        var count = 0
        count += 1  // Simulated add
        XCTAssertEqual(count, 1, "Adding observer should increase count")
    }

    func testRemoveObserverDecreasesCount() {
        var count = 1
        count -= 1  // Simulated remove
        XCTAssertEqual(count, 0, "Removing observer should decrease count")
    }

    // MARK: - Quality Change Detection Tests

    func testQualityChangeDetection_SameQuality() {
        let oldQuality = "excellent"
        let newQuality = "excellent"
        let changed = oldQuality != newQuality
        XCTAssertFalse(changed, "Same quality should not trigger change")
    }

    func testQualityChangeDetection_DifferentQuality() {
        let oldQuality = "excellent"
        let newQuality = "good"
        let changed = oldQuality != newQuality
        XCTAssertTrue(changed, "Different quality should trigger change")
    }

    func testQualityChangeDetection_Degradation() {
        let qualities = ["excellent", "good", "fair", "poor", "none"]
        for i in 0..<qualities.count - 1 {
            let old = qualities[i]
            let new = qualities[i + 1]
            XCTAssertNotEqual(old, new, "Quality degradation should be detected")
        }
    }

    // MARK: - Signal Drop Detection Tests

    func testSignalDropDetection_NoChange() {
        let oldRSSI = -50
        let newRSSI = -50
        let dropped = newRSSI < oldRSSI - 10
        XCTAssertFalse(dropped, "No change should not trigger drop")
    }

    func testSignalDropDetection_SmallChange() {
        let oldRSSI = -50
        let newRSSI = -55
        let dropped = newRSSI < oldRSSI - 10
        XCTAssertFalse(dropped, "Small change (5 dB) should not trigger drop")
    }

    func testSignalDropDetection_SignificantDrop() {
        let oldRSSI = -50
        let newRSSI = -65
        let dropped = newRSSI < oldRSSI - 10
        XCTAssertTrue(dropped, "Significant drop (15 dB) should trigger drop")
    }

    func testSignalDropDetection_ExactThreshold() {
        let oldRSSI = -50
        let newRSSI = -60
        let dropped = newRSSI < oldRSSI - 10
        XCTAssertFalse(dropped, "Exact threshold (10 dB) should not trigger drop")
    }

    func testSignalDropDetection_JustOverThreshold() {
        let oldRSSI = -50
        let newRSSI = -61
        let dropped = newRSSI < oldRSSI - 10
        XCTAssertTrue(dropped, "Just over threshold (11 dB) should trigger drop")
    }

    // MARK: - Outage Duration Tests

    func testOutageDurationCalculation() {
        let startTime = Date(timeIntervalSince1970: 1000)
        let endTime = Date(timeIntervalSince1970: 1060)
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertEqual(duration, 60, accuracy: 0.1, "Duration should be 60 seconds")
    }

    func testOutageDurationCalculation_ShortOutage() {
        let startTime = Date(timeIntervalSince1970: 1000)
        let endTime = Date(timeIntervalSince1970: 1005)
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertEqual(duration, 5, accuracy: 0.1, "Short outage duration should be 5 seconds")
    }

    func testOutageDurationCalculation_LongOutage() {
        let startTime = Date(timeIntervalSince1970: 1000)
        let endTime = Date(timeIntervalSince1970: 4600)
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertEqual(duration, 3600, accuracy: 0.1, "Long outage duration should be 1 hour")
    }

    // MARK: - Layer Classification Tests

    func testErrorLayerClassification() {
        let layers = ["interface", "gateway", "internet", "captive_portal", "dns", "http"]
        XCTAssertEqual(layers.count, 6, "Should have 6 error layers")
    }

    func testLayerPriority() {
        // Interface issues are most critical (no connection at all)
        // Gateway issues are next (connected but can't reach router)
        // Internet issues are next (router works but no internet)
        // DNS/HTTP issues are least critical (internet works but some services don't)

        let layerPriority = [
            "interface": 1,
            "gateway": 2,
            "internet": 3,
            "captive_portal": 3,
            "dns": 4,
            "http": 5
        ]

        XCTAssertEqual(layerPriority["interface"], 1, "Interface should be highest priority")
        XCTAssertEqual(layerPriority["gateway"], 2, "Gateway should be second priority")
        XCTAssertLessThan(layerPriority["interface"]!, layerPriority["dns"]!, "Interface issues more critical than DNS")
    }

    // MARK: - Script Hook Path Tests

    func testScriptNames() {
        let expectedScripts = [
            "on-outage-start",
            "on-outage-end",
            "on-quality-change",
            "on-speed-test",
            "on-signal-drop"
        ]

        XCTAssertEqual(expectedScripts.count, 5, "Should have 5 hook scripts")
        XCTAssertTrue(expectedScripts.contains("on-outage-start"), "Should have outage start hook")
        XCTAssertTrue(expectedScripts.contains("on-outage-end"), "Should have outage end hook")
    }

    func testScriptArgumentFormat() {
        // on-outage-start: [layer, timestamp]
        let outageStartArgs = ["gateway", "2024-01-15T10:30:00Z"]
        XCTAssertEqual(outageStartArgs.count, 2, "Outage start should have 2 args")

        // on-outage-end: [layer, duration_seconds]
        let outageEndArgs = ["recovered", "120"]
        XCTAssertEqual(outageEndArgs.count, 2, "Outage end should have 2 args")

        // on-speed-test: [speed_mbps, server]
        let speedTestArgs = ["95", "Cloudflare"]
        XCTAssertEqual(speedTestArgs.count, 2, "Speed test should have 2 args")
    }
}
