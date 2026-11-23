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
    @ObservationIgnored @Injected(\.modelContainer) private var modelContainer
    
    init() { }
    
    func deleteItem(_ item: LibraryItem) {
        do {
            self.modelContainer.mainContext.delete(item)
            try self.modelContainer.mainContext.save()
        } catch {
            self.modelContainer.mainContext.rollback()
        }
    }
}
