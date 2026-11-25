//
//  LibraryItemTests.swift
//  RemasterTests
//
//  The library grid (RMSTR-18) reads a few fields straight off LibraryItem
//  instead of decoding the saved edition for every card. These tests cover how
//  init fills those fields from the edition, the fallbacks when there's no TMDB
//  match, the owned formats being cleaned up, and the full edition still being
//  kept for the detail screen.
//
//  LibraryItem is built here without a container: init only sets properties.
//

import Foundation
import Testing
@testable import Remaster

@MainActor
@Suite("LibraryItem")
struct LibraryItemTests {

    // MARK: - Grid fields

    @Test("A matched edition shows its TMDB name, poster and year")
    func matchedEditionUsesTMDB() throws {
        let item = try item(from: Fixtures.comboPack)

        // The TMDB name, not the UPCMDB title with its format and packaging text.
        #expect(item.displayTitle == "Zootopia 2")
        #expect(item.posterURL == URL(string: "https://image.tmdb.org/t/p/w500/poster.jpg"))
        #expect(item.year == 2025)
    }

    @Test("An unmatched edition falls back to its UPC title, cover image and year")
    func unmatchedEditionFallsBack() throws {
        let item = try item(from: """
        {
          "id": "0786936900002",
          "upcTitle": "Some Disc (Blu-ray)",
          "year": 1999,
          "coverImageURL": "https://imagestorage.org/0786936900002.jpg",
          "barcodes": { "upc": "786936900002" },
          "packaging": {},
          "editionFlags": {},
          "unmatchedTitle": true
        }
        """)

        #expect(item.displayTitle == "Some Disc (Blu-ray)")
        #expect(item.posterURL == URL(string: "https://imagestorage.org/0786936900002.jpg"))
        #expect(item.year == 1999)
    }

    @Test("A TMDB title with no poster falls back to the cover image")
    func titleWithoutPosterUsesCover() throws {
        let item = try item(from: """
        {
          "id": "0786936900003",
          "upcTitle": "Obscure Film [DVD]",
          "coverImageURL": "https://imagestorage.org/0786936900003.jpg",
          "barcodes": { "upc": "786936900003" },
          "packaging": {},
          "editionFlags": {},
          "title": { "tmdbId": "123", "kind": "movie", "name": "Obscure Film", "year": 1987 },
          "unmatchedTitle": false
        }
        """)

        #expect(item.displayTitle == "Obscure Film")
        #expect(item.posterURL == URL(string: "https://imagestorage.org/0786936900003.jpg"))
        #expect(item.year == 1987)
    }

    @Test("An edition with no poster or cover has no poster URL, so the grid shows the placeholder")
    func noImagesMeansNoPosterURL() throws {
        let item = try item(from: Fixtures.minimal)

        #expect(item.posterURL == nil)
        #expect(item.displayTitle == "WandaVision: The Complete Series")
        #expect(item.year == nil)
    }

    @Test("No edition at all leaves the grid fields empty")
    func noEdition() {
        let item = LibraryItem(upc: "786936900004", ean: nil, kind: nil, tmdbId: nil, ownedFormats: nil, edition: nil)

        #expect(item.displayTitle == nil)
        #expect(item.posterURL == nil)
        #expect(item.year == nil)
        #expect(item.getEdition() == nil)
    }

    // MARK: - Owned formats

    @Test("Owned formats are de-duplicated and saved highest first")
    func formatsAreUniqueAndSorted() throws {
        let item = try item(from: Fixtures.comboPack, ownedFormats: ["DVD", "4K UHD", "DVD", "Blu-ray", "4K UHD"])

        #expect(item.ownedFormats == ["4K UHD", "Blu-ray", "DVD"])
    }

    @Test("A format the app doesn't recognise is kept, after the known ones")
    func unknownFormatIsKeptLast() throws {
        let item = try item(from: Fixtures.comboPack, ownedFormats: ["BluRay", "DVD"])

        #expect(item.ownedFormats == ["DVD", "BluRay"])
    }

    @Test("No owned formats stays nil rather than becoming an empty list")
    func nilFormatsStayNil() throws {
        let item = try item(from: Fixtures.comboPack, ownedFormats: nil)

        #expect(item.ownedFormats == nil)
    }

    // MARK: - Edition snapshot

    @Test("The full edition is still kept for the detail screen")
    func editionRoundTrips() throws {
        let item = try item(from: Fixtures.comboPack)

        #expect(item.editionData != nil, "The edition wasn't encoded")
        let edition = try #require(item.getEdition())
        #expect(edition.upcTitle == "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook")
        #expect(edition.hdr?.count == 2)
        #expect(edition.title?.tmdbId == item.tmdbId)
    }

    // MARK: - Helpers

    private func item(from json: String, ownedFormats: [DiscFormat.RawValue]? = [DiscFormat.uhd.rawValue]) throws -> LibraryItem {
        let edition = try Fixtures.decode(json)
        return LibraryItem(
            upc: edition.barcodes.upc,
            ean: edition.barcodes.ean,
            kind: edition.title?.kind.rawValue,
            tmdbId: edition.title?.tmdbId,
            ownedFormats: ownedFormats,
            edition: edition
        )
    }
}
