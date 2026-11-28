//
//  TitleSearchViewModelTests.swift
//  RemasterTests
//
//  Search as you type on the title search screen (RMSTR-16 AC 1, 3, 4 and
//  the search endpoint's client rules in backend/docs/search-endpoint.md).
//
//  TitleSearchViewModel resolves its TitleServicing from Container.shared, so
//  each test registers a StubTitleService first; FactoryTesting's .container
//  trait gives each test its own Container.shared. The view model takes its
//  clock in its initializer, so a ManualClock runs the 300 ms debounce and the
//  Retry-After wait instantly, and only when a test advances it.
//

import FactoryKit
import FactoryTesting
import Foundation
import Testing
@testable import Remaster

@MainActor
@Suite("TitleSearchViewModel", .container)
final class TitleSearchViewModelTests {
    private let stub = StubTitleService()
    private let clock = ManualClock()

    init() {
        Container.shared.titleService.register { [stub] in stub }
    }

    private func makeViewModel(_ searchType: TitleSearchType = .addTitle(upc: nil)) -> TitleSearchViewModel {
        TitleSearchViewModel(searchType: searchType, clock: clock)
    }

    /// Types `query`, then lets the debounce run out.
    private func type(_ query: String, into viewModel: TitleSearchViewModel) async {
        let sleepsBefore = clock.sleepCount
        viewModel.query = query
        await waitUntil("the debounce to start") { clock.sleepCount > sleepsBefore }
        clock.advance(by: .milliseconds(300))
    }

    // MARK: Starting out

    @Test("Starts idle with nothing typed, and doesn't search")
    func startsIdle() async {
        let viewModel = makeViewModel()

        #expect(viewModel.state.caseName == "idle")
        #expect(viewModel.query.isEmpty)

        clock.advance(by: .seconds(1))
        await settle()
        #expect(stub.queries.isEmpty)
    }

    @Test("A pre-filled title is searched without typing")
    func prefillSearches() async {
        stub.respond(to: "WandaVision", with: .success([SampleTitles.dune]))
        let viewModel = makeViewModel(.titleNotConfirmed(upc: "8717418608644", prefillQuery: "WandaVision"))

        #expect(viewModel.query == "WandaVision")
        await waitUntil("the debounce to start") { clock.pendingSleeps == 1 }
        clock.advance(by: .milliseconds(300))
        await waitUntil("results") { viewModel.state.caseName == "results" }

        #expect(stub.queries == ["WandaVision"])
    }

    // MARK: When a search is sent (AC 1)

    @Test("Searches only after a 300 ms pause in typing")
    func debounce() async {
        let viewModel = makeViewModel()

        viewModel.query = "dune"
        await waitUntil("the debounce to start") { clock.pendingSleeps == 1 }

        clock.advance(by: .milliseconds(299))
        await settle()
        #expect(stub.queries.isEmpty)

        clock.advance(by: .milliseconds(1))
        await waitUntil("the search") { stub.queries.count == 1 }
        #expect(stub.queries == ["dune"])
    }

    @Test("Each keystroke restarts the pause, so only the last text is searched")
    func typingRestartsDebounce() async {
        let viewModel = makeViewModel()

        viewModel.query = "du"
        await waitUntil("the first debounce") { clock.sleepCount == 1 }
        clock.advance(by: .milliseconds(200))

        viewModel.query = "dun"
        await waitUntil("the second debounce") { clock.sleepCount == 2 && clock.pendingSleeps == 1 }
        clock.advance(by: .milliseconds(200))
        await settle()
        #expect(stub.queries.isEmpty)

        clock.advance(by: .milliseconds(100))
        await waitUntil("the search") { stub.queries.count == 1 }
        #expect(stub.queries == ["dun"])
    }

    @Test("Text under 2 characters after trimming isn't sent", arguments: ["", "a", " a ", "   ", "\n"])
    func tooShortIsNotSent(_ query: String) async {
        let viewModel = makeViewModel()

        viewModel.query = query
        clock.advance(by: .seconds(1))
        await settle()

        #expect(stub.queries.isEmpty)
        #expect(viewModel.state.caseName == "idle")
    }

    @Test("Two characters is enough, as the contract allows")
    func twoCharactersIsSent() async {
        let viewModel = makeViewModel()

        await type("It", into: viewModel)
        await waitUntil("the search") { stub.queries.count == 1 }

        #expect(stub.queries == ["It"])
    }

    @Test("Surrounding whitespace is trimmed before sending")
    func trimsBeforeSending() async {
        let viewModel = makeViewModel()

        await type("  Blade Runner \n", into: viewModel)
        await waitUntil("the search") { stub.queries.count == 1 }

        #expect(stub.queries == ["Blade Runner"])
    }

    @Test("Setting the same text again doesn't search again")
    func sameTextDoesNotResearch() async {
        stub.respond(to: "dune", with: .success([SampleTitles.dune]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("results") { viewModel.state.caseName == "results" }

        viewModel.query = "dune"
        clock.advance(by: .seconds(1))
        await settle()

        #expect(stub.queries == ["dune"])
    }

    // MARK: What's shown (AC 1, 3)

    @Test("Shows loading while the search is in flight")
    func loadingWhileInFlight() async {
        stub.hold()
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the search") { stub.queries.count == 1 }

        #expect(viewModel.state.caseName == "loading")
        stub.release()
    }

    @Test("Matches are shown in the order the server sent them")
    func showsResults() async throws {
        stub.respond(to: "dune", with: .success([SampleTitles.dune, SampleTitles.duneMiniseries, SampleTitles.dunePartTwo]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("results") { viewModel.state.caseName == "results" }

        let titles = try #require(viewModel.state.titles)
        #expect(titles.map(\.id) == [SampleTitles.dune.id, SampleTitles.duneMiniseries.id, SampleTitles.dunePartTwo.id])
    }

    @Test("No results shows no matches")
    func noMatches() async {
        let viewModel = makeViewModel()

        await type(" zzzz ", into: viewModel)
        await waitUntil("no matches") { viewModel.state.caseName == "noMatches" }

        #expect(viewModel.state.titles == nil)
    }

    @Test("Clearing the field goes back to idle")
    func clearingReturnsToIdle() async {
        stub.respond(to: "dune", with: .success([SampleTitles.dune]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("results") { viewModel.state.caseName == "results" }

        viewModel.query = ""

        #expect(viewModel.state.caseName == "idle")
    }

    // MARK: Failures (AC 4)

    @Test("A failed search shows the error instead of loading forever", arguments: [
        TitleSearchError.offline, .tempUnavailable, .unexpected,
    ])
    func failureIsShown(_ failure: TitleSearchError) async throws {
        stub.respond(to: "dune", with: .failure(failure))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the failure") { viewModel.state.caseName == "failed" }

        let error = try #require(viewModel.state.error)
        #expect(error.caseName == failure.caseName)
        #expect(stub.queries.count == 1)
    }

    @Test("Try again searches straight away, without the typing pause")
    func retryAfterFailure() async {
        stub.respond(to: "dune", with: .failure(.offline), .success([SampleTitles.dune]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the failure") { viewModel.state.caseName == "failed" }

        let sleepsBefore = clock.sleepCount
        viewModel.retry()
        await waitUntil("results") { viewModel.state.caseName == "results" }

        #expect(stub.queries == ["dune", "dune"])
        #expect(clock.sleepCount == sleepsBefore)
    }

    @Test("A cancelled search leaves no error behind")
    func cancelledIsNotShown() async {
        stub.respond(to: "dune", with: .failure(.cancelled))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the search") { stub.queries.count == 1 }
        await settle()

        #expect(viewModel.state.caseName != "failed")
    }

    // MARK: A busy server (503 with Retry-After)

    @Test("A 503 waits Retry-After seconds, then retries once")
    func busyRetriesOnce() async throws {
        stub.respond(to: "dune", with: .failure(.serviceUnavailable(retryAfterSeconds: 5)), .success([SampleTitles.dune]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the retry wait") { viewModel.state.caseName == "waitingToRetry" && clock.pendingSleeps == 1 }

        guard case .waitingToRetry(_, let attempt) = viewModel.state else { return }
        #expect(attempt == 1)

        clock.advance(by: .milliseconds(4_999))
        await settle()
        #expect(stub.queries.count == 1)

        clock.advance(by: .milliseconds(1))
        await waitUntil("results") { viewModel.state.caseName == "results" }
        #expect(stub.queries == ["dune", "dune"])
    }

    @Test("A second 503 in a row is shown as busy instead of retrying again")
    func busyTwiceFails() async throws {
        let busy = TitleSearchError.serviceUnavailable(retryAfterSeconds: 2)
        stub.respond(to: "dune", with: .failure(busy), .failure(busy), .success([SampleTitles.dune]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the retry wait") { clock.pendingSleeps == 1 && viewModel.state.caseName == "waitingToRetry" }
        clock.advance(by: .seconds(2))
        await waitUntil("the failure") { viewModel.state.caseName == "failed" }

        let error = try #require(viewModel.state.error)
        #expect(error.caseName == "serviceUnavailable")

        clock.advance(by: .seconds(60))
        await settle()
        #expect(stub.queries.count == 2)
    }

    @Test("Retry now skips the rest of the wait")
    func retryNowSkipsWait() async {
        stub.respond(to: "dune", with: .failure(.serviceUnavailable(retryAfterSeconds: 30)), .success([SampleTitles.dune]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the retry wait") { clock.pendingSleeps == 1 && viewModel.state.caseName == "waitingToRetry" }

        viewModel.retry()
        await waitUntil("results") { viewModel.state.caseName == "results" }

        #expect(stub.queries == ["dune", "dune"])
        #expect(clock.pendingSleeps == 0)
    }

    @Test("Typing during the wait searches the new text instead")
    func typingDuringWaitReplacesRetry() async {
        stub.respond(to: "dune", with: .failure(.serviceUnavailable(retryAfterSeconds: 10)))
        stub.respond(to: "dune part two", with: .success([SampleTitles.dunePartTwo]))
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the retry wait") { clock.pendingSleeps == 1 && viewModel.state.caseName == "waitingToRetry" }

        await type("dune part two", into: viewModel)
        await waitUntil("results") { viewModel.state.caseName == "results" }
        clock.advance(by: .seconds(10))
        await settle()

        #expect(stub.queries == ["dune", "dune part two"])
        #expect(viewModel.state.titles?.map(\.id) == [SampleTitles.dunePartTwo.id])
    }

    // MARK: Out-of-order responses

    @Test("A slow answer to older text never replaces newer results")
    func newerQueryWins() async {
        stub.respond(to: "dune", with: .success([SampleTitles.dune]))
        stub.respond(to: "dune part two", with: .success([SampleTitles.dunePartTwo]))
        stub.hold()
        let viewModel = makeViewModel()

        await type("dune", into: viewModel)
        await waitUntil("the first search") { stub.queries.count == 1 }

        await type("dune part two", into: viewModel)
        await waitUntil("the second search") { stub.queries.count == 2 }

        stub.release()
        await waitUntil("results") { viewModel.state.caseName == "results" }
        await settle()

        #expect(viewModel.state.titles?.map(\.id) == [SampleTitles.dunePartTwo.id])
    }
}

@Suite("TitleSearchType")
struct TitleSearchTypeTests {
    @Test("Searching from the confirm sheet pre-fills the detected title and keeps the UPC")
    func titleNotConfirmed() {
        let type = TitleSearchType.titleNotConfirmed(upc: "8717418608644", prefillQuery: "WandaVision")

        #expect(type.prefillQuery == "WandaVision")
        #expect(type.upc == "8717418608644")
        #expect(type.navigationTitle == "Find Title")
        #expect(type.unmatchedCardText.contains("8717418608644"))
    }

    @Test("An unknown barcode starts empty and keeps the UPC")
    func barcodeNotFound() {
        let type = TitleSearchType.addTitle(upc: "043396648654")

        #expect(type.prefillQuery.isEmpty)
        #expect(type.upc == "043396648654")
        #expect(type.navigationTitle == "Add Title")
        #expect(type.unmatchedCardText.contains("043396648654"))
    }

    @Test("A disc without a barcode has no UPC to show")
    func noBarcode() {
        let type = TitleSearchType.addTitle(upc: nil)

        #expect(type.upc == nil)
        #expect(type.prefillQuery.isEmpty)
        #expect(!type.unmatchedCardText.contains("UPC"))
    }

    @Test("No wording mentions sharing, which isn't part of this release", arguments: [
        TitleSearchType.addTitle(upc: "043396648654"),
        .addTitle(upc: nil),
        .titleNotConfirmed(upc: "8717418608644", prefillQuery: "WandaVision"),
    ])
    func noShareWording(_ type: TitleSearchType) {
        let wording = [type.footerText, type.unmatchedCardText, type.unmatchedCardTitle].joined(separator: " ")
        #expect(!wording.localizedCaseInsensitiveContains("share"))
        #expect(!wording.localizedCaseInsensitiveContains("next collector"))
    }
}
