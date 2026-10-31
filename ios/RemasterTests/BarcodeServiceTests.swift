//
//  BarcodeServiceTests.swift
//  RemasterTests
//
//  The UPC lookup request and how responses map to errors
//  (backend/docs/upc-endpoint.md; RMSTR-11 AC 1, 4, 5 and privacy).
//
//  BarcodeService uses URLSession.shared, so requests are intercepted with a
//  URLProtocol registered globally. The suite is serialized because of that.
//

import Foundation
import Testing
import Vision
@testable import Remaster

@Suite("BarcodeService", .serialized)
final class BarcodeServiceTests {
    private let service = BarcodeService()
    private let configuredHost = Bundle.main.object(forInfoDictionaryKey: "RemasterBaseUrl") as? String

    init() {
        StubURLProtocol.reset()
        URLProtocol.registerClass(StubURLProtocol.self)
    }

    deinit {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.reset()
    }

    // MARK: Where the request goes (AC 1)

    @Test("Lookups go to the Remaster backend over HTTPS, never upcmdb.com")
    func requestGoesToBackend() async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.minimal)

        _ = try await service.fetchBarcode("0786936900378", shape: .ean13)

        let request = try #require(StubURLProtocol.requests.first)
        let url = try #require(request.url)
        #expect(url.scheme == "https")
        #expect(url.host() == configuredHost)
        #expect(url.host()?.localizedCaseInsensitiveContains("upcmdb") == false)
        #expect(url.path() == "/upc/0786936900378")
    }

    @Test("The barcode is sent without surrounding whitespace")
    func barcodeIsTrimmed() async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.minimal)

        _ = try await service.fetchBarcode(" 0786936900378\n", shape: nil)

        let url = try #require(StubURLProtocol.requests.first?.url)
        #expect(url.path() == "/upc/0786936900378")
    }

    @Test("The scanned shape is sent as the only query item", arguments: [
        (VNBarcodeSymbology.ean13, "EAN-13"),
        (VNBarcodeSymbology.upce, "UPC-E"),
        (VNBarcodeSymbology.ean8, "EAN-8"),
    ])
    func shapeQueryItem(_ symbology: VNBarcodeSymbology, _ expected: String) async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.minimal)

        _ = try await service.fetchBarcode("0786936900378", shape: symbology)

        let url = try #require(StubURLProtocol.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items == [URLQueryItem(name: "shape", value: expected)])
    }

    @Test("No query is sent when the shape is unknown or not a retail type", arguments: [
        nil, VNBarcodeSymbology.qr, VNBarcodeSymbology.code128,
    ] as [VNBarcodeSymbology?])
    func noShapeQuery(_ symbology: VNBarcodeSymbology?) async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.minimal)

        _ = try await service.fetchBarcode("0786936900378", shape: symbology)

        let url = try #require(StubURLProtocol.requests.first?.url)
        #expect(url.query() == nil)
    }

    // MARK: What the request contains (privacy)

    @Test("The request carries the UPC only: a GET with no body, cookies or identifying headers")
    func requestCarriesNoIdentifiers() async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.minimal)

        _ = try await service.fetchBarcode("0786936900378", shape: .ean13)

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.httpBodyStream == nil)

        let allowed: Set<String> = ["accept", "accept-encoding", "accept-language", "user-agent", "host", "connection"]
        let sent = Set((request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() })
        #expect(sent.subtracting(allowed).isEmpty, "Unexpected headers: \(sent.subtracting(allowed).sorted())")
    }

    // MARK: Responses

    @Test("A 200 decodes into the edition")
    func successDecodes() async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.comboPack)

        let edition = try await service.fetchBarcode("0786936900001", shape: .ean13)

        #expect(edition.title == "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook")
        #expect(edition.format == .uhd)
    }

    @Test("Error statuses map to the documented outcome", arguments: [
        (400, "badRequest", false),
        (404, "notFound", false),
        (500, "serverError", true),
        (502, "serverError", true),
        (504, "serverError", true),
    ])
    func errorStatuses(_ status: Int, _ expectedCase: String, _ retryable: Bool) async throws {
        StubURLProtocol.respond(status: status, body: Self.nestError(status: status, message: "Anything"))

        let error = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("0786936900378", shape: .ean13)
        })

        #expect(error.caseName == expectedCase)
        #expect(error.isRetryable == retryable)
    }

    @Test("The client branches on the status code, not the message text", arguments: [400, 404, 502])
    func statusNotMessage(_ status: Int) async throws {
        StubURLProtocol.respond(status: status, body: Self.nestError(status: status, message: "Invalid scanned barcode - Coupon"))
        let first = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("0786936900378", shape: .ean13)
        })

        StubURLProtocol.respond(status: status, body: Self.nestError(status: status, message: "Some new wording"))
        let second = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("0786936900378", shape: .ean13)
        })

        #expect(first.caseName == second.caseName)
        #expect(first.isRetryable == second.isRetryable)
    }

    @Test("A 200 whose body isn't an edition is a decoding error, not raw JSON")
    func undecodableBody() async throws {
        StubURLProtocol.respond(status: 200, body: #"{"statusCode":200,"unexpected":true}"#)

        let error = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("0786936900378", shape: .ean13)
        })

        #expect(error.caseName == "decodingError")
    }

    @Test("A connection failure is a retryable transport error")
    func offline() async throws {
        StubURLProtocol.fail(with: URLError(.notConnectedToInternet))

        let error = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("0786936900378", shape: .ean13)
        })

        #expect(error.caseName == "transportError")
        #expect(error.isRetryable)
    }

    // MARK: Bad input

    @Test("An empty code is a bad request and isn't sent")
    func emptyCode() async throws {
        StubURLProtocol.respond(status: 200, body: Fixtures.minimal)

        let error = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("", shape: nil)
        })

        #expect(error.caseName == "badRequest")
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test("A whitespace-only code is a bad request, the same as an empty one")
    func whitespaceOnlyCode() async throws {
        // What Nest answers for GET /upc/ (no route matches).
        StubURLProtocol.respond(status: 404, body: #"{"statusCode":404,"message":"Cannot GET /upc/","error":"Not Found"}"#)

        let error = try #require(await #expect(throws: NetworkError.self) {
            try await self.service.fetchBarcode("   ", shape: nil)
        })

        #expect(error.caseName == "badRequest")
    }

    private static func nestError(status: Int, message: String) -> String {
        let name = HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        return #"{"statusCode":\#(status),"message":"\#(message)","error":"\#(name)"}"#
    }
}

/// Answers every request with a canned response and records what was asked.
nonisolated final class StubURLProtocol: URLProtocol {
    private enum Reply {
        case response(status: Int, body: Data)
        case failure(URLError)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var reply: Reply = .failure(URLError(.unknown))
    nonisolated(unsafe) private static var recorded: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    static func respond(status: Int, body: String) {
        lock.withLock { reply = .response(status: status, body: Data(body.utf8)) }
    }

    static func fail(with error: URLError) {
        lock.withLock { reply = .failure(error) }
    }

    static func reset() {
        lock.withLock {
            reply = .failure(URLError(.unknown))
            recorded = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let reply = Self.lock.withLock {
            Self.recorded.append(request)
            return Self.reply
        }

        switch reply {
        case .response(let status, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
