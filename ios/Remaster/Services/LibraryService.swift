//
//  LibraryService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/21/26.
//

import FactoryKit
import Foundation
import OSLog
import SwiftData

@MainActor
public class LibraryService: LibraryManaging {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LibraryService")
    
    @Injected(\.modelContainer) private var modelContainer: ModelContainer
    @Injected(\.posterService) private var posterService: any PosterStore

    func addToLibrary(_ item: LibraryItem, forceDuplicate: Bool = false) async throws {
        do {
            try await self.checkForDuplicate(item: item, skipCheck: forceDuplicate)
            
            if item.ownedFormats != nil {
                item.ownedFormats = DiscFormat.sortList(item.ownedFormats!)
            }
            
            self.modelContainer.mainContext.insert(item)
            try self.modelContainer.mainContext.save()
        } catch {
            self.modelContainer.mainContext.rollback()
            throw error
        }
        
        if let posterURL = item.posterURL {
            Task {
                do {
                    try await self.posterService.savePoster(persistentModelID: item.persistentModelID, posterURL: posterURL)
                } catch {
                    Self.logger.error("Failed to save poster for \(posterURL): \(error.localizedDescription)")
                }
            }
        }
    }

    func findCopyWithBarcode(_ barcode: String?) async throws -> LibraryItem? {
        guard let barcode else { return nil }
        let descriptor: FetchDescriptor<LibraryItem> = .init(predicate: #Predicate { $0.upc == barcode || $0.ean == barcode })
        return try self.modelContainer.mainContext.fetch(descriptor).first
    }

    func findCopyByTitle(kind: String?, tmdbId: String?) async throws -> LibraryItem? {
        guard let kind, let tmdbId else { return nil }
        let descriptor: FetchDescriptor<LibraryItem> = .init(predicate: #Predicate { $0.kind == kind && $0.tmdbId == tmdbId })
        return try self.modelContainer.mainContext.fetch(descriptor).first
    }
    
    func addFormatsToExistingCopy(_ item: LibraryItem) async throws -> LibraryItem {
        let dupeAndFormats = try await findDuplicateAndExtraFormats(item: item)
        
        if let (match, extraFormats) = dupeAndFormats {
            if extraFormats.isEmpty { return match }
            
            do {
                if match.ownedFormats == nil {
                    match.ownedFormats = DiscFormat.sortList(extraFormats)
                } else {
                    var formatsList = match.ownedFormats!
                    formatsList.append(contentsOf: extraFormats)
                    match.ownedFormats = DiscFormat.sortList(formatsList)
                }
                
                try self.modelContainer.mainContext.save()
                return match
            } catch {
                self.modelContainer.mainContext.rollback()
                throw error
            }
        } else {
            throw LibraryError.duplicateNotFound
        }
    }
    
    private func checkForDuplicate(item: LibraryItem, skipCheck: Bool) async throws {
        guard !skipCheck else { return }
        
        if let extraFormats = try await findDuplicateAndExtraFormats(item: item)?.extraFormats {
            if extraFormats.isEmpty { throw LibraryError.duplicate }
            
            throw LibraryError.extraFormat(formats: extraFormats)
        }
        
        if let duplicate = try await findCopyByTitle(kind: item.kind, tmdbId: item.tmdbId) { throw LibraryError.ownedInOtherFormats(formats: duplicate.ownedFormats ?? []) }
    }
    
    private func findDuplicateAndExtraFormats(item: LibraryItem) async throws -> (match: LibraryItem, extraFormats: [DiscFormat.RawValue])? {
        let match: LibraryItem? = if let upcMatch = try await findCopyWithBarcode(item.upc) {
            upcMatch
        } else {
            try await findCopyWithBarcode(item.ean)
        }
        
        if let match {
            let extraFormats = (item.ownedFormats ?? []).filter { !(match.ownedFormats?.contains($0) ?? false) }
            return (match, extraFormats)
        }
        
        return nil
    }
}
