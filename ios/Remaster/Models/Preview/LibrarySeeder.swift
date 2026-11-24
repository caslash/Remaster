//
//  LibrarySeeder.swift
//  Remaster
//
//  Created by Cameron Slash on 11/24/26.
//

#if DEBUG
import Foundation
import SwiftData

nonisolated enum LibrarySeeder {
    static func seed(_ container: ModelContainer, count: Int = 500) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        
        let existing = (try? context.fetchCount(FetchDescriptor<LibraryItem>())) ?? 0
        guard existing == 0 else { return }
        
        var rng = SeededGenerator(seed: 42)
        let editions = [Edition.wandaVision, Edition.grinch, Edition.hoppers]
        
        for _ in 0..<count {
            let item = LibraryItem(
                upc: editions.randomElement(using: &rng)?.barcodes.upc,
                ean: editions.randomElement(using: &rng)?.barcodes.ean,
                kind: editions.randomElement(using: &rng)?.kind?.rawValue,
                tmdbId: editions.randomElement(using: &rng)?.title?.tmdbId,
                ownedFormats: editions.randomElement(using: &rng)?.discContents?.map { $0.format.rawValue },
                edition: editions.randomElement(using: &rng)!,
                dateAdded: Date(timeIntervalSince1970: Date.now.timeIntervalSince1970 - Double.random(in: 0...(86_400 * 365 * 5), using: &rng))
            )
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
