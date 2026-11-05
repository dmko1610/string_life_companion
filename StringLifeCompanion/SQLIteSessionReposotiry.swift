import Foundation
import SQLite3

enum SQLiteRepositoryError: LocalizedError {
    case open(String)
    case database(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .open(let message):
            return "Could not open session database: \(message)"
        case .database(let message):
            return "Database error: \(message)"
        case .invalidData(let message):
            return "Invalid session data: \(message)"
        }
    }
}

@MainActor
final class SQLiteSessionRepository: SessionRepository {
    private var database: OpaquePointer?

    convenience init() throws {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appDirectory = supportURL.appendingPathComponent(
            "StringLifeCompanion",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )

        let databaseURL = appDirectory.appendingPathComponent("sessions.sqlite")
        try self.init(databaseURL: databaseURL)
    }

    init(databaseURL: URL) throws {
        var openedDatabase: OpaquePointer?

        let result = sqlite3_open(databaseURL.path, &openedDatabase)

        guard result == SQLITE_OK, let openedDatabase else {
            let message: String

            if let openedDatabase {
                message = String(cString: sqlite3_errmsg(openedDatabase))
                sqlite3_close(openedDatabase)
            } else {
                message = "SQLite could not create a database connection."
            }

            throw SQLiteRepositoryError.open(message)
        }

        database = openedDatabase

        do {
            try createSchema()
        } catch {
            sqlite3_close(openedDatabase)
            database = nil
            throw error
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func loadActiveSession() throws -> PlayingSession? {
        let statement = try prepare(
            """
            SELECT id, started_at, ended_at, status,
                    amplifier_ids_json, last_observed_at,
                    timing_is_approximate
            FROM sessions
            WHERE status = 'active'
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }

        let result = sqlite3_step(statement)

        if result == SQLITE_DONE {
            return nil
        }

        guard result == SQLITE_ROW else {
            throw currentDatabaseError()
        }

        return try decodeSession(from: statement)
    }

    func save(_ session: PlayingSession) throws {
        let statement = try prepare(
            """
            INSERT INTO sessions (
             id, started_at, ended_at, status, amplifier_ids_json, last_observed_at, timing_is_approximate 
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                started_at = excluded.started_at,
                ended_at = excluded.ended_at,
                status = excluded.status,
                amplifier_ids_json = excluded.amplifier_ids_json,
                last_observed_at = excluded.last_observed_at,
                timing_is_approximate = excluded.timing_is_approximate;
            """
        )
        defer { sqlite3_finalize(statement) }

        let amplifierData: Data

        do {
            amplifierData = try JSONEncoder().encode(session.amplifierBundleIDs)
        } catch {
            throw SQLiteRepositoryError.invalidData(
                "Could not convert amplifier IDs to text."
            )
        }

        guard let amplifierJSON = String(data: amplifierData, encoding: .utf8)
        else {
            throw SQLiteRepositoryError.invalidData(
                "Could not convert amplifier IDs to text."
            )
        }

        try bind(session.id.uuidString, to: statement, at: 1)

        try checkSQLite(
            sqlite3_bind_double(
                statement,
                2,
                session.startedAt.timeIntervalSince1970
            )
        )

        if let endedAt = session.endedAt {
            try checkSQLite(
                sqlite3_bind_double(statement, 3, endedAt.timeIntervalSince1970)
            )
        } else {
            try checkSQLite(sqlite3_bind_null(statement, 3))
        }

        try bind(session.status.rawValue, to: statement, at: 4)
        try bind(amplifierJSON, to: statement, at: 5)

        try checkSQLite(
            sqlite3_bind_double(
                statement,
                6,
                session.lastObservedAt.timeIntervalSince1970
            )
        )

        try checkSQLite(
            sqlite3_bind_int(statement, 7, session.timingIsApproximate ? 1 : 0)
        )

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw currentDatabaseError()
        }
    }

    func listSessions() throws -> [PlayingSession] {
        let statement = try prepare(
            """
            SELECT id, started_at, ended_at, status, amplifier_ids_json, last_observed_at, timing_is_approximate
            FROM sessions
            ORDER BY started_at DESC;
            """
        )
        defer { sqlite3_finalize(statement) }

        var sessions: [PlayingSession] = []

        while true {
            let result = sqlite3_step(statement)

            if result == SQLITE_DONE {
                break
            }

            guard result == SQLITE_ROW else {
                throw currentDatabaseError()
            }

            sessions.append(try decodeSession(from: statement))
        }

        return sessions
    }

    private func createSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL,
                status TEXT NOT NULL
                    CHECK (status IN ('active', 'completed', 'recovered')),
                amplifier_ids_json TEXT NOT NULL,
                last_observed_at REAL NOT NULL,
                timing_is_approximate INTEGER NOT NULL DEFAULT 0,
                CHECK ((status = 'active' AND ended_at IS NULL)
                    OR
                (status IN ('completed', 'recovered') AND ended_at IS NOT NULL)
                )
            );

            CREATE UNIQUE INDEX IF NOT EXISTS one_active_session
            ON sessions(status)
            WHERE status = 'active';

            PRAGMA user_version = 1;
            """
        )
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let database else {
            throw SQLiteRepositoryError.database("The database is closed.")
        }

        var statement: OpaquePointer?

        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)

        guard result == SQLITE_OK, let statement else {
            throw currentDatabaseError()
        }

        return statement
    }

    private func execute(_ sql: String) throws {
        guard let database else {
            throw SQLiteRepositoryError.database("The database is closed.")
        }

        var messagePointer: UnsafeMutablePointer<Int8>?

        let result = sqlite3_exec(database, sql, nil, nil, &messagePointer)

        guard result == SQLITE_OK else {
            let message =
                messagePointer.map {
                    String(cString: $0)
                } ?? String(cString: sqlite3_errmsg(database))

            sqlite3_free(messagePointer)
            throw SQLiteRepositoryError.database(message)
        }
    }

    private func bind(
        _ value: String,
        to statement: OpaquePointer,
        at index: Int32
    ) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        let result = sqlite3_bind_text(statement, index, value, -1, transient)

        try checkSQLite(result)
    }

    private func checkSQLite(_ result: Int32) throws {
        guard result == SQLITE_OK else {
            throw currentDatabaseError()
        }
    }

    private func currentDatabaseError() -> SQLiteRepositoryError {
        guard let database else {
            return .database("the database is closed.")
        }

        return .database(String(cString: sqlite3_errmsg(database)))
    }

    private func decodeSession(from statement: OpaquePointer) throws
        -> PlayingSession
    {
        guard
            let idPointer = sqlite3_column_text(statement, 0),
            let id = UUID(uuidString: String(cString: idPointer)),
            let statusPointer = sqlite3_column_text(statement, 3),
            let status = SessionStatus(
                rawValue: String(cString: statusPointer)
            ),
            let amplifierPointer = sqlite3_column_text(statement, 4)
        else {
            throw SQLiteRepositoryError.invalidData(
                "A session row has an invalid ID, status, or amplifier list."
            )
        }

        let amplifierJSON = String(cString: amplifierPointer)

        guard let amplifierData = amplifierJSON.data(using: .utf8) else {
            throw SQLiteRepositoryError.invalidData(
                "The amplifier list is not valid UTF-8."
            )
        }

        let amplifierIDs: [String]

        do {
            amplifierIDs = try JSONDecoder().decode(
                [String].self,
                from: amplifierData
            )
        } catch {
            throw SQLiteRepositoryError.invalidData(
                "Could not decode amplifier IDs: \(error.localizedDescription)"
            )
        }

        let startedAt = Date(
            timeIntervalSince1970: sqlite3_column_double(statement, 1)
        )

        let endedAt: Date?

        if sqlite3_column_type(statement, 2) == SQLITE_NULL {
            endedAt = nil
        } else {
            endedAt = Date(
                timeIntervalSince1970: sqlite3_column_double(statement, 2)
            )
        }

        let lastObservedAt = Date(
            timeIntervalSince1970: sqlite3_column_double(statement, 5)
        )

        let timingIsApproximate =
            sqlite3_column_int(statement, 6) != 0

        return PlayingSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            status: status,
            amplifierBundleIDs: amplifierIDs,
            lastObservedAt: lastObservedAt,
            timingIsApproximate: timingIsApproximate
        )
    }

}
