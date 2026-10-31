//
//  EditionDecodingTests.swift
//  RemasterTests
//
//  Decoding the backend's normalized edition (backend/docs/edition-schema.md,
//  RMSTR-11 AC: "the app shows the title and format from it").
//

import Foundation
import Testing
@testable import Remaster

@Suite("Edition decoding")
struct EditionDecodingTests {

    @Test("A body with only the always-present keys decodes, everything else unknown")
    func minimalBody() throws {
        let edition = try Fixtures.decode(Fixtures.minimal)

        #expect(edition.id == "0786936900378")
        #expect(edition.title == "WandaVision: The Complete Series")
        #expect(edition.barcodes.upc == nil)
        #expect(edition.barcodes.ean == nil)
        #expect(edition.asin == nil)
        #expect(edition.imdbId == nil)
        #expect(edition.enrichedTitle == nil)
        #expect(edition.kind == nil)
        #expect(edition.year == nil)
        #expect(edition.format == nil)
        #expect(edition.discContents == nil)
        #expect(edition.hdr == nil)
        #expect(edition.masterResolution == nil)
        #expect(edition.releaseDate == nil)
        #expect(edition.distributor == nil)
        #expect(edition.country == nil)
        #expect(edition.coverImageURL == nil)
        #expect(edition.runtime == nil)
        #expect(edition.audio == nil)
        #expect(edition.subtitles == nil)
        #expect(edition.hasDigital == nil)
    }

    @Test("Title and format come through for display")
    func titleAndFormat() throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)

        #expect(edition.title == "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook")
        #expect(edition.format == .uhd)
    }

    @Test("Keys the client doesn't know about are ignored")
    func unknownKeysIgnored() throws {
        let edition = try Fixtures.decode(Fixtures.withUnknownKeys)

        #expect(edition.title == "WandaVision: The Complete Series")
    }

    // MARK: HDR: empty is SDR, absent is unknown

    @Test("An empty hdr list means SDR and stays empty")
    func emptyHDRIsSDR() throws {
        let edition = try Fixtures.decode(Fixtures.sdrBluray)

        let hdr = try #require(edition.hdr)
        #expect(hdr.isEmpty)
    }

    @Test("A 4K edition with no hdr key decodes HDR as unknown, not SDR")
    func absentHDRIsUnknown() throws {
        let edition = try Fixtures.decode(Fixtures.uhdUnknownHDR)

        #expect(edition.format == .uhd)
        #expect(edition.hdr == nil)
    }

    @Test("Multiple HDR formats keep their order and values")
    func multipleHDRFormats() throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)

        #expect(edition.hdr == [.dolbyvision, .hdr10])
    }

    // MARK: True / false / unknown

    @Test("Explicit false packaging and edition flags stay false, not unknown")
    func explicitFalseStaysFalse() throws {
        let edition = try Fixtures.decode(Fixtures.explicitFalse)

        #expect(edition.packaging?.steelbook == false)
        #expect(edition.packaging?.slipcover == true)
        #expect(edition.editionFlags.limited == false)
        #expect(edition.editionFlags.collector == false)
        #expect(edition.editionFlags.special == false)
        #expect(edition.editionFlags.anniversary == false)
        #expect(edition.editionFlags.boxset == false)
        #expect(edition.hasDigital == false)
    }

    @Test("Missing packaging and edition flag keys decode as unknown")
    func missingBooleansAreUnknown() throws {
        let edition = try Fixtures.decode(Fixtures.sdrBluray)

        let packaging = try #require(edition.packaging)
        #expect(packaging.steelbook == nil)
        #expect(packaging.slipcover == nil)
        #expect(packaging.memorabilia == nil)
        #expect(edition.editionFlags.limited == nil)
        #expect(edition.editionFlags.collector == nil)
        #expect(edition.editionFlags.special == nil)
        #expect(edition.editionFlags.anniversary == nil)
        #expect(edition.editionFlags.boxset == nil)
        #expect(edition.hasDigital == nil)
    }

    @Test("Each boolean field has three states", arguments: ["true", "false", nil] as [String?])
    func triStateBooleans(_ value: String?) throws {
        let expected: Bool? = value.map { $0 == "true" }
        let entry = value.map { #""steelbook": \#($0), "slipcover": \#($0), "memorabilia": \#($0)"# } ?? ""
        let flags = value.map {
            #""limited": \#($0), "collector": \#($0), "special": \#($0), "anniversary": \#($0), "boxset": \#($0)"#
        } ?? ""
        let digital = value.map { #", "hasDigital": \#($0)"# } ?? ""
        let json = """
        {
          "id": "0786936900378",
          "title": "Tri-state",
          "barcodes": {},
          "packaging": { \(entry) },
          "editionFlags": { \(flags) }\(digital)
        }
        """

        let edition = try Fixtures.decode(json)

        #expect(edition.packaging?.steelbook == expected)
        #expect(edition.packaging?.slipcover == expected)
        #expect(edition.packaging?.memorabilia == expected)
        #expect(edition.editionFlags.limited == expected)
        #expect(edition.editionFlags.collector == expected)
        #expect(edition.editionFlags.special == expected)
        #expect(edition.editionFlags.anniversary == expected)
        #expect(edition.editionFlags.boxset == expected)
        #expect(edition.hasDigital == expected)
    }

    // MARK: Canonical enum spellings

    @Test("Disc formats decode from the backend's spellings", arguments: [
        ("DVD", DiscFormat.dvd),
        ("Blu-ray", DiscFormat.bluray),
        ("4K UHD", DiscFormat.uhd),
    ])
    func discFormatSpellings(_ raw: String, _ expected: DiscFormat) throws {
        let edition = try Fixtures.decode(Fixtures.minimal(with: "format", "\"\(raw)\""))

        #expect(edition.format == expected)
    }

    @Test("HDR formats decode from the backend's spellings", arguments: [
        ("HDR10", HDRFormat.hdr10),
        ("HDR10+", HDRFormat.hdr10plus),
        ("Dolby Vision", HDRFormat.dolbyvision),
    ])
    func hdrSpellings(_ raw: String, _ expected: HDRFormat) throws {
        let edition = try Fixtures.decode(Fixtures.minimal(with: "hdr", "[\"\(raw)\"]"))

        #expect(edition.hdr == [expected])
    }

    @Test("Kind decodes from TMDB's naming", arguments: [
        ("movie", EditionKind.movie),
        ("tv", EditionKind.tv),
    ])
    func kindSpellings(_ raw: String, _ expected: EditionKind) throws {
        let edition = try Fixtures.decode(Fixtures.minimal(with: "kind", "\"\(raw)\""))

        #expect(edition.kind == expected)
    }

    @Test("Master resolution decodes", arguments: [
        ("native", Resolution.native),
        ("upscaled", Resolution.upscaled),
    ])
    func masterResolutionSpellings(_ raw: String, _ expected: Resolution) throws {
        let edition = try Fixtures.decode(Fixtures.minimal(with: "masterResolution", "\"\(raw)\""))

        #expect(edition.masterResolution == expected)
    }

    // MARK: Disc contents

    @Test("A combo pack lists the 4K disc first, and format is the highest in the set")
    func comboPackDiscs() throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)

        let discs = try #require(edition.discContents)
        try #require(discs.count == 2)
        #expect(discs[0].format == .uhd)
        #expect(discs[1].format == .bluray)
        #expect(edition.format == .uhd)
    }

    @Test("\"Region free\" decodes as region free with no region list")
    func regionFree() throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)

        let disc = try #require(edition.discContents?.first)
        #expect(disc.regionFree == true)
        #expect(disc.regions == nil)
    }

    @Test("A list of region codes decodes as region locked to those codes")
    func regionList() throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)

        let disc = try #require(edition.discContents?.last)
        #expect(disc.regions == ["A", "B"])
        #expect(disc.regionFree == false)
    }

    @Test("A disc with no region decodes with the region unknown")
    func regionAbsent() throws {
        let edition = try Fixtures.decode(Fixtures.discWithoutRegion)

        let disc = try #require(edition.discContents?.first)
        #expect(disc.format == .uhd)
        #expect(disc.regionFree == nil)
        #expect(disc.regions == nil)
    }

    @Test("The disc count is the length of discContents")
    func discCount() throws {
        let edition = try Fixtures.decode(Fixtures.fourteenDVDs)

        let discs = try #require(edition.discContents)
        #expect(discs.count == 14)
        #expect(discs.allSatisfy { $0.format == .dvd && $0.regions == ["1"] })
    }

    @Test("Disc regions survive encoding and decoding again")
    func discRegionsRoundTrip() throws {
        let original = try Fixtures.decode(Fixtures.comboPack)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Edition.self, from: encoded)

        let discs = try #require(decoded.discContents)
        try #require(discs.count == 2)
        #expect(discs[0].regionFree == true)
        #expect(discs[0].regions == nil)
        #expect(discs[1].regionFree == false)
        #expect(discs[1].regions == ["A", "B"])
    }

    // MARK: Display details

    @Test("Display details decode with their documented types")
    func displayDetails() throws {
        let edition = try Fixtures.decode(Fixtures.comboPack)

        #expect(edition.coverImageURL == URL(string: "https://imagestorage.org/786936900001.jpg"))
        #expect(edition.runtime == 108)
        #expect(edition.year == 2025)
        #expect(edition.releaseDate == "2026-03-03")
        #expect(edition.barcodes.upc == "786936900001")
        #expect(edition.barcodes.ean == "0786936900001")
    }

    // MARK: Fixtures

    @Test("Every JSON fixture loads from the test bundle and decodes", arguments: [
        "minimal", "combo-pack", "explicit-false", "sdr-bluray",
        "uhd-unknown-hdr", "fourteen-dvds", "disc-without-region", "unknown-keys",
    ])
    func bundledFixtureDecodes(_ name: String) throws {
        let json = Fixtures.load(name)
        try #require(!json.isEmpty)

        let edition = try Fixtures.decode(json)

        #expect(!edition.id.isEmpty)
        #expect(!edition.title.isEmpty)
    }
}
