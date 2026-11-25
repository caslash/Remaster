//
//  LibraryViewModel.swift
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
public class LibraryViewModel {
    @ObservationIgnored @Injected(\.libraryService) private var libraryService: any LibraryManaging
    @ObservationIgnored @Injected(\.posterService) private var posterService: any PosterStore
    
    public var error: Error?
    
    init() { }
    
    func deleteItem(_ item: LibraryItem) {
        do {
            try self.libraryService.deleteFromLibrary(item)
        } catch {
            self.error = error
        }
    }
    
    func getPoster(for persistentModelID: PersistentIdentifier) async -> UIImage? {
        return await self.posterService.getPoster(persistentModelID: persistentModelID)
    }
}
