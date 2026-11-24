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
}
