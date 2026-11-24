//
//  LibraryManaging.swift
//  Remaster
//
//  Created by Cameron Slash on 11/21/26.
//

protocol LibraryManaging {
    func addToLibrary(_ item: LibraryItem, forceDuplicate: Bool) async throws
    func findCopyWithBarcode(_ barcode: String?) throws -> LibraryItem?
    func findAmountOfCopiesWithBarcode(_ barcode: String?) throws -> Int
    func findCopyByTitle(kind: String?, tmdbId: String?) throws -> LibraryItem?
    func addFormatsToExistingCopy(_ item: LibraryItem) async throws -> LibraryItem
    func deleteFromLibrary(_ item: LibraryItem) throws
}
