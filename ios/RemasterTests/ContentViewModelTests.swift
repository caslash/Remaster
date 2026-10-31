//
//  ContentViewModelTests.swift
//  RemasterTests
//
//  The lookup flow on the main screen (RMSTR-11 AC 3, 4 and 5).
//
//  ContentViewModel resolves its BarcodeServicing from Container.shared when it's
//  created, so each test registers a stub first. The suite is serialized because
//  Container.shared is global.
//

import FactoryKit
import Foundation
import Synchronization
import Testing
import Vision
@testable import Remaster

@MainActor
@Suite("ContentViewModel", .serialized)
final class ContentViewModelTests {
    private let stub = StubBarcodeService()

    // Each test starts from a fresh container. There's no deinit reset because
    // Swift Testing can release the suite off the main actor.
    init() {
        Container.shared.reset()
        Container.shared.barcodeService.register { [stub] in stub }
    }

    @Test("Starts idle, so the scanner is running")
    func startsIdle() {
        let viewModel = ContentViewModel()

        #expect(viewModel.isIdle)
        #expect(viewModel.edition == nil)
    }

    @Test("A successful lookup shows the edition and pauses the scanner")
    func successShowsEdition() async throws {
        stub.result = .success(try Fixtures.decode(Fixtures.comboPack))
        let viewModel = ContentViewModel()

        viewModel.processBarcode("0786936900001", shape: .ean13)
        #expect(viewModel.isFetching)
        #expect(!viewModel.isIdle)
        try await waitForLookup(viewModel)

        let edition = try #require(viewModel.edition)
        #expect(edition.title == "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook")
        #expect(edition.format == .uhd)
        #expect(viewModel.networkError == nil)
        #expect(viewModel.error == nil)
        #expect(!viewModel.isIdle)
    }

    @Test("The scanned barcode and shape are what get looked up")
    func passesBarcodeAndShape() async throws {
        stub.result = .success(try Fixtures.decode(Fixtures.minimal))
        let viewModel = ContentViewModel()

        viewModel.processBarcode("04252614", shape: .upce)
        try await waitForLookup(viewModel)

        #expect(stub.calls.count == 1)
        #expect(stub.calls.first?.barcode == "04252614")
        #expect(stub.calls.first?.shape == .upce)
    }

    @Test("Not found shows a not-found error, not an edition")
    func notFound() async throws {
        stub.result = .failure(NetworkError.notFound)
        let viewModel = ContentViewModel()

        viewModel.processBarcode("0786936900378", shape: .ean13)
        try await waitForLookup(viewModel)

        let error = try #require(viewModel.networkError)
        #expect(error.caseName == "notFound")
        #expect(viewModel.edition == nil)
        #expect(viewModel.error == nil)
    }

    @Test("A network or backend failure shows a retryable error", arguments: [
        NetworkError.transportError(URLError(.notConnectedToInternet)),
        .serverError(statusCode: 502),
    ])
    func retryableFailure(_ failure: NetworkError) async throws {
        stub.result = .failure(failure)
        let viewModel = ContentViewModel()

        viewModel.processBarcode("0786936900378", shape: .ean13)
        try await waitForLookup(viewModel)

        let error = try #require(viewModel.networkError)
        #expect(error.isRetryable)
        #expect(viewModel.edition == nil)
    }

    @Test("A failure that isn't a NetworkError goes to the general error")
    func otherFailure() async throws {
        stub.result = .failure(CancellationError())
        let viewModel = ContentViewModel()

        viewModel.processBarcode("0786936900378", shape: .ean13)
        try await waitForLookup(viewModel)

        #expect(viewModel.error is CancellationError)
        #expect(viewModel.networkError == nil)
        #expect(viewModel.edition == nil)
    }

    @Test("A second scan while a lookup is running is ignored")
    func ignoresScanWhileFetching() async throws {
        stub.result = .success(try Fixtures.decode(Fixtures.minimal))
        let viewModel = ContentViewModel()

        viewModel.processBarcode("0786936900378", shape: .ean13)
        viewModel.processBarcode("0097361180047", shape: .ean13)
        try await waitForLookup(viewModel)

        #expect(stub.calls.count == 1)
        #expect(stub.calls.first?.barcode == "0786936900378")
    }

    @Test("Retry looks up the same barcode and shape again")
    func retryRepeatsLookup() async throws {
        stub.result = .failure(NetworkError.serverError(statusCode: 504))
        let viewModel = ContentViewModel()
        viewModel.processBarcode("04252614", shape: .upce)
        try await waitForLookup(viewModel)

        stub.result = .success(try Fixtures.decode(Fixtures.minimal))
        viewModel.retry()
        try await waitForLookup(viewModel)

        #expect(stub.calls.count == 2)
        #expect(stub.calls.last?.barcode == "04252614")
        #expect(stub.calls.last?.shape == .upce)
        #expect(viewModel.networkError == nil)
        #expect(viewModel.edition != nil)
    }

    @Test("Retry before any scan does nothing")
    func retryWithoutScan() {
        let viewModel = ContentViewModel()

        viewModel.retry()

        #expect(stub.calls.isEmpty)
        #expect(!viewModel.isFetching)
    }

    @Test("Starting a new lookup clears the previous error")
    func newLookupClearsErrors() async throws {
        stub.result = .failure(NetworkError.notFound)
        let viewModel = ContentViewModel()
        viewModel.processBarcode("0786936900378", shape: .ean13)
        try await waitForLookup(viewModel)
        try #require(viewModel.networkError != nil)

        stub.result = .success(try Fixtures.decode(Fixtures.minimal))
        viewModel.processBarcode("0097361180047", shape: .ean13)

        #expect(viewModel.networkError == nil)
        #expect(viewModel.error == nil)
        try await waitForLookup(viewModel)
    }

    /// processBarcode starts its own Task, so wait for isFetching to clear.
    private func waitForLookup(_ viewModel: ContentViewModel, timeout: Duration = .seconds(3)) async throws {
        let deadline = ContinuousClock.now + timeout
        while viewModel.isFetching {
            guard ContinuousClock.now < deadline else {
                Issue.record("Lookup didn't finish within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

/// Returns a canned result and records each lookup.
nonisolated final class StubBarcodeService: BarcodeServicing, Sendable {
    struct Call {
        var barcode: String
        var shape: VNBarcodeSymbology?
    }

    private let state = Mutex<(result: Result<Edition, any Error>, calls: [Call])>(
        (.failure(NetworkError.invalidResponse), [])
    )

    var result: Result<Edition, any Error> {
        get { state.withLock { $0.result } }
        set { state.withLock { $0.result = newValue } }
    }

    var calls: [Call] {
        state.withLock { $0.calls }
    }

    func fetchBarcode(_ barcode: String, shape: VNBarcodeSymbology?) async throws -> Edition {
        let result = state.withLock {
            $0.calls.append(Call(barcode: barcode, shape: shape))
            return $0.result
        }
        return try result.get()
    }
}
