//
//  TitleServiceTests.swift
//  RemasterTests
//
//  The title search call and how backend failures map to TitleSearchError
//  (backend/docs/search-endpoint.md; RMSTR-16).
//
//  TitleService takes its RemasterServicing in its initializer, so each test
//  hands it a FakeRemasterService and nothing touches the network.
//

import Foundation
import Testing
@testable import Remaster

@Suite("TitleService")
struct TitleServiceTests {
    private let backend = FakeRemasterService()
    private var service: TitleService { TitleService(remasterService: backend) }

    // MARK: The request

    @Test("Searches GET /search with the text as the only query item")
    func request() async throws {
        backend.result = .success(Data("[]".utf8))

        _ = try await service.searchTitle("Home Alone")

        let call = try #require(backend.calls.first)
        #expect(backend.calls.count == 1)
        #expect(call.path == "/search")
        #expect(call.httpMethod == "GET")
        #expect(call.queryItems == [URLQueryItem(name: "q", value: "Home Alone")])
    }

    // MARK: Decoding

    @Test("A 200 decodes every result in order, with year and poster optional")
    func decodesResults() async throws {
        // The contract's example response (search-endpoint.md, 200 OK).
        backend.result = .success(Data("""
        [
          { "tmdbId": "65282", "kind": "tv", "name": "Home Alone", "year": 2013,
            "posterURL": "https://image.tmdb.org/t/p/w500/1hqGagr94soBq70Lq7tPHvNmmxy.jpg" },
          { "tmdbId": "771", "kind": "movie", "name": "Home Alone", "year": 1990,
            "posterURL": "https://image.tmdb.org/t/p/w500/onTSipZ8R3bliBdKfPtsDuHTdlL.jpg" },
          { "tmdbId": "1832995", "kind": "movie", "name": "Untitled Home Alone Film" }
        ]
        """.utf8))

        let titles = try await service.searchTitle("Home Alone")

        #expect(titles.map(\.tmdbId) == ["65282", "771", "1832995"])
        #expect(titles.map(\.kind) == [.tv, .movie, .movie])
        #expect(titles.map(\.year) == [2013, 1990, nil])
        #expect(titles[1].posterURL == URL(string: "https://image.tmdb.org/t/p/w500/onTSipZ8R3bliBdKfPtsDuHTdlL.jpg"))
        #expect(titles[2].posterURL == nil)
        #expect(titles.allSatisfy { $0.imdbId == nil })
    }

    @Test("An empty array is no results, not an error")
    func emptyArray() async throws {
        backend.result = .success(Data("[]".utf8))

        let titles = try await service.searchTitle("zzzz")

        #expect(titles.isEmpty)
    }

    @Test("A body that isn't an array of titles is unexpected", arguments: [
        #"{"statusCode":200}"#,
        #"[{"tmdbId":"1","kind":"person","name":"Someone"}]"#,
        "not json",
    ])
    func undecodableBody(_ body: String) async throws {
        backend.result = .success(Data(body.utf8))

        let error = try #require(await #expect(throws: TitleSearchError.self) {
            try await self.service.searchTitle("Dune")
        })

        #expect(error.caseName == "unexpected")
    }

    // MARK: Failures

    @Test("No connection on the device is offline", arguments: [
        URLError.Code.notConnectedToInternet,
        .dataNotAllowed,
        .internationalRoamingOff,
        .networkConnectionLost,
    ])
    func offline(_ code: URLError.Code) async throws {
        try await expect(.transportError(urlError: URLError(code)), mapsTo: "offline")
    }

    @Test("Other transport failures are temporarily unavailable", arguments: [
        URLError.Code.timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .secureConnectionFailed,
    ])
    func transportUnavailable(_ code: URLError.Code) async throws {
        try await expect(.transportError(urlError: URLError(code)), mapsTo: "tempUnavailable")
    }

    @Test("A cancelled request is cancelled, not an error to show")
    func cancelled() async throws {
        try await expect(.transportError(urlError: URLError(.cancelled)), mapsTo: "cancelled")
    }

    @Test("A 503 is busy and carries the Retry-After seconds")
    func busyCarriesRetryAfter() async throws {
        backend.result = .failure(.serverError(statusCode: 503, retryAfter: 7))

        let error = try #require(await #expect(throws: TitleSearchError.self) {
            try await self.service.searchTitle("Dune")
        })

        guard case .serviceUnavailable(let seconds) = error else {
            Issue.record("Expected serviceUnavailable, got \(error.caseName)")
            return
        }
        #expect(seconds == 7)
    }

    @Test("A 503 without Retry-After still waits a delay inside the contract's 1–30 s range")
    func busyWithoutRetryAfter() async throws {
        backend.result = .failure(.serverError(statusCode: 503, retryAfter: nil))

        let error = try #require(await #expect(throws: TitleSearchError.self) {
            try await self.service.searchTitle("Dune")
        })

        guard case .serviceUnavailable(let seconds) = error else {
            Issue.record("Expected serviceUnavailable, got \(error.caseName)")
            return
        }
        #expect((1...30).contains(seconds))
    }

    @Test("502 and 504 are temporarily unavailable", arguments: [502, 504])
    func gatewayErrors(_ status: Int) async throws {
        try await expect(.serverError(statusCode: status, retryAfter: nil), mapsTo: "tempUnavailable")
    }

    @Test("Any other status is unexpected", arguments: [400, 404, 429, 500])
    func otherStatuses(_ status: Int) async throws {
        try await expect(.serverError(statusCode: status, retryAfter: nil), mapsTo: "unexpected")
    }

    @Test("A request that couldn't be built or answered is unexpected", arguments: [
        BackendError.invalidURL,
        .invalidResponse,
        .generic(CocoaError(.fileReadUnknown)),
    ])
    func otherBackendErrors(_ backendError: BackendError) async throws {
        try await expect(backendError, mapsTo: "unexpected")
    }

    private func expect(
        _ backendError: BackendError,
        mapsTo expected: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        backend.result = .failure(backendError)

        let error = try #require(await #expect(throws: TitleSearchError.self, sourceLocation: sourceLocation) {
            try await self.service.searchTitle("Dune")
        }, sourceLocation: sourceLocation)

        #expect(error.caseName == expected, sourceLocation: sourceLocation)
    }
}

@Suite("TitleSearchError")
struct TitleSearchErrorTests {
    private nonisolated static let shown: [TitleSearchError] = [
        .serviceUnavailable(retryAfterSeconds: 5), .offline, .tempUnavailable, .unexpected,
    ]

    @Test("Every error the screen shows has a headline and a recovery line", arguments: shown)
    func shownErrorsHaveWording(_ error: TitleSearchError) {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }

    @Test("Cancelled has no wording, because it's never shown")
    func cancelledHasNoWording() {
        #expect(TitleSearchError.cancelled.errorDescription == nil)
        #expect(TitleSearchError.cancelled.recoverySuggestion == nil)
    }

    @Test("Try again is offered only when retrying can help", arguments: [
        (TitleSearchError.serviceUnavailable(retryAfterSeconds: 5), true),
        (.offline, true),
        (.tempUnavailable, true),
        (.unexpected, false),
        (.cancelled, false),
    ])
    func retryable(_ error: TitleSearchError, _ expected: Bool) {
        #expect(error.isRetryable == expected)
    }

    @Test("Offline says so, as the acceptance criteria ask")
    func offlineWording() {
        #expect(TitleSearchError.offline.errorDescription == "You're offline")
    }
}

@Suite("Title identity")
struct TitleIdentityTests {
    @Test("A movie and a TV show with the same TMDB ID are different titles")
    func kindIsPartOfIdentity() {
        // TMDB IDs are only unique per kind; these two share an ID on purpose.
        #expect(SampleTitles.dune.tmdbId == SampleTitles.duneMiniseries.tmdbId)
        #expect(SampleTitles.dune.id != SampleTitles.duneMiniseries.id)
    }

    @Test("The same kind and TMDB ID is the same title")
    func sameKindAndID() {
        let again = Title(tmdbId: "438631", kind: .movie, name: "Dune (re-release)")
        #expect(again.id == SampleTitles.dune.id)
    }
}
