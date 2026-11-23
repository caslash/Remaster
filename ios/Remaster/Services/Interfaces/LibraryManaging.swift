//
//  LibraryManaging.swift
//  Remaster
//
//  Created by Cameron Slash on 11/21/26.
//

protocol LibraryManaging {
    func addToLibrary(_ item: LibraryItem, forceDuplicate: Bool) async throws
    func findCopyWithBarcode(_ barcode: String?) async throws -> LibraryItem?
    func findCopyByTitle(_ title: Title?) async throws -> LibraryItem?
    func addFormatsToExistingCopy(_ item: LibraryItem) async throws -> LibraryItem
}
