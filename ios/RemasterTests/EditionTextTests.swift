//
//  EditionTextTests.swift
//  RemasterTests
//
//  Edition.editionText: the one wording for an edition's packaging and flags,
//  shown on the confirm sheet (RMSTR-14) and the library detail screen
//  (RMSTR-18 AC 5). Standard needs everything known and false. When nothing
//  identifies the edition, editionText is nil and the screens leave the Edition
//  row out rather than guess.
//
//  Editions are built from small JSON bodies so each case states exactly the
//  fields it depends on. Absent means unknown (backend/docs/edition-schema.md).
//

import Foundation
import Testing
@testable import Remaster

@Suite("Edition text")
struct EditionTextTests {

    @Test("The edition is named only when it's known, and left out otherwise", arguments: [
        EditionCase("Every field an explicit false is Standard",
                    packaging: #"{ "steelbook": false, "slipcover": false }"#,
                    flags: #"{ "limited": false, "collector": false, "special": false, "anniversary": false, "boxset": false }"#,
                    expected: "Standard"),
        EditionCase("Nothing known leaves the edition out, not Standard",
                    packaging: "{}", flags: "{}", expected: nil),
        EditionCase("No packaging object at all leaves the edition out",
                    packaging: nil, flags: "{}", expected: nil),
        EditionCase("Standard needs every flag known, not just some",
                    packaging: #"{ "steelbook": false }"#, flags: #"{ "limited": false }"#,
                    expected: nil),
        EditionCase("A collector's edition that isn't a steelbook is Collector's, not Standard",
                    packaging: #"{ "steelbook": false }"#,
                    flags: #"{ "limited": false, "collector": true, "special": false, "anniversary": false, "boxset": false }"#,
                    expected: "Collector's"),
        EditionCase("A steelbook",
                    packaging: #"{ "steelbook": true }"#, flags: "{}", expected: "Steelbook"),
        EditionCase("Steelbook wins over a collector's flag",
                    packaging: #"{ "steelbook": true }"#, flags: #"{ "collector": true }"#,
                    expected: "Steelbook"),
        EditionCase("A flag is shown even with no packaging object",
                    packaging: nil, flags: #"{ "collector": true }"#, expected: "Collector's"),
        EditionCase("A flag is shown when packaging is empty",
                    packaging: "{}", flags: #"{ "anniversary": true }"#, expected: "Anniversary"),
        EditionCase("Limited, even when it isn't a steelbook",
                    packaging: #"{ "steelbook": false }"#, flags: #"{ "limited": true }"#, expected: "Limited"),
        EditionCase("Box set",
                    packaging: "{}", flags: #"{ "boxset": true }"#, expected: "Boxset"),
        EditionCase("Special",
                    packaging: "{}", flags: #"{ "special": true }"#, expected: "Special"),
    ])
    func editionText(_ testCase: EditionCase) throws {
        let edition = try edition(packaging: testCase.packaging, flags: testCase.flags)

        #expect(edition.editionText == testCase.expected)
    }

    @Test("Black Panther, with every flag false, reads as Standard")
    func explicitFalseFixtureIsStandard() throws {
        #expect(try Fixtures.decode(Fixtures.explicitFalse).editionText == "Standard")
    }

    @Test("A thin record with nothing about packaging has no edition text")
    func thinRecordHasNoEditionText() throws {
        #expect(try Fixtures.decode(Fixtures.minimal).editionText == nil)
    }

    /// A normalized edition body with only packaging and flags set. A `nil`
    /// packaging leaves the key out, which the schema reads as unknown.
    private func edition(packaging: String?, flags: String) throws -> Edition {
        var fields: [String] = [
            #""id": "0000000000000""#,
            #""barcodes": { "upc": "000000000000" }"#,
            #""upcTitle": "Test Edition""#,
            #""editionFlags": \#(flags)"#,
            #""unmatchedTitle": true"#,
        ]
        if let packaging { fields.append(#""packaging": \#(packaging)"#) }
        return try Fixtures.decode("{ \(fields.joined(separator: ", ")) }")
    }
}

nonisolated struct EditionCase: Sendable, CustomTestStringConvertible {
    let name: String
    let packaging: String?
    let flags: String
    let expected: String?
    var testDescription: String { name }

    init(_ name: String, packaging: String?, flags: String, expected: String?) {
        self.name = name
        self.packaging = packaging
        self.flags = flags
        self.expected = expected
    }
}
