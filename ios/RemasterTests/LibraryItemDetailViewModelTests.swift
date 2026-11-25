//
//  LibraryItemDetailViewModelTests.swift
//  RemasterTests
//
//  The library item detail screen (RMSTR-18 AC 5 and 6): the saved edition it
//  shows, the copy count, and Delete. The Edition row's wording is
//  Edition.editionText, tested in EditionTextTests.
//
//  The view model resolves LibraryManaging and PosterStore from Container.shared
//  when it's created, so each test registers a real LibraryService on a fresh
//  in-memory container, and a stand-in poster store, first.
//  Each test gets its own Container.shared (FactoryTesting's .container trait),
//  so suites that register stand-ins can run in parallel without swapping each
//  other's registrations.
//

import FactoryKit
import FactoryTesting
import Foundation
import SwiftData
import Testing
@testable import Remaster

@MainActor
@Suite("LibraryItemDetailViewModel", .container)
final class LibraryItemDetailViewModelTests {
    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: LibraryItem.self, configurations: configuration)
        self.container = container

        let posters = RecordingPosterStore()
        Container.shared.modelContainer.register { container }
        Container.shared.posterService.register { posters }
        // Registered explicitly: the test host app has already created a
        // LibraryService singleton on its real store, and .container copies the
        // singleton cache into each test.
        Container.shared.libraryService.register { LibraryService() }
    }

    // MARK: - Edition (AC 5: edition info if known)

    @Test("The saved edition snapshot is what the screen shows")
    func showsSavedEdition() throws {
        let item = try item(upc: "786936900001", ean: nil, packaging: #"{ "steelbook": true }"#)

        let viewModel = makeViewModel(for: item)

        #expect(viewModel.edition?.upcTitle == "Test edition")
        #expect(viewModel.edition?.editionText == "Steelbook")
    }

    @Test("A copy saved without an edition has no edition to show")
    func noEdition() {
        let item = LibraryItem(upc: "786936900001", ean: nil, kind: nil, tmdbId: nil, ownedFormats: nil, edition: nil)

        let viewModel = makeViewModel(for: item)

        #expect(viewModel.edition == nil)
    }

    // MARK: - Copies

    @Test("One copy saved with both a UPC and an EAN counts as one copy")
    func oneCopyWithBothBarcodes() throws {
        // Every sample edition the app ships with has both barcodes.
        let item = try item(upc: "043396648654", ean: "0043396648654")
        try seed(item)

        let viewModel = makeViewModel(for: item)
        viewModel.refreshCopies()

        #expect(viewModel.copies == 1, "A single copy was counted \(viewModel.copies) times")
    }

    @Test("Two copies of the same disc count as two")
    func twoCopiesOfTheSameDisc() throws {
        let first = try item(upc: "043396648654", ean: "0043396648654")
        try seed(first)
        try seed(item(upc: "043396648654", ean: "0043396648654"))

        let viewModel = makeViewModel(for: first)
        viewModel.refreshCopies()

        #expect(viewModel.copies == 2)
    }

    @Test("A copy with only an EAN counts as one")
    func eanOnlyCopy() throws {
        let item = try item(upc: nil, ean: "5051892230476")
        try seed(item)

        let viewModel = makeViewModel(for: item)
        viewModel.refreshCopies()

        #expect(viewModel.copies == 1)
    }

    @Test("Copies of other discs aren't counted")
    func otherDiscsAreNotCounted() throws {
        let item = try item(upc: "043396648654", ean: nil)
        try seed(item)
        try seed(self.item(upc: "786936900001", ean: nil))

        let viewModel = makeViewModel(for: item)
        viewModel.refreshCopies()

        #expect(viewModel.copies == 1)
    }

    // MARK: - Delete (AC 6)

    @Test("Delete removes the copy from the store and then finishes")
    func deleteRemovesAndCompletes() throws {
        let item = try item(upc: "043396648654", ean: nil)
        try seed(item)
        let viewModel = makeViewModel(for: item)
        var completions = 0

        viewModel.deleteItem { completions += 1 }

        #expect(completions == 1)
        #expect(viewModel.error == nil)
        #expect(try ModelContext(container).fetch(FetchDescriptor<LibraryItem>()).isEmpty, "The copy is still in the store")
    }

    @Test("Delete leaves the user's other copies alone")
    func deleteLeavesOtherItems() throws {
        let remove = try item(upc: "043396648654", ean: nil)
        let keep = try item(upc: "786936900001", ean: nil)
        try seed(remove)
        try seed(keep)
        let viewModel = makeViewModel(for: remove)

        viewModel.deleteItem { }

        let saved = try ModelContext(container).fetch(FetchDescriptor<LibraryItem>())
        #expect(saved.map(\.upc) == ["786936900001"])
    }

    // MARK: - Helpers

    private func makeViewModel(for item: LibraryItem) -> LibraryItemDetailViewModel {
        LibraryItemDetailViewModel(libraryItem: item)
    }

    private func seed(_ item: LibraryItem) throws {
        container.mainContext.insert(item)
        try container.mainContext.save()
    }

    private func item(upc: String?, ean: String?, packaging: String = "{}", flags: String = "{}") throws -> LibraryItem {
        var barcodes: [String] = []
        if let upc { barcodes.append(#""upc": "\#(upc)""#) }
        if let ean { barcodes.append(#""ean": "\#(ean)""#) }

        let edition = try Fixtures.decode("""
        {
          "id": "\(ean ?? upc ?? "unknown")",
          "upcTitle": "Test edition",
          "barcodes": { \(barcodes.joined(separator: ", ")) },
          "format": "4K UHD",
          "packaging": \(packaging),
          "editionFlags": \(flags),
          "unmatchedTitle": true
        }
        """)

        return LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: nil,
            tmdbId: nil,
            ownedFormats: [DiscFormat.uhd.rawValue],
            edition: edition
        )
    }
}
