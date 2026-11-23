//
//  App+Injection.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import FactoryKit
import Foundation
import SwiftData

extension Container {
    var barcodeService: Factory<any BarcodeServicing> {
        Factory(self) { BarcodeService() }
            .singleton
#if DEBUG
            .onArg("SIMULATED_SERVICES", factory: {
                SimulatedBarcodeService()
            })
#endif
    }
    
    @MainActor
    var libraryService: Factory<any LibraryManaging> {
        Factory(self) { LibraryService() }
            .singleton
    }
    
    private func createModelContainer(isStoredInMemoryOnly: Bool) -> ModelContainer {
        let schema = Schema([
            LibraryItem.self
        ])
        
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly, cloudKitDatabase: .none)
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var modelContainer: Factory<ModelContainer> {
        self {
            return self.createModelContainer(isStoredInMemoryOnly: false)
        }
        .singleton
#if DEBUG
        .context(.arg("SIMULATED_SERVICES"), .preview, factory: {
            return self.createModelContainer(isStoredInMemoryOnly: true)
        })
#endif
    }
}
