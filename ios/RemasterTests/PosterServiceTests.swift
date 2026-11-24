//
//  PosterServiceTests.swift
//  RemasterTests
//
//  Posters stored on the device so the library grid works offline (RMSTR-18
//  AC 3): savePoster downloads, downsamples and writes a poster to its library
//  item; backfillPosters finds the items still missing one.
//
//  PosterService uses URLSession.shared, so downloads are intercepted with
//  PosterStubURLProtocol, which only answers requests to its own host and
//  replies per URL. It resolves its ModelContainer from Container.shared when
//  it's created, so each test registers a fresh container first.
//
//  The container is on disk in a temporary folder, not in memory, because
//  imageData is an .externalStorage attribute and the backfill's
//  `imageData == nil` predicate should be checked against real external
//  storage.
//

import FactoryKit
import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import Remaster

@MainActor
@Suite("PosterService", .serialized)
final class PosterServiceTests {
    private let folder: URL
    private let container: ModelContainer
    private let service: PosterService

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "PosterServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(url: folder.appending(path: "Library.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: LibraryItem.self, configurations: configuration)
        self.container = container

        Container.shared.reset()
        Container.shared.modelContainer.register { container }
        service = PosterService()

        PosterStubURLProtocol.reset()
        URLProtocol.registerClass(PosterStubURLProtocol.self)
    }

    deinit {
        URLProtocol.unregisterClass(PosterStubURLProtocol.self)
        PosterStubURLProtocol.reset()
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Saving one poster

    @Test("A downloaded poster is stored on its item, downsampled to at most 500 px")
    func savesDownsampledPoster() async throws {
        let url = PosterStubURLProtocol.url("zootopia.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 1000, height: 1500))
        let id = try seed(posterURL: url)

        try await service.savePoster(persistentModelID: id, posterURL: url)

        let data = try #require(try stored(id).imageData, "No poster was stored")
        let size = try #require(Self.pixelSize(of: data), "The stored poster isn't a readable image")
        let width = Double(size.width)
        let height = Double(size.height)
        let ratio = width / height
        #expect(max(width, height) <= 500, "Stored poster is \(width) × \(height)")
        #expect(abs(ratio - 2.0 / 3.0) < 0.01, "The poster's 2:3 shape wasn't kept: \(width) × \(height)")
    }

    @Test("Only the item asked for gets the poster")
    func savesOnlyTheTargetItem() async throws {
        let url = PosterStubURLProtocol.url("hoppers.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        let target = try seed(posterURL: url)
        let other = try seed(posterURL: url)

        try await service.savePoster(persistentModelID: target, posterURL: url)

        #expect(try stored(target).imageData != nil)
        #expect(try stored(other).imageData == nil, "A poster was written to an item that wasn't asked for")
    }

    @Test("A poster the server doesn't have throws and stores nothing", arguments: [404, 500])
    func errorStatusStoresNothing(_ status: Int) async throws {
        let url = PosterStubURLProtocol.url("missing.jpg")
        PosterStubURLProtocol.respond(to: url, status: status, with: Data("Not Found".utf8))
        let id = try seed(posterURL: url)

        await #expect(throws: (any Error).self) {
            try await self.service.savePoster(persistentModelID: id, posterURL: url)
        }
        #expect(try stored(id).imageData == nil)
    }

    @Test("A 200 that isn't an image stores nothing")
    func nonImageStoresNothing() async throws {
        let url = PosterStubURLProtocol.url("error-page.jpg")
        PosterStubURLProtocol.respond(to: url, with: Data("<html><body>Service unavailable</body></html>".utf8))
        let id = try seed(posterURL: url)

        try? await service.savePoster(persistentModelID: id, posterURL: url)

        #expect(try stored(id).imageData == nil, "Something that isn't an image was stored as the poster")
    }

    @Test("An item deleted while its poster downloads is left deleted")
    func deletedItemIsSkipped() async throws {
        let url = PosterStubURLProtocol.url("deleted.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        let id = try seed(posterURL: url)
        try delete(id)

        try await service.savePoster(persistentModelID: id, posterURL: url)

        #expect(try ModelContext(container).fetch(FetchDescriptor<Remaster.LibraryItem>()).isEmpty, "Saving the poster brought a deleted item back")
    }

    @Test("The poster request is a plain GET with no body, cookies or identifying headers")
    func requestCarriesNoIdentifiers() async throws {
        let url = PosterStubURLProtocol.url("privacy.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        let id = try seed(posterURL: url)

        try await service.savePoster(persistentModelID: id, posterURL: url)

        let request = try #require(PosterStubURLProtocol.requests.first)
        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.httpBodyStream == nil)

        let allowed: Set<String> = ["accept", "accept-encoding", "accept-language", "user-agent", "host", "connection"]
        let sent = Set((request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() })
        #expect(sent.subtracting(allowed).isEmpty, "Unexpected headers: \(sent.subtracting(allowed).sorted())")
    }

    // MARK: - Backfill

    @Test("Backfill downloads only items with a poster URL and no stored poster")
    func backfillPicksMissingPosters() async throws {
        let missing = PosterStubURLProtocol.url("missing-poster.jpg")
        let alreadyStored = PosterStubURLProtocol.url("already-stored.jpg")
        for url in [missing, alreadyStored] {
            PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        }
        let needsPoster = try seed(posterURL: missing)
        _ = try seed(posterURL: alreadyStored, imageData: Self.jpeg(width: 100, height: 150))
        _ = try seed(posterURL: nil)

        try await service.backfillPosters()

        #expect(PosterStubURLProtocol.requests.map(\.url) == [missing], "Requested: \(PosterStubURLProtocol.requests.compactMap(\.url))")
        #expect(try stored(needsPoster).imageData != nil)
    }

    @Test("Backfill with nothing missing makes no requests")
    func backfillWithNothingToDo() async throws {
        _ = try seed(posterURL: PosterStubURLProtocol.url("done.jpg"), imageData: Self.jpeg(width: 100, height: 150))
        _ = try seed(posterURL: nil)

        try await service.backfillPosters()

        #expect(PosterStubURLProtocol.requests.isEmpty)
    }

    @Test("One poster failing doesn't stop the backfill for the others")
    func backfillSurvivesAFailure() async throws {
        let good = (0..<3).map { PosterStubURLProtocol.url("good-\($0).jpg") }
        let bad = PosterStubURLProtocol.url("gone.jpg")
        for url in good {
            PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        }
        PosterStubURLProtocol.respond(to: bad, status: 404, with: Data())

        let badID = try seed(posterURL: bad)
        let goodIDs = try good.map { try seed(posterURL: $0) }

        try await service.backfillPosters()

        for id in goodIDs {
            #expect(try stored(id).imageData != nil, "A good poster wasn't stored after another one failed")
        }
        #expect(try stored(badID).imageData == nil)
    }

    @Test("Backfill never has more than 4 downloads running at once, and still gets every poster")
    func backfillLimitsConcurrency() async throws {
        let urls = (0..<10).map { PosterStubURLProtocol.url("batch-\($0).jpg") }
        for url in urls {
            PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450), delay: 0.1)
        }
        let ids = try urls.map { try seed(posterURL: $0) }

        try await service.backfillPosters()

        #expect(PosterStubURLProtocol.maxInFlight <= 4, "\(PosterStubURLProtocol.maxInFlight) downloads ran at once")
        #expect(PosterStubURLProtocol.requests.count == 10)
        for id in ids {
            #expect(try stored(id).imageData != nil)
        }
    }

    // MARK: - Getting a poster to display

    @Test("A stored poster comes back as an image of the stored size")
    func returnsStoredPoster() async throws {
        let id = try seed(posterURL: nil, imageData: Self.jpeg(width: 320, height: 480))

        let image = try #require(await service.getPoster(persistentModelID: id))

        #expect(image.size.width * image.scale == 320)
        #expect(image.size.height * image.scale == 480)
    }

    @Test("Asking again returns the cached image instead of decoding it again")
    func secondCallIsCached() async throws {
        let id = try seed(posterURL: nil, imageData: Self.jpeg(width: 320, height: 480))

        let first = try #require(await service.getPoster(persistentModelID: id))
        let second = try #require(await service.getPoster(persistentModelID: id))

        #expect(first === second, "The second call decoded the poster again")
    }

    @Test("Each item gets its own poster from the cache")
    func cacheKeysAreDistinct() async throws {
        let tall = try seed(posterURL: nil, imageData: Self.jpeg(width: 200, height: 300))
        let small = try seed(posterURL: nil, imageData: Self.jpeg(width: 100, height: 150))

        // Fill the cache with both, then read them back from it.
        _ = await service.getPoster(persistentModelID: tall)
        _ = await service.getPoster(persistentModelID: small)
        let tallAgain = try #require(await service.getPoster(persistentModelID: tall))
        let smallAgain = try #require(await service.getPoster(persistentModelID: small))

        #expect(tallAgain.size.width * tallAgain.scale == 200)
        #expect(smallAgain.size.width * smallAgain.scale == 100, "One item was given another item's poster")
    }

    @Test("An item with no stored poster returns nil")
    func noPosterIsNil() async throws {
        let id = try seed(posterURL: PosterStubURLProtocol.url("not-yet.jpg"))

        #expect(await service.getPoster(persistentModelID: id) == nil)
    }

    @Test("Stored bytes that aren't an image return nil")
    func corruptDataIsNil() async throws {
        let id = try seed(posterURL: nil, imageData: Data("not an image".utf8))

        #expect(await service.getPoster(persistentModelID: id) == nil)
    }

    @Test("A corrupt stored poster is cleared, so the backfill downloads it again")
    func corruptPosterIsReplaced() async throws {
        let url = PosterStubURLProtocol.url("replacement.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        let id = try seed(posterURL: url, imageData: Data("not an image".utf8))

        #expect(await service.getPoster(persistentModelID: id) == nil)
        #expect(try stored(id).imageData == nil, "The corrupt bytes were left in place, so the backfill would never replace them")
        #expect(try stored(id).posterUpdatedAt == nil)

        try await service.backfillPosters()

        #expect(PosterStubURLProtocol.requests.map(\.url) == [url])
        #expect(await service.getPoster(persistentModelID: id) != nil, "The re-downloaded poster wasn't returned")
    }

    @Test("Saving a poster sets the marker the card reloads on")
    func savingSetsMarker() async throws {
        let url = PosterStubURLProtocol.url("marker.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        let id = try seed(posterURL: url)
        #expect(try stored(id).posterUpdatedAt == nil)

        try await service.savePoster(persistentModelID: id, posterURL: url)

        #expect(try stored(id).posterUpdatedAt != nil)
    }

    @Test("A deleted item returns nil")
    func deletedItemIsNil() async throws {
        let id = try seed(posterURL: nil, imageData: Self.jpeg(width: 100, height: 150))
        try delete(id)

        #expect(await service.getPoster(persistentModelID: id) == nil)
    }

    @Test("A poster that arrives after a nil result is returned next time")
    func missIsNotCached() async throws {
        let url = PosterStubURLProtocol.url("arrives-later.jpg")
        PosterStubURLProtocol.respond(to: url, with: Self.jpeg(width: 300, height: 450))
        let id = try seed(posterURL: url)

        #expect(await service.getPoster(persistentModelID: id) == nil)

        try await service.savePoster(persistentModelID: id, posterURL: url)

        #expect(await service.getPoster(persistentModelID: id) != nil, "The earlier miss was cached, so the new poster never shows")
    }

    // MARK: - Helpers

    /// Saves an item straight into the store and returns its permanent ID
    /// (an unsaved model only has a temporary one).
    private func seed(posterURL: URL?, imageData: Data? = nil) throws -> PersistentIdentifier {
        let item = Remaster.LibraryItem(upc: nil, ean: nil, kind: nil, tmdbId: nil, ownedFormats: nil, edition: nil)
        item.posterURL = posterURL
        item.imageData = imageData
        container.mainContext.insert(item)
        try container.mainContext.save()
        return item.persistentModelID
    }

    private func delete(_ id: PersistentIdentifier) throws {
        let context = container.mainContext
        let item = try #require(try context.fetch(FetchDescriptor<Remaster.LibraryItem>(predicate: #Predicate { $0.persistentModelID == id })).first)
        context.delete(item)
        try context.save()
    }

    /// Reads the item back from a separate context, so this checks what was
    /// saved to the store rather than what's sitting in the main context.
    private func stored(_ id: PersistentIdentifier) throws -> Remaster.LibraryItem {
        let descriptor = FetchDescriptor<Remaster.LibraryItem>(predicate: #Predicate { $0.persistentModelID == id })
        return try #require(try ModelContext(container).fetch(descriptor).first)
    }

    private static func jpeg(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return nil }
        return CGSize(width: width, height: height)
    }
}

/// Answers requests to its own host with a canned reply per URL (404 for any
/// URL it wasn't given), records what was asked, and tracks how many requests
/// were in flight at once.
nonisolated final class PosterStubURLProtocol: URLProtocol {
    static let host = "posters.remaster.test"

    private struct Reply {
        let status: Int
        let body: Data
        let delay: TimeInterval
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [URL: Reply] = [:]
    nonisolated(unsafe) private static var recorded: [URLRequest] = []
    nonisolated(unsafe) private static var inFlight = 0
    nonisolated(unsafe) private static var peakInFlight = 0

    static func url(_ path: String) -> URL {
        URL(string: "https://\(host)/\(path)")!
    }

    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    static var maxInFlight: Int {
        lock.withLock { peakInFlight }
    }

    static func respond(to url: URL, status: Int = 200, with body: Data, delay: TimeInterval = 0) {
        lock.withLock { replies[url] = Reply(status: status, body: body, delay: delay) }
    }

    static func reset() {
        lock.withLock {
            replies = [:]
            recorded = []
            inFlight = 0
            peakInFlight = 0
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let reply = Self.lock.withLock {
            Self.recorded.append(request)
            Self.inFlight += 1
            Self.peakInFlight = max(Self.peakInFlight, Self.inFlight)
            return request.url.flatMap { Self.replies[$0] } ?? Reply(status: 404, body: Data(), delay: 0)
        }

        let finish = { [weak self] in
            guard let self else { return }
            let response = HTTPURLResponse(url: self.request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "image/jpeg"])!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: reply.body)
            self.client?.urlProtocolDidFinishLoading(self)
            Self.lock.withLock { Self.inFlight -= 1 }
        }

        if reply.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay, execute: finish)
        } else {
            finish()
        }
    }

    override func stopLoading() { }
}
