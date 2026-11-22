//
//  LibraryItem.swift
//  Remaster
//
//  Created by Cameron Slash on 11/21/26.
//

import Foundation
import SwiftData
import OSLog

@Model
public final class LibraryItem {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LibraryItem")
    
    var upc: String?
    var ean: String?
    var kind: Kind.RawValue?
    var tmdbId: String?
    var ownedFormats: [DiscFormat.RawValue]?
    var editionData: Data?
    var dateAdded: Date = Date.now
    
    var edition: Edition? {
        guard let data = editionData else { return nil }
        
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(Edition.self, from: data)
        } catch {
            Self.logger.error("Failed to decode saved LibraryItem's edition: \(error.localizedDescription)")
            return nil
        }
    }
    
    public init(upc: String?, ean: String?, kind: Kind.RawValue?, tmdbId: String?, ownedFormats: [DiscFormat.RawValue]?, edition: Edition?) {
        let encoder = JSONEncoder()
        
        self.upc = upc
        self.ean = ean
        self.kind = kind
        self.tmdbId = tmdbId
        self.ownedFormats = ownedFormats
        
        do {
            self.editionData = try encoder.encode(edition)
        } catch {
            Self.logger.error("Failed to encode LibraryItem's edition: \(error)")
            assertionFailure()
        }
    }
}
