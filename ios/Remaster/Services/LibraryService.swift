//
//  LibraryService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/21/26.
//

import FactoryKit
import Foundation
import SwiftData

@MainActor
public class LibraryService: LibraryManaging {
    @Injected(\.modelContainer) private var modelContainer: ModelContainer

    func addToLibrary(_ item: LibraryItem, forceDuplicate: Bool = false) async throws {
        do {
            try await self.checkForDuplicate(item: item, skipCheck: forceDuplicate)
            
            self.modelContainer.mainContext.insert(item)
            try self.modelContainer.mainContext.save()
        } catch {
            self.modelContainer.mainContext.rollback()
            throw error
        }
    }
    
    private func checkForDuplicate(item: LibraryItem, skipCheck: Bool) async throws {
        guard !skipCheck else { return }
        
        if try await findCopyWithBarcode(item.upc) != nil { throw LibraryError.duplicate }
        if try await findCopyWithBarcode(item.ean) != nil { throw LibraryError.duplicate }
        if let duplicate = try await findCopyByTitle(item.edition?.title) { throw LibraryError.ownedInOtherFormats(formats: duplicate.ownedFormats ?? []) }
    }

    func findCopyWithBarcode(_ barcode: String?) async throws -> LibraryItem? {
        guard let barcode else { return nil }
        let descriptor: FetchDescriptor<LibraryItem> = .init(predicate: #Predicate { $0.upc == barcode || $0.ean == barcode })
        return try self.modelContainer.mainContext.fetch(descriptor).first
    }

    func findCopyByTitle(_ title: Title?) async throws -> LibraryItem? {
        guard let title else { return nil }
        let kind: String? = title.kind.rawValue
        let tmdbId: String? = title.tmdbId
        let descriptor: FetchDescriptor<LibraryItem> = .init(predicate: #Predicate { $0.kind == kind && $0.tmdbId == tmdbId })
        return try self.modelContainer.mainContext.fetch(descriptor).first
    }
}
