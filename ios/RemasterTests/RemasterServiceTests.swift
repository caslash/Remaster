//
//  RemasterServiceTests.swift
//  RemasterTests
//
//  The shared backend call: the request it builds and how responses become
//  BackendError (backend/docs/search-endpoint.md; RMSTR-16 and privacy).
//
//  RemasterService uses URLSession.shared, so requests are intercepted with
//  SearchStubURLProtocol, which only answers GET /search so it can't collide
//  with the UPC and poster stubs other suites register in parallel. The suite
//  is serialized because the stub's state is global.
//

import Foundation
import Synchronization
import Testing
@testable import Remaster

@Suite("RemasterService", .serialized)
final class RemasterServiceTests {
    private let service = RemasterService()
    private let configuredHost = Bundle.main.object(forInfoDictionaryKey: "RemasterBaseUrl") as? String

    init() {
        SearchStubURLProtocol.reset()
        URLProtocol.registerClass(SearchStubURLProtocol.self)
    }

    deinit {
        URLProtocol.unregisterClass(SearchStubURLProtocol.self)
        SearchStubURLProtocol.reset()
    }

    private func search(_ text: String) async throws(BackendError) -> Data {
        try await service.fetchRemaster("/search", httpMethod: "GET", queryItems: [URLQueryItem(name: "q", value: text)])
    }

    // MARK: Where the request goes

    @Test("Searches go to the Remaster backend over HTTPS, never TMDB")
    func requestGoesToBackend() async throws {
        SearchStubURLProtocol.respond(status: 200, body: "[]")

        _ = try await search("Dune")

        let url = try #require(SearchStubURLProtocol.requests.first?.url)
        #expect(url.scheme == "https")
        #expect(url.host() == configuredHost)
        #expect(url.host()?.localizedCaseInsensitiveContains("themoviedb") == false)
        #expect(url.path() == "/search")
    }

    @Test("Punctuation and non-ASCII text reach the server unchanged", arguments: [
        "AC/DC", "Fast & Furious", "Amélie", "What's Up, Doc?", "100% Wolf", "a=b",
    ])
    func textRoundTrips(_ text: String) async throws {
        SearchStubURLProtocol.respond(status: 200, body: "[]")

        _ = try await search(text)

        let url = try #require(SearchStubURLProtocol.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items == [URLQueryItem(name: "q", value: text)])
    }

    @Test("A plus sign is percent-encoded, so the server doesn't read it as a space")
    func plusIsEncoded() async throws {
        // Nest's query parser decodes a raw "+" as a space, so "Romeo + Juliet"
        // must be sent as %2B or the server searches for "Romeo   Juliet".
        SearchStubURLProtocol.respond(status: 200, body: "[]")

        _ = try await search("Romeo + Juliet")

        let url = try #require(SearchStubURLProtocol.requests.first?.url)
        let query = try #require(url.query(percentEncoded: true))
        #expect(!query.contains("+"), "Sent query was \(query)")
        #expect(query.contains("%2B"), "Sent query was \(query)")
    }

    // MARK: What the request contains (privacy)

    @Test("The request carries the search text only: a GET with no body, cookies or identifying headers")
    func requestCarriesNoIdentifiers() async throws {
        SearchStubURLProtocol.respond(status: 200, body: "[]")

        _ = try await search("Dune")

        let request = try #require(SearchStubURLProtocol.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.httpBodyStream == nil)

        let allowed: Set<String> = ["accept", "accept-encoding", "accept-language", "user-agent", "host", "connection"]
        let sent = Set((request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() })
        #expect(sent.subtracting(allowed).isEmpty, "Unexpected headers: \(sent.subtracting(allowed).sorted())")

        let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems
        #expect(items?.map(\.name) == ["q"])
    }

    // MARK: Responses

    @Test("A 2xx returns the body as sent")
    func successReturnsBody() async throws {
        let body = #"[{"tmdbId":"771","kind":"movie","name":"Home Alone","year":1990}]"#
        SearchStubURLProtocol.respond(status: 200, body: body)

        let data = try await search("Home Alone")

        #expect(String(decoding: data, as: UTF8.self) == body)
    }

    @Test("A non-2xx status is a server error with that status", arguments: [400, 404, 500, 502, 503, 504])
    func statusIsReported(_ status: Int) async throws {
        SearchStubURLProtocol.respond(status: status, body: Self.nestError(status: status))

        let error = try #require(await #expect(throws: BackendError.self) {
            try await self.search("Dune")
        })

        guard case .serverError(let statusCode, _) = error else {
            Issue.record("Expected serverError, got \(error)")
            return
        }
        #expect(statusCode == status)
    }

    @Test("Retry-After in whole seconds is passed on", arguments: ["1", "7", "30"])
    func retryAfterSeconds(_ header: String) async throws {
        SearchStubURLProtocol.respond(status: 503, body: Self.nestError(status: 503), headers: ["Retry-After": header])

        let error = try #require(await #expect(throws: BackendError.self) {
            try await self.search("Dune")
        })

        guard case .serverError(_, let retryAfter) = error else {
            Issue.record("Expected serverError, got \(error)")
            return
        }
        #expect(retryAfter == Int(header))
    }

    @Test("A missing or non-numeric Retry-After is left out", arguments: [
        nil, "", "Wed, 21 Oct 2026 07:28:00 GMT", "5.5",
    ] as [String?])
    func retryAfterMissing(_ header: String?) async throws {
        let headers = header.map { ["Retry-After": $0] } ?? [:]
        SearchStubURLProtocol.respond(status: 503, body: Self.nestError(status: 503), headers: headers)

        let error = try #require(await #expect(throws: BackendError.self) {
            try await self.search("Dune")
        })

        guard case .serverError(_, let retryAfter) = error else {
            Issue.record("Expected serverError, got \(error)")
            return
        }
        #expect(retryAfter == nil)
    }

    @Test("A connection failure is a transport error carrying the URLError", arguments: [
        URLError.Code.notConnectedToInternet, .timedOut, .cannotFindHost,
    ])
    func transportFailure(_ code: URLError.Code) async throws {
        SearchStubURLProtocol.fail(with: URLError(code))

        let error = try #require(await #expect(throws: BackendError.self) {
            try await self.search("Dune")
        })

        guard case .transportError(let urlError) = error else {
            Issue.record("Expected transportError, got \(error)")
            return
        }
        #expect(urlError.code == code)
    }

    private static func nestError(status: Int) -> String {
        let name = HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        return #"{"statusCode":\#(status),"message":"Anything","error":"\#(name)"}"#
    }
}

/// Answers GET /search with a canned response and records what was asked.
nonisolated final class SearchStubURLProtocol: URLProtocol {
    static let path = "/search"

    private enum Reply {
        case response(status: Int, body: Data, headers: [String: String])
        case failure(URLError)
    }

    private static let state = Mutex<(reply: Reply, requests: [URLRequest])>((.failure(URLError(.unknown)), []))

    static var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    static func respond(status: Int, body: String, headers: [String: String] = [:]) {
        state.withLock { $0.reply = .response(status: status, body: Data(body.utf8), headers: headers) }
    }

    static func fail(with error: URLError) {
        state.withLock { $0.reply = .failure(error) }
    }

    static func reset() {
        state.withLock { $0 = (.failure(URLError(.unknown)), []) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.path() == path
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let reply = Self.state.withLock { state in
            state.requests.append(request)
            return state.reply
        }

        switch reply {
        case .response(let status, let body, let headers):
            let fields = headers.merging(["Content-Type": "application/json"]) { mine, _ in mine }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
