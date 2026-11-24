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
    var displayTitle: String?
    var posterURL: URL?
    var year: Int?
    var posterUpdatedAt: Date?
    
    @Attribute(.externalStorage)
    var imageData: Data?
    
    public init(upc: String?, ean: String?, kind: Kind.RawValue?, tmdbId: String?, ownedFormats: [DiscFormat.RawValue]?, edition: Edition?) {
        let encoder = JSONEncoder()
        
        self.upc = upc
        self.ean = ean
        self.kind = kind
        self.tmdbId = tmdbId
        self.displayTitle = edition?.title?.name ?? edition?.upcTitle
        self.posterURL = edition?.title?.posterURL ?? edition?.coverImageURL
        self.year = edition?.title?.year ?? edition?.year
        
        if let ownedFormats {
            self.ownedFormats = DiscFormat.sortList(ownedFormats.unique())
        }
        
        if let edition {
            do {
                self.editionData = try encoder.encode(edition)
            } catch {
                Self.logger.error("Failed to encode LibraryItem's edition: \(error)")
                assertionFailure("Failed to encode LibraryItem's edition: \(error)")
            }
        }
    }
    
    public func getEdition() -> Edition? {
        guard let data = editionData else { return nil }
        
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(Edition.self, from: data)
        } catch {
            Self.logger.error("Failed to decode saved LibraryItem's edition: \(error)")
            return nil
        }
    }
}
