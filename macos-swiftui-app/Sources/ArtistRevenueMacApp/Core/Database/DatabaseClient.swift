// DatabaseClient.swift
// Amplify Core
//
// PostgresNIO-backed connection pool actor with a readiness gate.
// All repository objects hold a shared reference and call through it for queries.
// Connection target: localhost:5433 / artist_revenue_db (Docker container).

import Foundation
import PostgresNIO
import Logging

/// An application-wide actor that encapsulates a `PostgresClient` connection pool
/// and exposes a typed query execution interface for all Repository objects.
///
/// ### Lifecycle
/// 1. `DatabaseClient.shared.start()` is called from `AmplifyCoreApp.init()` via a
///    detached Task — this fires as early as possible, before any view appears.
/// 2. `query()` / `execute()` callers that arrive before the pool is ready **wait**
///    via a `CheckedContinuation` queue rather than failing or racing.
/// 3. On application termination call `stop()` to close connections.
///
/// ### Readiness Gate
/// An internal boolean `isReady` tracks whether `client.run()` has completed its
/// initial TCP + authentication handshake. Any query arriving before `isReady == true`
/// is suspended and enqueued; all queued callers are resumed when `markReady()` fires.
public actor DatabaseClient {

    // MARK: - Singleton

    public static let shared: DatabaseClient = DatabaseClient()

    // MARK: - Private State

    private let client: PostgresClient
    private var runTask: Task<Void, Never>?
    private let logger: Logger

    /// `true` once the pool has completed its initial handshake.
    private var isReady: Bool = false

    /// Suspended callers waiting for the pool to become ready.
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Init

    private init() {
        self.logger = Logger(label: "com.labelmaster.database")
        let env = EnvLoader.load()
        let host = env["SUPABASE_DB_HOST"] ?? "localhost"
        let port = Int(env["SUPABASE_DB_PORT"] ?? "5433") ?? 5433
        let username = env["SUPABASE_DB_USER"] ?? "postgres"
        let password = env["SUPABASE_DB_PASSWORD"] ?? "postgres"
        let database = env["SUPABASE_DB_NAME"] ?? "artist_revenue_db"
        let tls: PostgresClient.Configuration.TLS = host.contains("supabase") ? .require : .disable

        let configuration = PostgresClient.Configuration(
            host:     host,
            port:     port,
            username: username,
            password: password,
            database: database,
            tls:      tls
        )
        self.client = PostgresClient(configuration: configuration)
    }

    // MARK: - Lifecycle

    /// Starts the NIO event loop and waits for the TCP + auth handshake to complete.
    /// Idempotent — repeated calls while already running are no-ops.
    /// Call this from `App.init()` in a detached Task so it fires before views appear.
    public func start() async {
        guard runTask == nil else { return }
        logger.info("DatabaseClient: Starting connection pool → localhost:5433/artist_revenue_db")

        // client.run() drives the PostgresNIO event loop and never returns while the
        // pool is alive, so it must live in a detached background Task.
        runTask = Task.detached(priority: .background) { [self] in
            await self.client.run()
        }

        // Give the NIO event loop a moment to complete TCP connect + auth.
        // We use an adaptive retry instead of a fixed sleep.
        for attempt in 1...10 {
            try? await Task.sleep(for: .milliseconds(300))
            // Perform a lightweight heartbeat to confirm connectivity.
            let connected = await pingDatabase()
            if connected {
                logger.info("DatabaseClient: Connection pool ready (attempt \(attempt)).")
                markReady()
                return
            }
            logger.warning("DatabaseClient: Pool not yet ready, retrying (\(attempt)/10)…")
        }
        // Even if the ping never succeeded, unblock waiters so they fail gracefully.
        logger.error("DatabaseClient: Could not confirm pool readiness after 10 attempts.")
        markReady()
    }

    /// Cancels the background event-loop task, closing all connections.
    public func stop() {
        logger.info("DatabaseClient: Terminating connection pool.")
        runTask?.cancel()
        runTask = nil
        isReady = false
    }

    // MARK: - Readiness Gate

    /// Suspends the caller until the pool is ready.
    /// If the pool is already ready, returns immediately.
    private func awaitReady() async {
        guard !isReady else { return }
        await withCheckedContinuation { continuation in
            readyWaiters.append(continuation)
        }
    }

    /// Marks the pool as ready and resumes all suspended callers.
    private func markReady() {
        isReady = true
        let waiters = readyWaiters
        readyWaiters.removeAll()
        for continuation in waiters {
            continuation.resume()
        }
    }

    /// Executes a trivial `SELECT 1` to confirm the TCP + auth handshake is complete.
    private func pingDatabase() async -> Bool {
        do {
            let rows = try await client.query("SELECT 1::int4", logger: logger)
            for try await _ in rows { break }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Query Execution

    /// Executes a parameterised SQL query, decodes each result row, and returns typed results.
    ///
    /// If the pool is not yet ready, this method suspends until `start()` signals readiness.
    ///
    /// **SQL authoring rules:**
    /// - Cast `NUMERIC` → `::float8` so PostgresNIO maps to `Double`.
    /// - Cast `ENUM`   → `::text`   so PostgresNIO maps to `String`.
    ///
    /// - Parameters:
    ///   - sql:    A `PostgresQuery` built via safe string-interpolation binding.
    ///   - decode: A closure that receives each `PostgresRow` and returns `T`.
    /// - Returns: Collected decoded values.
    /// - Throws:  `DatabaseError.queryFailed` on server error.
    public func query<T: Sendable>(
        _ sql: PostgresQuery,
        decode: @Sendable (PostgresRow) throws -> T
    ) async throws -> [T] {
        await awaitReady()
        do {
            let rows: PostgresRowSequence = try await client.query(sql, logger: logger)
            var results: [T] = []
            for try await row in rows {
                results.append(try decode(row))
            }
            return results
        } catch let error as DatabaseError {
            throw error
        } catch {
            // Log full reflection for debugging (not shown to user)
            logger.error("DatabaseClient.query failed: \(String(reflecting: error))")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }

    /// Executes a parameterised DML statement (INSERT / UPDATE / DELETE).
    public func execute(_ sql: PostgresQuery) async throws {
        await awaitReady()
        do {
            _ = try await client.query(sql, logger: logger)
        } catch let error as DatabaseError {
            throw error
        } catch {
            logger.error("DatabaseClient.execute failed: \(String(reflecting: error))")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }

    /// Calls a PostgreSQL stored procedure via `CALL sp_name(...)` and optionally
    /// reads an OUT parameter value from the first column of the result row.
    ///
    /// PostgreSQL 14+ propagates OUT parameters through the SELECT-compatible
    /// `CALL` result set, so this method reads the first row (if any) and decodes
    /// the given column type `T`. Returns `nil` if the procedure produces no rows
    /// (e.g., void procedures with only side-effects).
    ///
    /// - Parameters:
    ///   - sql:    A `PostgresQuery` containing the full `CALL sp_name(...)` statement.
    ///   - decode: Closure that decodes the first result row into an OUT-param value `T`.
    ///             Pass `nil` if the procedure returns no value.
    /// - Returns: The decoded OUT-parameter value, or `nil`.
    /// - Throws:  `DatabaseError.queryFailed` on server error.
    public func callProcedure<T: Sendable>(
        _ sql: PostgresQuery,
        decode: (@Sendable (PostgresRow) throws -> T)? = nil
    ) async throws -> T? {
        await awaitReady()
        do {
            let rows: PostgresRowSequence = try await client.query(sql, logger: logger)
            guard let decoder = decode else { return nil }
            for try await row in rows {
                return try decoder(row)
            }
            return nil
        } catch let error as DatabaseError {
            throw error
        } catch {
            logger.error("DatabaseClient.callProcedure failed: \(String(reflecting: error))")
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }
}
