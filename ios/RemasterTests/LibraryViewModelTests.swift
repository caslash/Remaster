//
//  LibraryViewModelTests.swift
//  RemasterTests
//
//  Deleting from a library card's context menu (RMSTR-18 AC 6): the delete goes
//  through LibraryManaging, and a failure is reported instead of swallowed.
//
//  LibraryViewModel resolves LibraryManaging from Container.shared when it's
//  created, so each test registers a stand-in first. Each test gets its own
//  Container.shared (FactoryTesting's .container trait).
//

import FactoryKit
import FactoryTesting
import Foundation
import SwiftData
import Testing
@testable import Remaster

@MainActor
@Suite("LibraryViewModel", .container)
final class LibraryViewModelTests {
    private let library = RecordingLibrary()

    init() {
        Container.shared.libraryService.register { [library] in library }
    }

    @Test("Deleting from the card menu deletes that copy through the library service")
    func deleteGoesThroughTheService() {
        let item = LibraryItem(upc: "043396648654", ean: nil, kind: nil, tmdbId: nil, ownedFormats: nil, edition: nil)
        let viewModel = LibraryViewModel()

        viewModel.deleteItem(item)

        #expect(library.deleted.count == 1)
        #expect(library.deleted.first === item, "A different copy was deleted")
        #expect(viewModel.error == nil)
    }

    @Test("A delete that fails is reported, not swallowed")
    func failedDeleteIsReported() {
        library.deleteError = LibraryError.duplicateNotFound
        let item = LibraryItem(upc: "043396648654", ean: nil, kind: nil, tmdbId: nil, ownedFormats: nil, edition: nil)
        let viewModel = LibraryViewModel()

        viewModel.deleteItem(item)

        #expect(viewModel.error != nil, "The failed delete wasn't reported")
        #expect((viewModel.error as? LibraryError) == .duplicateNotFound)
    }

    @Test("A successful delete after a failed one doesn't leave the old error showing")
    func successAfterFailure() {
        let item = LibraryItem(upc: "043396648654", ean: nil, kind: nil, tmdbId: nil, ownedFormats: nil, edition: nil)
        let viewModel = LibraryViewModel()
        library.deleteError = LibraryError.duplicateNotFound
        viewModel.deleteItem(item)
        viewModel.error = nil   // the alert's OK clears its binding

        library.deleteError = nil
        viewModel.deleteItem(item)

        #expect(viewModel.error == nil)
    }
}

/// A LibraryManaging that records deletes and can be told to fail them. The
/// other requirements aren't used by LibraryViewModel.
final class RecordingLibrary: LibraryManaging {
    var deleted: [LibraryItem] = []
    var deleteError: Error?

    func deleteFromLibrary(_ item: LibraryItem) throws {
        if let deleteError { throw deleteError }
        deleted.append(item)
    }

    nonisolated func addToLibrary(_ item: LibraryItem, forceDuplicate: Bool) async throws { }
    func findCopyWithBarcode(_ barcode: String?) throws -> LibraryItem? { nil }
    func findAmountOfCopiesWithBarcode(upc: String?, ean: String?) throws -> Int { 0 }
    func findCopyByTitle(kind: String?, tmdbId: String?) throws -> LibraryItem? { nil }
    nonisolated func addFormatsToExistingCopy(_ item: LibraryItem) async throws -> LibraryItem { item }
}
