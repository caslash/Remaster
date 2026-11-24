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
    private let posters = RecordingPosterStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: LibraryItem.self, configurations: configuration)
        self.container = container

        // A stand-in poster store, so saving never downloads a real poster
        // (and never hits another suite's URLProtocol stub).
        let posters = self.posters
        Container.shared.reset()
        Container.shared.modelContainer.register { container }
        Container.shared.posterService.register { posters }
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

    @Test("A new copy's formats are saved highest first, whatever order they were picked in")
    func addSortsFormats() async throws {
        let combo = try item(upc: "043396648654", ean: nil, title: nil)
        combo.ownedFormats = [DiscFormat.dvd.rawValue, DiscFormat.bluray.rawValue, DiscFormat.uhd.rawValue]

        try await service.addToLibrary(combo)

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.ownedFormats == ["4K UHD", "Blu-ray", "DVD"])
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
        #expect(saved.getEdition()?.upcTitle == "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook")
        #expect(saved.getEdition()?.hdr?.count == 2)
    }

    @Test("The fields the library grid shows are saved with the copy (RMSTR-18)")
    func addSavesGridFields() async throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)
        try await service.addToLibrary(LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: edition.title?.kind.rawValue,
            tmdbId: edition.title?.tmdbId,
            ownedFormats: [DiscFormat.uhd.rawValue],
            edition: edition
        ))

        // Read back from a separate context, so this checks what was stored,
        // not the values still sitting on the inserted object.
        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.displayTitle == "Zootopia 2")
        #expect(saved.posterURL == URL(string: "https://image.tmdb.org/t/p/w500/poster.jpg"))
        #expect(saved.year == 2025)
    }

    // MARK: - Posters (RMSTR-18 AC 3)

    @Test("A saved copy with a poster URL has its poster stored")
    func saveRequestsPoster() async throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)
        try await service.addToLibrary(LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: edition.title?.kind.rawValue,
            tmdbId: edition.title?.tmdbId,
            ownedFormats: [DiscFormat.uhd.rawValue],
            edition: edition
        ))

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        let request = try #require(await posters.waitForSave(), "No poster was requested after saving")
        #expect(request.id == saved.persistentModelID, "The poster was requested for another item, or with a temporary ID")
        #expect(request.url == URL(string: "https://image.tmdb.org/t/p/w500/poster.jpg"))
    }

    @Test("A copy with no poster URL doesn't request a poster")
    func noPosterURLNoRequest() async throws {
        try await service.addToLibrary(item(upc: "043396648654", ean: nil, title: nil))

        #expect(await posters.waitForSave(timeout: .milliseconds(300)) == nil)
    }

    @Test("A poster that fails to download doesn't fail the save")
    func posterFailureDoesNotFailSave() async throws {
        posters.failSaves = true
        let edition = try Fixtures.decode(Fixtures.comboPack)

        // The copy is saved either way; the backfill retries the poster later.
        // Throwing here would tell the collector the save failed when it didn't.
        try await service.addToLibrary(LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: edition.title?.kind.rawValue,
            tmdbId: edition.title?.tmdbId,
            ownedFormats: [DiscFormat.uhd.rawValue],
            edition: edition
        ))

        #expect(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).count == 1)
    }

    @Test("Saving doesn't wait for the poster to download")
    func saveDoesNotWaitForPoster() async throws {
        posters.saveDelay = .seconds(2)
        let edition = try Fixtures.decode(Fixtures.comboPack)
        let clock = ContinuousClock()

        // The Added to Library banner has to appear within 1 s of Add.
        let elapsed = try await clock.measure {
            try await service.addToLibrary(LibraryItem(
                upc: edition.barcodes.upc,
                ean: edition.barcodes.ean,
                kind: edition.title?.kind.rawValue,
                tmdbId: edition.title?.tmdbId,
                ownedFormats: [DiscFormat.uhd.rawValue],
                edition: edition
            ))
        }

        #expect(elapsed < .seconds(1), "addToLibrary took \(elapsed), waiting on the poster download")
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

    // MARK: - Rescanning with a format the copy doesn't have (RMSTR-14)

    @Test("The same disc with its formats in another order is still a plain duplicate")
    func formatOrderDoesNotMatter() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.bluray.rawValue, DiscFormat.uhd.rawValue]

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(rescan)
        }
    }

    @Test("Rescanning with fewer formats than the copy has is a plain duplicate")
    func subsetOfFormatsIsDuplicate() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue]

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(rescan)
        }
    }

    @Test("Rescanning with a new format offers only the format the copy is missing")
    func newFormatIsOffered() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.uhd.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]

        await #expect(throws: LibraryError.extraFormat(formats: ["Blu-ray"])) {
            try await self.service.addToLibrary(rescan)
        }
    }

    @Test("A saved copy with no formats counts as owning none of them")
    func copyWithNoFormatsIsOfferedAll() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = nil
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue]

        await #expect(throws: LibraryError.extraFormat(formats: ["4K UHD"])) {
            try await self.service.addToLibrary(rescan)
        }
    }

    @Test("A rescan with no formats is still matched by its barcode")
    func rescanWithNoFormatsIsDuplicate() async throws {
        try seed(item(upc: "043396648654", ean: nil, title: nil))

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = nil

        await #expect(throws: LibraryError.duplicate) {
            try await self.service.addToLibrary(rescan)
        }
    }

    // MARK: - Adding formats to the existing copy

    @Test("Adding a format updates the saved copy instead of adding a second one")
    func addsMissingFormatToCopy() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.uhd.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        let updated = try await service.addFormatsToExistingCopy(rescan)

        // A separate context only sees what the main context actually saved.
        let saved = try ModelContext(container).fetch(FetchDescriptor<LibraryItem>())
        #expect(saved.count == 1, "Adding a format saved another copy")
        #expect(Set(saved.first?.ownedFormats ?? []) == ["4K UHD", "Blu-ray"])
        #expect(Set(updated.ownedFormats ?? []) == ["4K UHD", "Blu-ray"], "The returned copy doesn't have the merged formats")
    }

    @Test("Adding a format returns the saved copy, not the rescanned item")
    func returnsTheSavedCopy() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.dvd.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        let updated = try await service.addFormatsToExistingCopy(rescan)

        // The banner shows these formats, so they must be the copy's (DVD kept), not the rescan's.
        #expect(updated.persistentModelID == owned.persistentModelID, "Returned an object other than the saved copy")
        #expect(Set(updated.ownedFormats ?? []) == ["4K UHD", "DVD", "Blu-ray"])
    }

    @Test("A copy saved with no formats gets the missing ones")
    func fillsCopyWithNoFormats() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = nil
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue]
        _ = try await service.addFormatsToExistingCopy(rescan)

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.ownedFormats == ["4K UHD"])
    }

    @Test("A copy with no formats gets the missing ones highest first")
    func fillsCopyWithNoFormatsSorted() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = nil
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.bluray.rawValue, DiscFormat.uhd.rawValue]
        let updated = try await service.addFormatsToExistingCopy(rescan)

        #expect(updated.ownedFormats == ["4K UHD", "Blu-ray"])
    }

    @Test("Adding a format the copy already has changes nothing")
    func nothingMissingChangesNothing() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue]
        _ = try await service.addFormatsToExistingCopy(rescan)

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.ownedFormats == ["4K UHD", "Blu-ray"])
    }

    @Test("A copy with nothing missing keeps its formats in the order they were saved")
    func nothingMissingKeepsSavedOrder() async throws {
        // New saves are sorted highest first, but a copy from before that (or
        // seeded directly, as here) can still be in another order.
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = [DiscFormat.bluray.rawValue, DiscFormat.uhd.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue]
        _ = try await service.addFormatsToExistingCopy(rescan)

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.ownedFormats == ["Blu-ray", "4K UHD"], "A copy with nothing to add was rewritten")
    }

    @Test("A saved format the app doesn't recognise is kept, after the known ones")
    func unknownSavedFormatIsKeptLast() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: nil)
        owned.ownedFormats = ["BluRay", DiscFormat.dvd.rawValue]
        try seed(owned)

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue]
        let updated = try await service.addFormatsToExistingCopy(rescan)

        #expect(updated.ownedFormats == ["4K UHD", "DVD", "BluRay"])
    }

    @Test("Adding a format keeps the copy's saved edition snapshot")
    func addingFormatKeepsSnapshot() async throws {
        let owned = try item(upc: "043396648654", ean: nil, title: zootopia)
        owned.ownedFormats = [DiscFormat.uhd.rawValue]
        try seed(owned)
        let snapshot = owned.editionData

        let rescan = try item(upc: "043396648654", ean: nil, title: zootopia)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        _ = try await service.addFormatsToExistingCopy(rescan)

        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).first)
        #expect(saved.editionData == snapshot, "Adding a format rewrote the saved edition")
    }

    @Test("With two copies of the disc, only one of them gets the format")
    func onlyOneCopyGetsTheFormat() async throws {
        for _ in 0..<2 {
            let copy = try item(upc: "043396648654", ean: nil, title: nil)
            copy.ownedFormats = [DiscFormat.uhd.rawValue]
            try seed(copy)
        }

        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]
        _ = try await service.addFormatsToExistingCopy(rescan)

        let saved = try ModelContext(container).fetch(FetchDescriptor<LibraryItem>())
        #expect(saved.count == 2)
        #expect(saved.filter { $0.ownedFormats?.contains("Blu-ray") == true }.count == 1, "The format went to more or fewer than one copy")
    }

    @Test("Adding a format when no copy matches fails instead of pretending it worked")
    func noCopyToUpdateThrows() async throws {
        let rescan = try item(upc: "043396648654", ean: nil, title: nil)
        rescan.ownedFormats = [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue]

        await #expect(throws: LibraryError.duplicateNotFound) {
            _ = try await self.service.addFormatsToExistingCopy(rescan)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).isEmpty, "A copy was saved when there was nothing to update")
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

        let zootopia = try zootopia
        let found = try await service.findCopyByTitle(kind: zootopia.kind.rawValue, tmdbId: zootopia.tmdbId)

        #expect(found?.upc == "786936900001")
    }

    @Test("The same TMDB ID under the other kind is a different title")
    func kindIsPartOfTheKey() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        // TMDB IDs are only unique per kind (AGENTS.md §5).
        let found = try await service.findCopyByTitle(kind: "tv", tmdbId: "1084242")

        #expect(found == nil)
    }

    @Test("A title that isn't in the library finds nothing")
    func unknownTitle() async throws {
        try seed(item(upc: "786936900001", ean: nil, title: zootopia))

        let found = try await service.findCopyByTitle(kind: "tv", tmdbId: "85271")

        #expect(found == nil)
    }

    @Test("An unmatched edition has no title, so it never matches other unmatched copies")
    func nilTitleFindsNothing() async throws {
        try seed(item(upc: "0191329282809", ean: nil, title: nil))

        let found = try await service.findCopyByTitle(kind: nil, tmdbId: nil)

        #expect(found == nil, "A missing title matched a saved copy that also has no TMDB match")
    }

    @Test("Half a title key never matches a copy that's missing the same half")
    func partialTitleKeyFindsNothing() async throws {
        let unmatched = try item(upc: "0191329282809", ean: nil, title: nil)
        unmatched.kind = "movie"
        try seed(unmatched)

        let found = try await service.findCopyByTitle(kind: "movie", tmdbId: nil)

        #expect(found == nil, "A kind with no TMDB ID matched a copy that also has no TMDB ID")
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
}
