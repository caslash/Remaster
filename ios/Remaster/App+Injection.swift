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
    
    var posterService: Factory<any PosterStore> {
        Factory(self) { PosterService() }
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
#if DEBUG || PROFILING
        .context(.arg("SIMULATED_SERVICES"), .arg("SEED_LIBRARY"), .preview, factory: {
            let container = self.createModelContainer(isStoredInMemoryOnly: true)
            
            if ProcessInfo.processInfo.arguments.contains("SEED_LIBRARY") {
                LibrarySeeder.seed(container)
            }
            
            return container
        })
#endif
    }
}
