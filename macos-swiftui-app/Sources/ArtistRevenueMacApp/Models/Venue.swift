// Venue.swift
// Amplify Core
//
// Domain model for the `venues` table (V4__Events_and_Venues.sql).

import Foundation

public struct Venue: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let address: String?
    public let capacity: Int?

    public init(id: Int, name: String, address: String?, capacity: Int?) {
        self.id = id
        self.name = name
        self.address = address
        self.capacity = capacity
    }
}

