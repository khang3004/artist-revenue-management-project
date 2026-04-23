// DatabaseError.swift
// Amplify Core
//
// Defines the canonical set of error cases that can originate from the
// database interaction layer and are ultimately surfaced to the UI as alerts.

import Foundation

/// Enumerates every category of failure that may occur during database interaction.
///
/// All cases conform to `LocalizedError`, enabling SwiftUI `Alert` modifiers to
/// render human-readable diagnostic messages without additional mapping.
///
/// ### Usage
/// Throw these errors from `DatabaseClient` or Repository methods; catch them
/// in `@MainActor`-annotated ViewModel functions and assign to the exposed
/// `errorMessage` string property for UI presentation.
public enum DatabaseError: LocalizedError, Equatable, Sendable {

    /// The initial TCP connection to the PostgreSQL server could not be established.
    /// `detail` carries the underlying NIO error message.
    case connectionFailed(String)

    /// A query was submitted successfully but the PostgreSQL server returned an error.
    /// `detail` carries the server-side error message (SQLSTATE + detail).
    case queryFailed(String)

    /// The raw `PostgresRow` result could not be decoded into the expected Swift model.
    /// `detail` identifies the offending column or type mismatch.
    case decodingFailed(String)

    /// The query returned zero rows where at least one was required (e.g., INSERT RETURNING).
    case noResults

    /// A mutation statement (INSERT / UPDATE / DELETE) affected an unexpected number of rows.
    case unexpectedRowCount(expected: Int, actual: Int)

    // MARK: - LocalizedError

    /// A short, user-facing title suitable for an `Alert` heading.
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let detail):
            return "Connection Failed: \(detail)"
        case .queryFailed(let detail):
            return "Query Failed: \(detail)"
        case .decodingFailed(let detail):
            return "Data Decoding Failed: \(detail)"
        case .noResults:
            return "No Results Returned"
        case .unexpectedRowCount(let expected, let actual):
            return "Unexpected Row Count (expected \(expected), got \(actual))"
        }
    }

    /// An extended explanation of the failure cause.
    public var failureReason: String? {
        switch self {
        case .connectionFailed:
            return "Verify that the Docker PostgreSQL container is running on localhost:5433."
        case .queryFailed:
            return "The PostgreSQL server returned a server-side error. Inspect the application log for the full query and SQLSTATE."
        case .decodingFailed:
            return "A type mismatch exists between the expected Swift model and the database schema. The schema migration may be out of sync."
        case .noResults:
            return "The query predicates may be too restrictive, or the relevant data has not yet been seeded."
        case .unexpectedRowCount:
            return "A concurrent modification may have altered the data between read and write. Retry the operation."
        }
    }

    /// A short, actionable suggestion presented below the error description.
    public var recoverySuggestion: String? {
        "Ensure the Docker container is running (`docker compose up -d`) and retry. Consult the application log for full diagnostic details."
    }
}
