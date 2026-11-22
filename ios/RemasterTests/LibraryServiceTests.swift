//
//  LibraryServiceTests.swift
//  RemasterTests
//
//  The on-device library store (RMSTR-14): saving a copy, the duplicate rules
//  (same barcode, then same TMDB title), and the two lookups they're built on.
//
//  The lookup tests seed the store directly; only the saving tests go through
//  addToLibrary.
//
//  LibraryService resolves its ModelContainer from Container.shared when it's
//  created, so each test registers a fresh in-memory container first. The suite
//  is serialized because Container.shared is global.
//

import FactoryKit
import Foundation
import SwiftData
import Testing
@testable import Remaster

@MainActor
@Suite("LibraryService", .serialized)
final class LibraryServiceTests {
    private let container: ModelContainer
    private let service: LibraryService

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: LibraryItem.self, configurations: configuration)
        self.container = container

        Container.shared.reset()
        Container.shared.modelContainer.register { container }
        service = LibraryService()
    }

    // MARK: - Saving

    @Test("A saved copy is written to the store, not just staged")
    func addSaves() async throws {
        try await service.addToLibrary(item(upc: "786936900001", ean: "0786936900001", title: zootopia))

        // A separate context only sees what the main context actually saved.
        let saved = try ModelContext(container).fetch(FetchDescriptor<LibraryItem>())
        #expect(saved.count == 1)
        #expect(saved.first?.upc == "786936900001")
    }

    @Test("A saved copy keeps the edition snapshot and the owned formats")
    func addKeepsSnapshot() async throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)
        try await service.addToLibrary(LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: edition.title?.kind.rawValue,
            tmdbId: edition.title?.tmdbId,
            ownedFormats: [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue],
            edition: edition
        ))

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.ownedFormats == ["4K UHD", "Blu-ray"])
        #expect(saved.edition?.upcTitle == "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook")
        #expect(saved.edition?.hdr?.count == 2)
    }

    // MARK: - Duplicate rules (RMSTR-14)

    @Test("The same disc again is Already in your library, matched by UPC")
    func sameUPCIsDuplicate() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(self.item(upc: "786936900001", ean: nil, title: self.zootopia))
        }
    }

    @Test("The same disc again is Already in your library, matched by EAN")
    func sameEANIsDuplicate() async throws {
        try seed(item(upc: nil, ean: "5051892230476", title: nil))

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(self.item(upc: nil, ean: "5051892230476", title: nil))
        }
    }

    @Test("A disc with both barcodes matches a copy saved with only one of them")
    func eitherBarcodeIsDuplicate() async throws {
        try seed(item(upc: nil, ean: "0786936900001", title: nil))

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(self.item(upc: "786936900001", ean: "0786936900001", title: nil))
        }
    }

    @Test("Another edition of a title you own names the formats you own")
    func sameTitleOtherEdition() async throws {
        let owned = try item(upc: "786936900001", ean: nil, title: zootopia)
        owned.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        try seed(owned)

        // A DVD of the same film: different barcode, same TMDB title.
        let dvd = try item(upc: "786936900099", ean: nil, title: zootopia)
        dvd.ownedFormats = [DiscFormat.dvd.rawValue]

        await #expect(throws: LibraryError.ownedInOtherFormats(formats: ["4K UHD", "Blu-ray"])) {
            try await self.service.addToLibrary(dvd)
        }
    }

    @Test("Same barcode is reported before same title")
    func barcodeBeatsTitle() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(self.item(upc: "786936900001", ean: nil, title: self.zootopia))
        }
    }

    @Test("Add another copy saves a second copy of the same disc")
    func forcedDuplicateSaves() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        try await service.addToLibrary(item(upc: "786936900001", ean: nil, title: zootopia), forceDuplicate: true)

        #expect(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).count == 2)
    }

    @Test("Two different unmatched discs aren't duplicates of each other")
    func unmatchedDiscsAreNotDuplicates() async throws {
        try seed(item(upc: "0191329282809", ean: nil, title: nil))

        try await service.addToLibrary(item(upc: "043396648654", ean: nil, title: nil))

        #expect(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).count == 2)
    }

    @Test("A rejected duplicate leaves nothing behind")
    func rejectedDuplicateIsNotSaved() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        _ = try? await service.addToLibrary(item(upc: "786936900001", ean: nil, title: zootopia))

        #expect(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).count == 1)
    }

    // MARK: - Finding by barcode

    @Test("Finds a copy by its UPC")
    func findsByUPC() async throws {
        try seed(item(upc: "786936900001", ean: "0786936900001", title: zootopia))

        let found = try await service.findCopyWithBarcode("786936900001")

        #expect(found?.tmdbId == "1084242")
    }

    @Test("Finds a copy by its EAN, the same disc scanned as EAN-13")
    func findsByEAN() async throws {
        try seed(item(upc: "786936900001", ean: "0786936900001", title: zootopia))

        let found = try await service.findCopyWithBarcode("0786936900001")

        #expect(found?.tmdbId == "1084242")
    }

    @Test("Finds a copy that only has an EAN")
    func findsEANOnlyCopy() async throws {
        try seed(item(upc: nil, ean: "5051892230476", title: nil))

        let found = try await service.findCopyWithBarcode("5051892230476")

        #expect(found != nil)
    }

    @Test("A barcode that isn't in the library finds nothing")
    func unknownBarcode() async throws {
        try seed(item(upc: "786936900001", ean: "0786936900001", title: zootopia))

        let found = try await service.findCopyWithBarcode("043396648654")

        #expect(found == nil)
    }

    @Test("No barcode never matches, even when saved copies are missing a UPC or EAN")
    func nilBarcodeFindsNothing() async throws {
        try seed(item(upc: nil, ean: "5051892230476", title: nil))
        try seed(item(upc: "043396648654", ean: nil, title: nil))

        let found = try await service.findCopyWithBarcode(nil)

        #expect(found == nil, "A missing barcode matched a copy whose UPC or EAN is also missing")
    }

    // MARK: - Finding by title

    @Test("Finds a copy of the same title by kind and TMDB ID, whatever the edition")
    func findsByTitle() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        let found = try await service.findCopyByTitle(zootopia)

        #expect(found?.upc == "786936900001")
    }

    @Test("The same TMDB ID under the other kind is a different title")
    func kindIsPartOfTheKey() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        // TMDB IDs are only unique per kind (AGENTS.md §5).
        let found = try await service.findCopyByTitle(try title(tmdbId: "1084242", kind: "tv"))

        #expect(found == nil)
    }

    @Test("A title that isn't in the library finds nothing")
    func unknownTitle() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        let found = try await service.findCopyByTitle(try title(tmdbId: "85271", kind: "tv"))

        #expect(found == nil)
    }

    @Test("An unmatched edition has no title, so it never matches other unmatched copies")
    func nilTitleFindsNothing() async throws {
        try seed(item(upc: "0191329282809", ean: nil, title: nil))

        let found = try await service.findCopyByTitle(nil)

        #expect(found == nil, "A missing title matched a saved copy that also has no TMDB match")
    }

    // MARK: - Helpers

    /// Saves straight into the container, so the lookup tests don't depend on
    /// addToLibrary's own duplicate checks.
    private func seed(_ item: LibraryItem) throws {
        container.mainContext.insert(item)
        try container.mainContext.save()
    }

    private var zootopia: Title {
        get throws { try Fixtures.decode(Fixtures.comboPack).title! }
    }

    /// A library entry built the way ConfirmViewModel builds one, from an
    /// edition with just the barcodes and TMDB title under test.
    private func item(upc: String?, ean: String?, title: Title?) throws -> LibraryItem {
        let edition = try edition(upc: upc, ean: ean, title: title)
        return LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: edition.title?.kind.rawValue,
            tmdbId: edition.title?.tmdbId,
            ownedFormats: [DiscFormat.uhd.rawValue],
            edition: edition
        )
    }

    private func edition(upc: String?, ean: String?, title: Title?) throws -> Edition {
        var barcodes: [String] = []
        if let upc { barcodes.append(#""upc": "\#(upc)""#) }
        if let ean { barcodes.append(#""ean": "\#(ean)""#) }

        var titleJSON = ""
        if let title {
            titleJSON = #""title": { "tmdbId": "\#(title.tmdbId)", "kind": "\#(title.kind.rawValue)", "name": "\#(title.name)" },"#
        }

        return try Fixtures.decode("""
        {
          "id": "\(ean ?? upc ?? "unknown")",
          "upcTitle": "Test edition",
          "barcodes": { \(barcodes.joined(separator: ", ")) },
          "format": "4K UHD",
          "packaging": {},
          "editionFlags": {},
          \(titleJSON)
          "unmatchedTitle": \(title == nil)
        }
        """)
    }

    private func title(tmdbId: String, kind: String) throws -> Title {
        try JSONDecoder().decode(Title.self, from: Data(#"{ "tmdbId": "\#(tmdbId)", "kind": "\#(kind)", "name": "Other" }"#.utf8))
    }
}
