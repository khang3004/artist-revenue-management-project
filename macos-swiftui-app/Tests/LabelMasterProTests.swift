// AmplifyCoreTests.swift
// Amplify Core
//
// Placeholder test target. Expand with unit tests for repositories and ViewModels
// using a mock DatabaseClient that returns seed fixtures.

import XCTest
@testable import ArtistRevenueMacApp

/// Placeholder test suite for Amplify Core.
///
/// ### Recommended Test Strategy
/// - **Unit Tests**: Mock `DatabaseClient` with a closure-injection strategy to return
///   fixture `PostgresRow` stubs and validate model decoding.
/// - **ViewModel Tests**: Inject mock repositories and assert that `DashboardViewModel.loadAll()`
///   correctly propagates data to published properties.
/// - **Integration Tests**: Run against a dedicated test Docker container with known seed data.
final class AmplifyCoreTests: XCTestCase {

    /// Verifies that `ArtistRole.displayName` returns a non-empty string for every case.
    func testArtistRoleDisplayNames() {
        for role in ArtistRole.allCases {
            XCTAssertFalse(
                role.displayName.isEmpty,
                "ArtistRole.\(role.rawValue) must have a non-empty displayName."
            )
        }
    }

    /// Verifies that `ContractType.displayName` is capitalised correctly.
    func testContractTypeDisplayNames() {
        for type_case in ContractType.allCases {
            let displayName: String = type_case.displayName
            XCTAssertEqual(
                displayName.first?.isUppercase, true,
                "ContractType.\(type_case.rawValue).displayName should begin with an uppercase letter."
            )
        }
    }

    /// Verifies that `Contract.isCurrentlyActive` returns `false` for expired contracts.
    func testContractIsCurrentlyActiveReturnsFalseForExpired() {
        let pastDate: Date = Date(timeIntervalSinceNow: -86400 * 365 * 2)
        let contract: Contract = Contract(
            id:           UUID(),
            name:         "Test Contract",
            startDate:    Date(timeIntervalSinceNow: -86400 * 730),
            endDate:      pastDate,
            contractType: .recording,
            status:       .active,
            createdAt:    Date.now
        )
        XCTAssertFalse(
            contract.isCurrentlyActive,
            "A contract whose endDate is in the past should not be considered currently active."
        )
    }

    /// Verifies that `Track.formattedDuration` returns the expected `m:ss` format.
    func testTrackFormattedDuration() {
        let track: Track = Track(
            id:              1,
            isrc:            "USABC1234567",
            title:           "Test Track",
            durationSeconds: 217,   // 3 minutes 37 seconds
            albumId:         1,
            playCount:       0
        )
        XCTAssertEqual(
            track.formattedDuration, "3:37",
            "Track.formattedDuration should return '3:37' for 217 seconds."
        )
    }

    /// Verifies that `RevenueType` raw values match the PostgreSQL ENUM literals.
    func testRevenueTypeRawValuesMatchDatabaseEnumLiterals() {
        XCTAssertEqual(RevenueType.STREAMING.rawValue, "STREAMING")
        XCTAssertEqual(RevenueType.SYNC.rawValue,      "SYNC")
        XCTAssertEqual(RevenueType.LIVE.rawValue,      "LIVE")
    }
}
