import Foundation
import SQLite3

public class HistoryStore {
    public static let shared = HistoryStore()

    private var db: OpaquePointer?
    private let dbPath: String
    private var currentOutageId: Int64?
    private var outageStartTime: Date?
    private let dbQueue = DispatchQueue(label: "com.toocheapfi.database", qos: .utility)

    public init() {
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

    /// Returns detailed SQLite error message
    private func sqliteErrorMessage() -> String {
        if let db = db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "Database not open"
    }

    // MARK: - Record Events

    public func recordStatus(_ status: NetworkStatus) {
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
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logError("Failed to prepare recordStatus: \(self.sqliteErrorMessage())")
                return
            }
            defer { sqlite3_finalize(stmt) }

            var bindResult = SQLITE_OK
            bindResult = sqlite3_bind_text(stmt, 1, status.interfaceType.rawValue, -1, nil)
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 2, status.wifiConnected ? 1 : 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 3, status.gatewayReachable ? 1 : 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 4, status.internetReachable ? 1 : 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 5, status.dnsWorking ? 1 : 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 6, status.httpWorking ? 1 : 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 7, status.captivePortalDetected ? 1 : 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 8, Int32(status.wifiInfo?.rssi ?? 0)) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 9, Int32(status.wifiInfo?.snr ?? 0)) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_double(stmt, 10, status.internetLatency ?? 0) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_int(stmt, 11, Int32(status.qualityScore)) : bindResult
            bindResult = bindResult == SQLITE_OK ? sqlite3_bind_text(stmt, 12, errorLayer, -1, nil) : bindResult

            if bindResult != SQLITE_OK {
                logError("Failed to bind parameters for recordStatus: \(bindResult)")
                return
            }

            let stepResult = sqlite3_step(stmt)
            if stepResult != SQLITE_DONE {
                logError("Failed to execute recordStatus: \(stepResult)")
            }

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
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare startOutage: \(sqliteErrorMessage())")
            return -1
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, layer, -1, nil)
        sqlite3_bind_text(stmt, 2, cause, -1, nil)

        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE {
            logError("Failed to execute startOutage: \(sqliteErrorMessage())")
            return -1
        }

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
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare endOutage: \(sqliteErrorMessage())")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, id)

        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE {
            logError("Failed to execute endOutage: \(sqliteErrorMessage())")
        }
    }

    // MARK: - Record Speed Test

    public func recordSpeedTest(_ result: SpeedTestResult) {
        guard Preferences.shared.historyEnabled else { return }

        let sql = """
        INSERT INTO speed_tests (download_speed, upload_speed, server)
        VALUES (?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare recordSpeedTest: \(sqliteErrorMessage())")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, result.downloadSpeed ?? 0)
        sqlite3_bind_double(stmt, 2, result.uploadSpeed ?? 0)
        sqlite3_bind_text(stmt, 3, result.testServer, -1, nil)

        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE {
            logError("Failed to execute recordSpeedTest: \(sqliteErrorMessage())")
        }
    }

    // MARK: - Query History

    public struct OutageRecord {
        public let id: Int64
        public let startTime: String
        public let endTime: String?
        public let durationSeconds: Int?
        public let affectedLayer: String
        public let cause: String?
        public let resolved: Bool

        public init(
            id: Int64,
            startTime: String,
            endTime: String?,
            durationSeconds: Int?,
            affectedLayer: String,
            cause: String?,
            resolved: Bool
        ) {
            self.id = id
            self.startTime = startTime
            self.endTime = endTime
            self.durationSeconds = durationSeconds
            self.affectedLayer = affectedLayer
            self.cause = cause
            self.resolved = resolved
        }
    }

    public func getRecentOutages(limit: Int = 10) -> [OutageRecord] {
        let sql = """
        SELECT id, start_time, end_time, duration_seconds, affected_layer, cause, resolved
        FROM outages
        ORDER BY start_time DESC
        LIMIT ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare getRecentOutages: \(sqliteErrorMessage())")
            return []
        }
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

    public func getUptimePercentage(hours: Int = 24) -> Double {
        let sql = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN error_layer IS NULL THEN 1 ELSE 0 END) as up
        FROM events
        WHERE timestamp > datetime('now', ? || ' hours', 'localtime');
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare getUptimePercentage: \(sqliteErrorMessage())")
            return 100
        }
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

    public func getTotalOutageTime(hours: Int = 24) -> Int {
        let sql = """
        SELECT COALESCE(SUM(duration_seconds), 0)
        FROM outages
        WHERE start_time > datetime('now', ? || ' hours', 'localtime')
        AND resolved = 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare getTotalOutageTime: \(sqliteErrorMessage())")
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        let hoursParam = "-\(hours)"
        sqlite3_bind_text(stmt, 1, hoursParam, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }

        return 0
    }

    // MARK: - Export

    /// Streams CSV export directly to file (memory efficient for large datasets)
    public func streamExportToCSV(to url: URL) throws {
        // Create or truncate file
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        // Write header
        let header = "Timestamp,Interface,Gateway,Internet,DNS,HTTP,RSSI,SNR,Latency,Quality,Error\n"
        handle.write(header.data(using: .utf8)!)

        let sql = """
        SELECT timestamp, interface_type, gateway_reachable, internet_reachable,
               dns_working, http_working, rssi, snr, latency_ms, quality_score, error_layer
        FROM events
        ORDER BY timestamp DESC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "HistoryStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to prepare query: \(sqliteErrorMessage())"
            ])
        }
        defer { sqlite3_finalize(stmt) }

        var rowCount = 0
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

            let row = "\(timestamp),\(interface),\(gateway),\(internet),\(dns),\(http),\(rssi),\(snr),\(latency),\(quality),\(error)\n"
            handle.write(row.data(using: .utf8)!)
            rowCount += 1
        }

        logInfo("Exported \(rowCount) rows to \(url.path)")
    }

    public func exportToCSV() -> String {
        var csv = "Timestamp,Interface,Gateway,Internet,DNS,HTTP,RSSI,SNR,Latency,Quality,Error\n"

        let sql = """
        SELECT timestamp, interface_type, gateway_reachable, internet_reachable,
               dns_working, http_working, rssi, snr, latency_ms, quality_score, error_layer
        FROM events
        ORDER BY timestamp DESC
        LIMIT 1000;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare exportToCSV: \(sqliteErrorMessage())")
            return csv
        }
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

    public func exportOutagesToCSV() -> String {
        var csv = "Start Time,End Time,Duration (s),Affected Layer,Cause,Resolved\n"

        let sql = """
        SELECT start_time, end_time, duration_seconds, affected_layer, cause, resolved
        FROM outages
        ORDER BY start_time DESC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare exportOutagesToCSV: \(sqliteErrorMessage())")
            return csv
        }
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
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("Failed to prepare cleanup for \(table): \(sqliteErrorMessage())")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, daysParam, -1, nil)

        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE {
            logError("Failed to cleanup \(table): \(sqliteErrorMessage())")
        }
    }
}
