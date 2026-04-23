// TrackRegistryItem.swift
// Amplify Core
//
// UI-facing track projection: track fields + joined album + artist names.

import Foundation

public struct TrackRegistryItem: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let isrc: String
    public let title: String
    public let durationSeconds: Int?
    public let albumId: Int
    public let playCount: Int
    public let albumTitle: String
    public let artistStageName: String

    public var formattedDuration: String {
        guard let seconds = durationSeconds else { return "—" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    public var formattedPlayCount: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: playCount)) ?? "\(playCount)"
    }

    public init(
        id: Int,
        isrc: String,
        title: String,
        durationSeconds: Int?,
        albumId: Int,
        playCount: Int,
        albumTitle: String,
        artistStageName: String
    ) {
        self.id = id
        self.isrc = isrc
        self.title = title
        self.durationSeconds = durationSeconds
        self.albumId = albumId
        self.playCount = playCount
        self.albumTitle = albumTitle
        self.artistStageName = artistStageName
    }
}

