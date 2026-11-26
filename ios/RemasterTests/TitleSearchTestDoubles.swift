//
//  TitleSearchTestDoubles.swift
//  RemasterTests
//
//  Stand-ins for the title search tests (RMSTR-16):
//
//  - ManualClock: a Clock that only moves when a test advances it, so the
//    300 ms debounce and the Retry-After wait run instantly and exactly.
//  - StubTitleService: answers searches with canned results per query and can
//    hold a search in flight until the test releases it.
//  - FakeRemasterService: answers TitleService's backend call with a canned
//    result and records what was asked.
//

import Foundation
import Synchronization
import Testing
@testable import Remaster

// MARK: - ManualClock

/// A clock whose time only moves when `advance(by:)` is called.
nonisolated final class ManualClock: Clock, Sendable {
    nonisolated struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        var deadline: Instant
        var continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleepers: [UUID: Sleeper] = [:]
        /// Sleeps cancelled before they were registered.
        var cancelledEarly: Set<UUID> = []
        var sleepCount = 0
    }

    private let state = Mutex(State())

    var now: Instant { state.withLock { $0.now } }
    var minimumResolution: Duration { .zero }

    /// Sleeps currently waiting for the clock to reach their deadline.
    var pendingSleeps: Int { state.withLock { $0.sleepers.count } }

    /// Every sleep ever started, including finished and cancelled ones.
    var sleepCount: Int { state.withLock { $0.sleepCount } }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                enum Action { case wait, resume, cancel }

                let action: Action = state.withLock { state in
                    state.sleepCount += 1
                    if state.cancelledEarly.remove(id) != nil { return .cancel }
                    if deadline <= state.now { return .resume }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return .wait
                }

                switch action {
                case .wait: break
                case .resume: continuation.resume()
                case .cancel: continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let sleeper: Sleeper? = state.withLock { state in
                if let sleeper = state.sleepers.removeValue(forKey: id) { return sleeper }
                state.cancelledEarly.insert(id)
                return nil
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward and wakes every sleep whose deadline has passed.
    func advance(by duration: Duration) {
        let due: [Sleeper] = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let ready = state.sleepers.filter { $0.value.deadline <= now }
            for id in ready.keys { state.sleepers.removeValue(forKey: id) }
            return Array(ready.values)
        }

        for sleeper in due { sleeper.continuation.resume() }
    }
}

// MARK: - StubTitleService

/// Answers each search from a per-query queue of canned results, falling back
/// to no results, and records every query it was asked.
nonisolated final class StubTitleService: TitleServicing, Sendable {
    private struct State {
        var responses: [String: [Result<[Title], TitleSearchError>]] = [:]
        var queries: [String] = []
        var isHolding = false
        var held: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    var queries: [String] { state.withLock { $0.queries } }

    /// Queues results for a query, used in order, one per search.
    func respond(to query: String, with results: Result<[Title], TitleSearchError>...) {
        state.withLock { $0.responses[query, default: []].append(contentsOf: results) }
    }

    /// Searches started from now on wait until `release()`.
    func hold() {
        state.withLock { $0.isHolding = true }
    }

    /// Lets every held search finish.
    func release() {
        let held = state.withLock { state in
            state.isHolding = false
            defer { state.held = [] }
            return state.held
        }
        for continuation in held { continuation.resume() }
    }

    func searchTitle(_ query: String) async throws(TitleSearchError) -> [Title] {
        let mustWait = state.withLock { state in
            state.queries.append(query)
            return state.isHolding
        }

        if mustWait {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let resumeNow = state.withLock { state in
                    guard state.isHolding else { return true }
                    state.held.append(continuation)
                    return false
                }
                if resumeNow { continuation.resume() }
            }
        }

        let result: Result<[Title], TitleSearchError> = state.withLock { state in
            guard var queue = state.responses[query], !queue.isEmpty else { return .success([]) }
            let next = queue.removeFirst()
            state.responses[query] = queue
            return next
        }

        switch result {
        case .success(let titles): return titles
        case .failure(let error): throw error
        }
    }
}

// MARK: - FakeRemasterService

/// Answers every backend call with one canned result and records each call.
nonisolated final class FakeRemasterService: RemasterServicing, Sendable {
    struct Call {
        var path: String
        var httpMethod: String
        var queryItems: [URLQueryItem]?
    }

    private let state = Mutex<(result: Result<Data, BackendError>, calls: [Call])>(
        (.failure(.invalidResponse), [])
    )

    var result: Result<Data, BackendError> {
        get { state.withLock { $0.result } }
        set { state.withLock { $0.result = newValue } }
    }

    var calls: [Call] { state.withLock { $0.calls } }

    func fetchRemaster(_ pathName: String, httpMethod: String, queryItems: [URLQueryItem]?) async throws(BackendError) -> Data {
        let result = state.withLock {
            $0.calls.append(Call(path: pathName, httpMethod: httpMethod, queryItems: queryItems))
            return $0.result
        }

        switch result {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
}

// MARK: - Helpers

/// Polls until `condition` holds, recording an issue if it doesn't within `timeout`.
/// The view model's searches run in their own Tasks, so tests wait for them.
@MainActor
func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting for \(description)", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

/// Gives pending Tasks a moment to run, for asserting that nothing happened.
@MainActor
func settle() async {
    try? await Task.sleep(for: .milliseconds(50))
}

extension TitleSearchError {
    /// The case without its associated value, for comparing in tests.
    var caseName: String {
        switch self {
        case .serviceUnavailable: "serviceUnavailable"
        case .offline: "offline"
        case .tempUnavailable: "tempUnavailable"
        case .unexpected: "unexpected"
        case .cancelled: "cancelled"
        }
    }
}

extension TitleSearchState {
    var caseName: String {
        switch self {
        case .idle: "idle"
        case .loading: "loading"
        case .waitingToRetry: "waitingToRetry"
        case .results: "results"
        case .noMatches: "noMatches"
        case .failed: "failed"
        }
    }

    var titles: [Title]? {
        if case .results(let titles) = self { return titles }
        return nil
    }

    var error: TitleSearchError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

enum SampleTitles {
    static let dune = Title(tmdbId: "438631", kind: .movie, name: "Dune", year: 2021)
    static let duneMiniseries = Title(tmdbId: "438631", kind: .tv, name: "Frank Herbert's Dune", year: 2000)
    static let dunePartTwo = Title(tmdbId: "693134", kind: .movie, name: "Dune: Part Two", year: 2024)
}
