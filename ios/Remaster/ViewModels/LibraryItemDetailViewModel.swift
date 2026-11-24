//
//  LibraryItemDetailViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import FactoryKit
import Foundation
import Observation
import SwiftData
import UIKit

@Observable
public class LibraryItemDetailViewModel {
    @ObservationIgnored @Injected(\.libraryService) private var libraryService: any LibraryManaging
    @ObservationIgnored @Injected(\.posterService) private var posterService: any PosterStore
    
    public var libraryItem: LibraryItem
    public var edition: Edition?
    public var posterImage: UIImage?
    public var editionText: String? { getEditionText() }
    
    public var error: Error?
    
    public private(set) var copies: Int = 0
    
    init(libraryItem: LibraryItem) {
        self.libraryItem = libraryItem
        self.edition = libraryItem.getEdition()
    }
    
    public func fetchPoster() {
        Task {
            self.posterImage = await self.posterService.getPoster(persistentModelID: libraryItem.persistentModelID)
        }
    }
    
    public func refreshCopies() {
        self.copies = (try? libraryService.findAmountOfCopiesWithBarcode(upc: libraryItem.upc, ean: libraryItem.ean)) ?? 0
    }

    public func observeLibraryChanges() async {
        refreshCopies()
        for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
            refreshCopies()
        }
    }
    
    public func deleteItem(onComplete: @escaping () -> Void) {
        do {
            try self.libraryService.deleteFromLibrary(libraryItem)
            onComplete()
        } catch {
            self.error = error
        }
    }
    
    private func getEditionText() -> String? {
        guard let edition else { return nil }
        
        if edition.packaging?.steelbook == false && edition.editionFlags.allFalse { return "Standard" }

        if edition.packaging?.steelbook ?? false { return "Steelbook" }
        if edition.editionFlags.collector ?? false { return "Collector's" }
        if edition.editionFlags.limited ?? false { return "Limited" }
        if edition.editionFlags.boxset ?? false { return "Boxset" }
        if edition.editionFlags.special ?? false { return "Special" }
        if edition.editionFlags.anniversary ?? false { return "Anniversary" }
            
        return "Unknown"
    }
}
