//
//  SimulatedTitleServiceTests.swift
//  RemasterTests
//
//  The canned searches the Remaster_Sim scheme and the UI tests rely on
//  (RMSTR-16). The results come from ios/Mocks/Titles.bundle, which is in
//  Debug builds for the Simulator.
//

import Foundation
import Testing
@testable import Remaster

#if DEBUG
@Suite("SimulatedTitleService")
struct SimulatedTitleServiceTests {
    private let service = SimulatedTitleService()

    @Test("A sample query returns its results", arguments: ["grinch", "hoppers", "wandavision"])
    func sampleQueries(_ query: String) async throws {
        let titles = try await service.searchTitle(query)

        #expect(!titles.isEmpty)
    }

    @Test("Sample queries match regardless of case and surrounding whitespace")
    func caseAndWhitespace() async throws {
        let plain = try await service.searchTitle("grinch")
        let messy = try await service.searchTitle("  Grinch \n")

        #expect(messy.map(\.id) == plain.map(\.id))
    }

    @Test("An unknown query has no matches, not an error")
    func unknownQuery() async throws {
        let titles = try await service.searchTitle("no such title")

        #expect(titles.isEmpty)
    }

    @Test("Special queries fake each failure the screen shows", arguments: [
        ("000", "offline"),
        ("503", "serviceUnavailable"),
        ("504", "tempUnavailable"),
        ("unexpected", "unexpected"),
        (" 000 ", "offline"),
    ])
    func failures(_ query: String, _ expected: String) async throws {
        let error = try #require(await #expect(throws: TitleSearchError.self) {
            try await self.service.searchTitle(query)
        })

        #expect(error.caseName == expected)
    }
}
#endif
