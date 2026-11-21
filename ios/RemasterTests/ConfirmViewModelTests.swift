//
//  ConfirmViewModelTests.swift
//  RemasterTests
//
//  The confirm sheet's logic (RMSTR-14): the "Format you own" picker, the
//  combo-pack toggle and the formats that get saved, plus the HDR and Edition
//  rows and the summary card's chip.
//
//  Editions are built from small JSON bodies so each test states exactly the
//  fields it depends on. Absent means unknown (backend/docs/edition-schema.md).
//

import Foundation
import Testing
@testable import Remaster

@MainActor
@Suite("ConfirmViewModel")
struct ConfirmViewModelTests {

    // MARK: - Format you own and the combo-pack toggle

    @Test("The picker starts on the format the lookup reported")
    func pickerStartsOnLookupFormat() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))

        #expect(viewModel.discFormat == .uhd)
    }

    @Test("A 4K + Blu-ray combo with 4K picked offers Blu-ray and saves both")
    func comboWithLookupFormatPicked() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))

        #expect(viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == "Blu-ray")
        #expect(viewModel.includesOtherFormats)
        #expect(viewModel.ownedFormats == [.uhd, .bluray])
    }

    @Test("Picking the combo's other disc offers the rest of the set")
    func comboWithOtherDiscPicked() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))

        viewModel.discFormat = .bluray

        #expect(viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == "4K UHD")
        #expect(viewModel.ownedFormats == [.bluray, .uhd])
    }

    @Test("Picking a format that isn't in the set hides the toggle and saves only that format")
    func formatOutsideSetHidesToggle() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))

        viewModel.discFormat = .dvd

        #expect(!viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.includesOtherFormats, "The toggle value is on, but hidden, so it mustn't count")
        #expect(viewModel.ownedFormats == [.dvd])
    }

    @Test("Turning the toggle off saves only the picked format")
    func toggleOffSavesPickedFormat() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))

        viewModel.includesOtherFormats = false

        #expect(viewModel.selectedFormatIncludedAndHasLeftover, "The toggle stays visible when switched off")
        #expect(viewModel.ownedFormats == [.uhd])
    }

    @Test("Changing the picked format switches the toggle back on")
    func pickerChangeResetsToggle() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))
        viewModel.includesOtherFormats = false

        viewModel.discFormat = .bluray

        #expect(viewModel.includesOtherFormats)
        #expect(viewModel.ownedFormats == [.bluray, .uhd])
    }

    @Test("Two discs of the same format aren't a combo pack")
    func sameFormatDiscsAreNotCombo() throws {
        let viewModel = ConfirmViewModel(edition: try edition(
            format: "4K UHD",
            discs: ["4K UHD", "4K UHD"]
        ))

        #expect(!viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == nil)
        #expect(viewModel.ownedFormats == [.uhd])
    }

    @Test("Fourteen DVDs are still one format")
    func manyDiscsOneFormat() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.fourteenDVDs))

        #expect(!viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.ownedFormats == [.dvd])
    }

    @Test("With no format reported, nothing is picked, the toggle is hidden and nothing would be saved")
    func unknownFormat() throws {
        let viewModel = ConfirmViewModel(edition: try edition(
            format: nil,
            discs: ["4K UHD", "Blu-ray"]
        ))

        #expect(viewModel.discFormat == nil)
        #expect(!viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == nil)
        #expect(viewModel.ownedFormats.isEmpty)
    }

    @Test("Once a format is picked for an edition with no reported format, the toggle appears")
    func unknownFormatThenPicked() throws {
        let viewModel = ConfirmViewModel(edition: try edition(
            format: nil,
            discs: ["4K UHD", "Blu-ray"]
        ))

        viewModel.discFormat = .uhd

        #expect(viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == "Blu-ray")
        #expect(viewModel.ownedFormats == [.uhd, .bluray])
    }

    @Test("A three-format set lists both leftovers and saves all three")
    func threeFormatSet() throws {
        let viewModel = ConfirmViewModel(edition: try edition(
            format: "4K UHD",
            discs: ["4K UHD", "Blu-ray", "DVD"]
        ))

        #expect(viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == "DVD, Blu-ray")
        #expect(Set(viewModel.ownedFormats) == [.uhd, .bluray, .dvd])
        #expect(viewModel.ownedFormats.first == .uhd, "The picked format comes first")
    }

    @Test("A thin record with no disc list has no toggle and saves the picked format")
    func noDiscContents() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.sdrBluray))

        #expect(!viewModel.selectedFormatIncludedAndHasLeftover)
        #expect(viewModel.secondFormatName == nil)
        #expect(viewModel.ownedFormats == [.bluray])
    }

    // MARK: - HDR row

    @Test("The HDR row tells unknown apart from SDR", arguments: [
        HDRCase(json: nil, expected: "Unknown"),
        HDRCase(json: "[]", expected: "SDR"),
        HDRCase(json: #"["HDR10"]"#, expected: "HDR10"),
        HDRCase(json: #"["Dolby Vision", "HDR10"]"#, expected: "Dolby Vision, HDR10"),
    ])
    func hdrText(_ testCase: HDRCase) throws {
        let viewModel = ConfirmViewModel(edition: try edition(hdr: testCase.json))

        #expect(viewModel.hdrFormats == testCase.expected)
    }

    // MARK: - Edition row

    @Test("The Edition row names the packaging only when it's known", arguments: [
        EditionCase("Every field an explicit false is Standard",
                    packaging: #"{ "steelbook": false, "slipcover": false }"#,
                    flags: #"{ "limited": false, "collector": false, "special": false, "anniversary": false, "boxset": false }"#,
                    expected: "Standard"),
        EditionCase("Nothing known is Unknown, not Standard",
                    packaging: "{}", flags: "{}", expected: "Unknown"),
        EditionCase("No packaging object at all is Unknown",
                    packaging: nil, flags: "{}", expected: "Unknown"),
        EditionCase("Standard needs every flag known, not just some",
                    packaging: #"{ "steelbook": false }"#, flags: #"{ "limited": false }"#,
                    expected: "Unknown"),
        EditionCase("A steelbook",
                    packaging: #"{ "steelbook": true }"#, flags: "{}", expected: "Steelbook"),
        EditionCase("Steelbook wins over a collector's flag",
                    packaging: #"{ "steelbook": true }"#, flags: #"{ "collector": true }"#,
                    expected: "Steelbook"),
        EditionCase("A flag is shown even with no packaging object",
                    packaging: nil, flags: #"{ "collector": true }"#, expected: "Collector's"),
        EditionCase("A flag is shown when packaging is empty",
                    packaging: "{}", flags: #"{ "anniversary": true }"#, expected: "Anniversary"),
        EditionCase("Limited",
                    packaging: #"{ "steelbook": false }"#, flags: #"{ "limited": true }"#, expected: "Limited"),
        EditionCase("Box set",
                    packaging: "{}", flags: #"{ "boxset": true }"#, expected: "Boxset"),
        EditionCase("Special",
                    packaging: "{}", flags: #"{ "special": true }"#, expected: "Special"),
    ])
    func editionText(_ testCase: EditionCase) throws {
        let viewModel = ConfirmViewModel(edition: try edition(
            packaging: testCase.packaging,
            flags: testCase.flags
        ))

        #expect(viewModel.editionText == testCase.expected)
    }

    @Test("Black Panther, with every flag false, reads as Standard")
    func explicitFalseFixtureIsStandard() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.explicitFalse))

        #expect(viewModel.editionText == "Standard")
    }

    // MARK: - Summary card chip

    @Test("An unmatched title shows Title not confirmed, never Some details missing")
    func unmatchedTitle() throws {
        let viewModel = ConfirmViewModel(edition: try edition(matched: false, hdr: nil, packaging: "{}"))

        #expect(viewModel.titleNotConfirmed)
        #expect(!viewModel.someDetailsMissing)
    }

    @Test("A matched edition with HDR and packaging known shows no chip")
    func matchedAndComplete() throws {
        let viewModel = ConfirmViewModel(edition: try Fixtures.decode(Fixtures.comboPack))

        #expect(!viewModel.titleNotConfirmed)
        #expect(!viewModel.someDetailsMissing)
    }

    @Test("A matched edition is missing details when HDR or packaging is unknown", arguments: [
        DetailsCase("HDR unknown", hdr: nil, packaging: #"{ "steelbook": true }"#, missing: true),
        DetailsCase("Packaging empty", hdr: "[]", packaging: "{}", missing: true),
        DetailsCase("Packaging absent", hdr: "[]", packaging: nil, missing: true),
        DetailsCase("SDR and an explicit false are both known", hdr: "[]", packaging: #"{ "slipcover": false }"#, missing: false),
    ])
    func someDetailsMissing(_ testCase: DetailsCase) throws {
        let viewModel = ConfirmViewModel(edition: try edition(
            matched: true,
            hdr: testCase.hdr,
            packaging: testCase.packaging
        ))

        #expect(!viewModel.titleNotConfirmed)
        #expect(viewModel.someDetailsMissing == testCase.missing)
    }

    // MARK: - Helpers

    /// A normalized edition body with only the fields these tests care about.
    /// A `nil` argument leaves that key out of the JSON, which the schema
    /// reads as unknown.
    private func edition(
        format: String? = "4K UHD",
        discs: [String]? = nil,
        matched: Bool = true,
        hdr: String? = "[]",
        packaging: String? = "{}",
        flags: String = "{}"
    ) throws -> Edition {
        var fields: [String] = [
            #""id": "0000000000000""#,
            #""barcodes": { "upc": "000000000000" }"#,
            #""upcTitle": "Test Edition""#,
            #""editionFlags": \#(flags)"#,
        ]
        if let format { fields.append(#""format": "\#(format)""#) }
        if let discs {
            let list = discs.map { #"{ "format": "\#($0)" }"# }.joined(separator: ", ")
            fields.append(#""discContents": [\#(list)]"#)
        }
        if let hdr { fields.append(#""hdr": \#(hdr)"#) }
        if let packaging { fields.append(#""packaging": \#(packaging)"#) }
        if matched {
            fields.append(#""title": { "tmdbId": "1", "kind": "movie", "name": "Test" }"#)
            fields.append(#""unmatchedTitle": false"#)
        } else {
            fields.append(#""unmatchedTitle": true"#)
        }
        return try Fixtures.decode("{ \(fields.joined(separator: ", ")) }")
    }
}

// MARK: - Parameterized cases

nonisolated struct HDRCase: Sendable, CustomTestStringConvertible {
    let json: String?
    let expected: String
    var testDescription: String { "\(json ?? "absent") → \(expected)" }
}

nonisolated struct EditionCase: Sendable, CustomTestStringConvertible {
    let name: String
    let packaging: String?
    let flags: String
    let expected: String
    var testDescription: String { name }

    init(_ name: String, packaging: String?, flags: String, expected: String) {
        self.name = name
        self.packaging = packaging
        self.flags = flags
        self.expected = expected
    }
}

nonisolated struct DetailsCase: Sendable, CustomTestStringConvertible {
    let name: String
    let hdr: String?
    let packaging: String?
    let missing: Bool
    var testDescription: String { name }

    init(_ name: String, hdr: String?, packaging: String?, missing: Bool) {
        self.name = name
        self.hdr = hdr
        self.packaging = packaging
        self.missing = missing
    }
}
