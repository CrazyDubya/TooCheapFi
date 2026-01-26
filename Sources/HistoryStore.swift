import Foundation
import SQLite3

class HistoryStore {
    static let shared = HistoryStore()

    private var db: OpaquePointer?
    private let dbPath: String
    private var currentOutageId: Int64?
    private var outageStartTime: Date?
    private let dbQueue = DispatchQueue(label: "com.toocheapfi.database", qos: .utility)

    init() {
        dbPath = Preferences.historyPath.path

        dbQueue.sync {
            guard sqlite3_open(self.dbPath, &self.db) == SQLITE_OK else {
                logError("Failed to open database at \(self.dbPath)")
                return
            }
        }

        createTables()
        cleanupOldRecords()
    }

    deinit {
        dbQueue.sync {
            if db != nil {
                sqlite3_close(db)
            }
        }
    }

    // MARK: - Schema

    private func createTables() {
        let createEventsSQL = """
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
            interface_type TEXT,
            wifi_connected INTEGER,
            gateway_reachable INTEGER,
            internet_reachable INTEGER,
            dns_working INTEGER,
            http_working INTEGER,
            captive_portal INTEGER,
            rssi INTEGER,
            snr INTEGER,
            latency_ms REAL,
            quality_score INTEGER,
            error_layer TEXT
        );
        """

        let createOutagesSQL = """
        CREATE TABLE IF NOT EXISTS outages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time TEXT NOT NULL,
            end_time TEXT,
            duration_seconds INTEGER,
            affected_layer TEXT,
            cause TEXT,
            resolved INTEGER DEFAULT 0
        );
        """

        let createSpeedTestsSQL = """
        CREATE TABLE IF NOT EXISTS speed_tests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
            download_speed REAL,
            upload_speed REAL,
            server TEXT
        );
        """

        let createIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_outages_start ON outages(start_time);
        """

        executeSQL(createEventsSQL)
        executeSQL(createOutagesSQL)
        executeSQL(createSpeedTestsSQL)
        executeSQL(createIndexSQL)
    }

    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                logError("SQL Error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Record Events

    func recordStatus(_ status: NetworkStatus) {
        guard Preferences.shared.historyEnabled else { return }

        let errorLayer = determineErrorLayer(status)

        dbQueue.async { [weak self] in
            guard let self = self else { return }

            let sql = """
            INSERT INTO events (
                interface_type, wifi_connected, gateway_reachable, internet_reachable,
                dns_working, http_working, captive_portal, rssi, snr, latency_ms,
                quality_score, error_layer
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, status.interfaceType.rawValue, -1, nil)
            sqlite3_bind_int(stmt, 2, status.wifiConnected ? 1 : 0)
            sqlite3_bind_int(stmt, 3, status.gatewayReachable ? 1 : 0)
            sqlite3_bind_int(stmt, 4, status.internetReachable ? 1 : 0)
            sqlite3_bind_int(stmt, 5, status.dnsWorking ? 1 : 0)
            sqlite3_bind_int(stmt, 6, status.httpWorking ? 1 : 0)
            sqlite3_bind_int(stmt, 7, status.captivePortalDetected ? 1 : 0)
            sqlite3_bind_int(stmt, 8, Int32(status.wifiInfo?.rssi ?? 0))
            sqlite3_bind_int(stmt, 9, Int32(status.wifiInfo?.snr ?? 0))
            sqlite3_bind_double(stmt, 10, status.internetLatency ?? 0)
            sqlite3_bind_int(stmt, 11, Int32(status.qualityScore))
            sqlite3_bind_text(stmt, 12, errorLayer, -1, nil)

            sqlite3_step(stmt)

            // Track outages
            self.handleOutageTracking(status, errorLayer: errorLayer)
        }
    }

    private func determineErrorLayer(_ status: NetworkStatus) -> String? {
        if status.interfaceType == .none { return "interface" }
        if !status.gatewayReachable { return "gateway" }
        if !status.internetReachable { return "internet" }
        if status.captivePortalDetected { return "captive_portal" }
        if !status.dnsWorking { return "dns" }
        if !status.httpWorking { return "http" }
        return nil
    }

    private func handleOutageTracking(_ status: NetworkStatus, errorLayer: String?) {
        let isDown = errorLayer != nil

        if isDown && currentOutageId == nil {
            // Start new outage
            let startTime = Date()
            outageStartTime = startTime
            let layer = errorLayer ?? "unknown"
            currentOutageId = startOutage(layer: layer, cause: status.issues.first?.description)

            // Fire event hook
            EventHookManager.shared.notifyOutageStarted(layer: layer, time: startTime)
        } else if !isDown, let outageId = currentOutageId {
            // End outage
            let duration = Date().timeIntervalSince(outageStartTime ?? Date())
            endOutage(id: outageId)

            // Fire event hook
            EventHookManager.shared.notifyOutageEnded(layer: "recovered", duration: duration)

            currentOutageId = nil
            outageStartTime = nil
        }
    }

    private func startOutage(layer: String, cause: String?) -> Int64 {
        let sql = """
        INSERT INTO outages (start_time, affected_layer, cause)
        VALUES (datetime('now', 'localtime'), ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, layer, -1, nil)
        sqlite3_bind_text(stmt, 2, cause, -1, nil)
        sqlite3_step(stmt)

        return sqlite3_last_insert_rowid(db)
    }

    private func endOutage(id: Int64) {
        let sql = """
        UPDATE outages SET
            end_time = datetime('now', 'localtime'),
            duration_seconds = CAST((julianday(datetime('now', 'localtime')) - julianday(start_time)) * 86400 AS INTEGER),
            resolved = 1
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
    }

    // MARK: - Record Speed Test

    func recordSpeedTest(_ result: SpeedTestResult) {
        guard Preferences.shared.historyEnabled else { return }

        let sql = """
        INSERT INTO speed_tests (download_speed, upload_speed, server)
        VALUES (?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, result.downloadSpeed ?? 0)
        sqlite3_bind_double(stmt, 2, result.uploadSpeed ?? 0)
        sqlite3_bind_text(stmt, 3, result.testServer, -1, nil)
        sqlite3_step(stmt)
    }

    // MARK: - Query History

    struct OutageRecord {
        let id: Int64
        let startTime: String
        let endTime: String?
        let durationSeconds: Int?
        let affectedLayer: String
        let cause: String?
        let resolved: Bool
    }

    func getRecentOutages(limit: Int = 10) -> [OutageRecord] {
        let sql = """
        SELECT id, start_time, end_time, duration_seconds, affected_layer, cause, resolved
        FROM outages
        ORDER BY start_time DESC
        LIMIT ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var outages: [OutageRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let outage = OutageRecord(
                id: sqlite3_column_int64(stmt, 0),
                startTime: String(cString: sqlite3_column_text(stmt, 1)),
                endTime: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                durationSeconds: sqlite3_column_type(stmt, 3) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 3)) : nil,
                affectedLayer: String(cString: sqlite3_column_text(stmt, 4)),
                cause: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                resolved: sqlite3_column_int(stmt, 6) == 1
            )
            outages.append(outage)
        }

        return outages
    }

    func getUptimePercentage(hours: Int = 24) -> Double {
        let sql = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN error_layer IS NULL THEN 1 ELSE 0 END) as up
        FROM events
        WHERE timestamp > datetime('now', ? || ' hours', 'localtime');
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 100 }
        defer { sqlite3_finalize(stmt) }

        let hoursParam = "-\(hours)"
        sqlite3_bind_text(stmt, 1, hoursParam, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = sqlite3_column_int(stmt, 0)
            let up = sqlite3_column_int(stmt, 1)
            if total > 0 {
                return Double(up) / Double(total) * 100
            }
        }

        return 100
    }

    func getTotalOutageTime(hours: Int = 24) -> Int {
        let sql = """
        SELECT COALESCE(SUM(duration_seconds), 0)
        FROM outages
        WHERE start_time > datetime('now', ? || ' hours', 'localtime')
        AND resolved = 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        let hoursParam = "-\(hours)"
        sqlite3_bind_text(stmt, 1, hoursParam, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }

        return 0
    }

    // MARK: - Export

    func exportToCSV() -> String {
        var csv = "Timestamp,Interface,Gateway,Internet,DNS,HTTP,RSSI,SNR,Latency,Quality,Error\n"

        let sql = """
        SELECT timestamp, interface_type, gateway_reachable, internet_reachable,
               dns_working, http_working, rssi, snr, latency_ms, quality_score, error_layer
        FROM events
        ORDER BY timestamp DESC
        LIMIT 1000;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return csv }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let timestamp = String(cString: sqlite3_column_text(stmt, 0))
            let interface = String(cString: sqlite3_column_text(stmt, 1))
            let gateway = sqlite3_column_int(stmt, 2)
            let internet = sqlite3_column_int(stmt, 3)
            let dns = sqlite3_column_int(stmt, 4)
            let http = sqlite3_column_int(stmt, 5)
            let rssi = sqlite3_column_int(stmt, 6)
            let snr = sqlite3_column_int(stmt, 7)
            let latency = sqlite3_column_double(stmt, 8)
            let quality = sqlite3_column_int(stmt, 9)
            let error = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""

            csv += "\(timestamp),\(interface),\(gateway),\(internet),\(dns),\(http),\(rssi),\(snr),\(latency),\(quality),\(error)\n"
        }

        return csv
    }

    func exportOutagesToCSV() -> String {
        var csv = "Start Time,End Time,Duration (s),Affected Layer,Cause,Resolved\n"

        let sql = """
        SELECT start_time, end_time, duration_seconds, affected_layer, cause, resolved
        FROM outages
        ORDER BY start_time DESC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return csv }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let start = String(cString: sqlite3_column_text(stmt, 0))
            let end = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "ongoing"
            let duration = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? "\(sqlite3_column_int(stmt, 2))" : "ongoing"
            let layer = String(cString: sqlite3_column_text(stmt, 3))
            let cause = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
            let resolved = sqlite3_column_int(stmt, 5) == 1 ? "yes" : "no"

            csv += "\"\(start)\",\"\(end)\",\(duration),\(layer),\"\(cause)\",\(resolved)\n"
        }

        return csv
    }

    // MARK: - Cleanup

    private func cleanupOldRecords() {
        let retentionDays = Preferences.shared.historyRetentionDays
        let daysParam = "-\(retentionDays) days"

        cleanupTable("events", column: "timestamp", daysParam: daysParam)
        cleanupTable("outages", column: "start_time", daysParam: daysParam, extraCondition: "AND resolved = 1")
        cleanupTable("speed_tests", column: "timestamp", daysParam: daysParam)
    }

    private func cleanupTable(_ table: String, column: String, daysParam: String, extraCondition: String = "") {
        let sql = "DELETE FROM \(table) WHERE \(column) < datetime('now', ?, 'localtime') \(extraCondition);"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, daysParam, -1, nil)
        sqlite3_step(stmt)
    }
}
