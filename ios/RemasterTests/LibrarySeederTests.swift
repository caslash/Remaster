//
//  LibrarySeederTests.swift
//  RemasterTests
//
//  The SEED_LIBRARY data used to check RMSTR-18 AC 2 (a 500-item library loads
//  in under 1 s and scrolls smoothly). These keep the seeded library realistic,
//  so profiling measures what a real library costs:
//  - every seeded poster is stored like a downloaded one, so the backfill has
//    nothing to fetch while profiling and cards take the stored-poster path;
//  - the stored posters are real JPEGs at the size PosterService stores;
//  - some cards have no cover, so the title placeholder is exercised;
//  - every card has a format badge, as a copy saved through Confirm does;
//  - titles vary, so cells don't all lay out the same text.
//

import Foundation
import ImageIO
import SwiftData
import Testing
@testable import Remaster

@MainActor
@Suite("LibrarySeeder")
struct LibrarySeederTests {
    private let container: ModelContainer
    private let items: [LibraryItem]

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: LibraryItem.self, configurations: configuration)
        LibrarySeeder.seed(container)
        items = try ModelContext(container).fetch(FetchDescriptor<LibraryItem>())
    }

    @Test("Seeding saves 500 items")
    func seeds500() {
        #expect(items.count == 500)
    }

    @Test("Seeding twice doesn't add a second 500")
    func seedingIsIdempotent() throws {
        LibrarySeeder.seed(container)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<LibraryItem>()) == 500)
    }

    @Test("The backfill finds nothing to download in a seeded library")
    func backfillHasNothingToDo() throws {
        // The same query PosterService.backfillPosters uses.
        let missing = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.posterURL != nil && $0.imageData == nil })

        #expect(try ModelContext(container).fetchCount(missing) == 0)
    }

    @Test("Every stored poster has the marker the card reloads on")
    func storedPostersHaveMarker() {
        let withPoster = items.filter { $0.imageData != nil }

        #expect(withPoster.allSatisfy { $0.posterUpdatedAt != nil })
    }

    @Test("Stored posters are 333 × 500 JPEGs of a realistic size, not trivially small")
    func postersAreRealistic() throws {
        let posters = Set(items.compactMap(\.imageData))
        try #require(!posters.isEmpty, "No seeded item has a stored poster")

        for data in posters {
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            #expect(CGImageSourceGetType(source) as String? == "public.jpeg")
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == 333)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == 500)
            // A real downsampled poster is a few tens of KB; a flat fill would
            // be a few KB and decode unrealistically fast.
            #expect(data.count > 10_000, "A seeded poster is only \(data.count) bytes")
        }
    }

    @Test("Posters vary across the library")
    func postersVary() {
        #expect(Set(items.compactMap(\.imageData)).count >= 8)
    }

    @Test("About one in ten cards has no cover, so the placeholder shows")
    func someCardsHaveNoCover() {
        let coverless = items.filter { $0.imageData == nil && $0.posterURL == nil }

        #expect((25...100).contains(coverless.count), "\(coverless.count) of 500 seeded cards have no cover")
    }

    @Test("Every card has a format badge, as a copy saved through Confirm does")
    func everyCardHasAFormat() {
        let noFormat = items.filter { ($0.ownedFormats ?? []).isEmpty }

        #expect(noFormat.isEmpty, "\(noFormat.count) seeded cards have no format: \(Set(noFormat.compactMap(\.displayTitle)))")
    }

    @Test("Titles vary, so cells don't all lay out the same text")
    func titlesVary() {
        #expect(Set(items.compactMap(\.displayTitle)).count >= 10)
    }

    @Test("Every card has a title")
    func everyCardHasATitle() {
        #expect(items.allSatisfy { !($0.displayTitle ?? "").isEmpty })
    }
}
