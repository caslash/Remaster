//
//  LibrarySeeder.swift
//  Remaster
//
//  Created by Cameron Slash on 11/24/26.
//

#if DEBUG || PROFILING
import FactoryKit
import Foundation
import SwiftData
import UIKit

nonisolated enum LibrarySeeder {
    static func seed(_ container: ModelContainer, count: Int = 500) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        
        let existing = (try? context.fetchCount(FetchDescriptor<LibraryItem>())) ?? 0
        guard existing == 0 else { return }
        
        var rng = SeededGenerator(seed: 42)
        let editions = [Edition.wandaVision, Edition.grinch, Edition.hoppers]
        let posters: [Data] = (0..<12).map { _ in ArtworkGenerator().makeImageData(using: &rng) }
        let missingImageRate = 0.1
        
        for _ in 0..<count {
            var randomItem = editions.randomElement(using: &rng)!
            let addedAt = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970 - Double.random(in: 0...(86_400 * 365 * 5), using: &rng))
            let randomPosterData: Data? = Double.random(in: 0..<1, using: &rng) >= missingImageRate ? posters.randomElement(using: &rng)! : nil
            
            if randomPosterData == nil {
                randomItem.title?.posterURL = nil
                randomItem.coverImageURL = nil
            }
            
            let fallbackOwnedFormats = randomItem.format?.rawValue != nil ? [randomItem.format!.rawValue] : []
            
            let item = LibraryItem(
                upc: randomItem.barcodes.upc,
                ean: randomItem.barcodes.ean,
                kind: randomItem.title?.kind.rawValue,
                tmdbId: randomItem.title?.tmdbId,
                ownedFormats: randomItem.discContents?.map { $0.format.rawValue } ?? fallbackOwnedFormats,
                edition: randomItem,
                dateAdded: addedAt,
                imageData: randomPosterData,
                posterUpdatedAt: addedAt
            )
            
            if Double.random(in: 0..<1, using: &rng) >= 0.7 {
                item.displayTitle = ["Alien", "Heat", "Arrival", "Dune", "Jaws", "Se7en", "Up", "Tenet"].randomElement(using: &rng)
            }
            
            context.insert(item)
        }
        
        do {
            try context.save()
        } catch {
            assertionFailure("Library seeding failed: \(error)")
        }
    }
}

nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) { self.state = seed }
    
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
#endif
