// Manager.swift
// Amplify Core
//
// Domain model for the `managers` table (V4__Events_and_Venues.sql).

import Foundation

public struct Manager: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let phone: String?

    public init(id: Int, name: String, phone: String?) {
        self.id = id
        self.name = name
        self.phone = phone
    }
}

