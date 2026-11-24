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

@Observable
public class LibraryViewModel {
    @ObservationIgnored @Injected(\.libraryService) private var libraryService: any LibraryManaging
    
    public var error: Error?
    
    init() { }
    
    func deleteItem(_ item: LibraryItem) {
        do {
            try self.libraryService.deleteFromLibrary(item)
        } catch {
            self.error = error
        }
    }
}
