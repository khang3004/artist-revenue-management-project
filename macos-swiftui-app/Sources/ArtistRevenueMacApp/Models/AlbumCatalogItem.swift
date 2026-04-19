// AlbumCatalogItem.swift
// Amplify Core
//
// UI-facing album projection: album fields + joined artist name.

import Foundation

public struct AlbumCatalogItem: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let releaseDate: Date
    public let artistId: Int
    public let artistStageName: String

    public var releaseYear: String { releaseDate.formatted(.dateTime.year()) }

    public init(id: Int, title: String, releaseDate: Date, artistId: Int, artistStageName: String) {
        self.id = id
        self.title = title
        self.releaseDate = releaseDate
        self.artistId = artistId
        self.artistStageName = artistStageName
    }
}

