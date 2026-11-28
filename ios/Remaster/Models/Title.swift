//
//  Title.swift
//  Remaster
//
//  Created by Cameron Slash on 11/8/26.
//

import Foundation

public nonisolated struct Title: Codable, Identifiable {
    public var id: String { "\(kind)\(tmdbId)" }
    var tmdbId: String
    var kind: Kind
    var name: String
    var year: Int?
    var imdbId: String?
    var posterURL: URL?
}
