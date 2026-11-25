//
//  RecordingPosterStore.swift
//  RemasterTests
//
//  A stand-in PosterStore for tests of code that asks for posters.
//

import Foundation
import SwiftData
import UIKit
@testable import Remaster

/// A PosterStore that records save requests instead of downloading anything.
/// It can be told to fail or to take a while, and the test can wait for the
/// first request, since LibraryService doesn't wait for posters itself.
nonisolated final class RecordingPosterStore: PosterStore, @unchecked Sendable {
    struct SaveRequest: Sendable {
        let id: PersistentIdentifier
        let url: URL
    }

    private let lock = NSLock()
    private var saves: [SaveRequest] = []
    private var shouldFail = false
    private var delay: Duration = .zero

    var failSaves: Bool {
        get { lock.withLock { shouldFail } }
        set { lock.withLock { shouldFail = newValue } }
    }

    var saveDelay: Duration {
        get { lock.withLock { delay } }
        set { lock.withLock { delay = newValue } }
    }

    func savePoster(persistentModelID: PersistentIdentifier, posterURL: URL) async throws {
        lock.withLock { saves.append(SaveRequest(id: persistentModelID, url: posterURL)) }
        if saveDelay > .zero {
            try await Task.sleep(for: saveDelay)
        }
        if failSaves {
            throw URLError(.notConnectedToInternet)
        }
    }

    func backfillPosters() async throws { }

    func getPoster(persistentModelID: PersistentIdentifier) async -> UIImage? { nil }

    /// The first save request, waiting up to `timeout` for it to arrive.
    func waitForSave(timeout: Duration = .seconds(1)) async -> SaveRequest? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let first = lock.withLock({ saves.first }) { return first }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return lock.withLock { saves.first }
    }
}
