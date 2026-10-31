//
//  NetworkErrorTests.swift
//  RemasterTests
//
//  What the user is told for each failure (backend/docs/upc-endpoint.md,
//  "What the client should do"; RMSTR-11 AC 4 and 5).
//

import Foundation
import Testing
@testable import Remaster

@Suite("NetworkError")
struct NetworkErrorTests {

    @Test("A bad scan (400) isn't retried: retrying the same code can't succeed")
    func badRequestNotRetryable() {
        #expect(NetworkError.badRequest.isRetryable == false)
    }

    @Test("An unknown disc (404) isn't retried: the user falls back to manual entry")
    func notFoundNotRetryable() {
        #expect(NetworkError.notFound.isRetryable == false)
    }

    @Test("Temporary backend failures offer a retry", arguments: [500, 502, 504])
    func serverErrorsRetryable(_ status: Int) {
        #expect(NetworkError.serverError(statusCode: status).isRetryable)
    }

    @Test("Network failures offer a retry", arguments: [
        URLError.Code.notConnectedToInternet,
        .timedOut,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .dataNotAllowed,
        .internationalRoamingOff,
    ])
    func transportErrorsRetryable(_ code: URLError.Code) {
        #expect(NetworkError.transportError(URLError(code)).isRetryable)
    }

    @Test("Every failure has a readable message and suggestion, never raw JSON", arguments: [
        NetworkError.invalidURL,
        .invalidResponse,
        .transportError(URLError(.notConnectedToInternet)),
        .transportError(URLError(.timedOut)),
        .transportError(URLError(.badServerResponse)),
        .serverError(statusCode: 500),
        .serverError(statusCode: 502),
        .serverError(statusCode: 504),
        .decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test"))),
        .badRequest,
        .notFound,
    ])
    func readableMessages(_ error: NetworkError) throws {
        let description = try #require(error.errorDescription)
        let suggestion = try #require(error.recoverySuggestion)

        for text in [description, suggestion] {
            #expect(!text.trimmingCharacters(in: .whitespaces).isEmpty)
            #expect(!text.contains("{"))
            #expect(!text.contains("statusCode"))
        }
    }

    @Test("Not-found and bad-scan messages differ, so the user can tell them apart")
    func notFoundDistinctFromBadRequest() {
        #expect(NetworkError.notFound.errorDescription != NetworkError.badRequest.errorDescription)
        #expect(NetworkError.notFound.recoverySuggestion != NetworkError.badRequest.recoverySuggestion)
    }
}
