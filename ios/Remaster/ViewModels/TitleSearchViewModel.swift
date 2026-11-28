//
//  TitleSearchViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import FactoryKit
import Foundation
import Observation

@Observable
public class TitleSearchViewModel {
    @ObservationIgnored @Injected(\.titleService) private var titleService: any TitleServicing
    
    var query: String {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch(debounced: true)
        }
    }
    
    private(set) var state: TitleSearchState = .idle
    
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let maxAttempts = 2
    
    init(searchType: TitleSearchType, clock: any Clock<Duration> = ContinuousClock(), debounce: Duration = .milliseconds(300)) {
        self.clock = clock
        self.debounce = debounce
        self.query = searchType.prefillQuery
        
        scheduleSearch(debounced: true)
    }
    
    func retry() {
        scheduleSearch(debounced: false)
    }
    
    private func scheduleSearch(debounced: Bool) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else {
            state = .idle
            return
        }
        
        searchTask = Task {
            if debounced {
                do { try await clock.sleep(for: debounce) } catch { return }
            }
            
            await run(trimmed)
        }
    }
    
    private func run(_ query: String) async {
        for attempt in 1...maxAttempts {
            state = .loading
            
            do {
                let titles = try await titleService.searchTitle(query)
                guard !Task.isCancelled else { return }
                state = titles.isEmpty ? .noMatches : .results(titles)
                return
            } catch TitleSearchError.serviceUnavailable(let seconds) where attempt < maxAttempts {
                guard !Task.isCancelled else { return }
                state = .waitingToRetry(until: .now.addingTimeInterval(TimeInterval(seconds)), attempt: attempt)
                do { try await clock.sleep(for: .seconds(seconds)) } catch { return }
            } catch TitleSearchError.cancelled {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error)
                return
            }
        }
    }
}

public enum TitleSearchState {
    case idle, loading, waitingToRetry(until: Date, attempt: Int), results([Title]), noMatches, failed(TitleSearchError)
}

public enum TitleSearchType {
    case addTitle(upc: String?), titleNotConfirmed(upc: String, prefillQuery: String)
    
    public var navigationTitle: String {
        switch self {
        case .addTitle: return "Add Title"
        case .titleNotConfirmed: return "Find Title"
        }
    }
    
    public var unmatchedCardTitle: String {
        switch self {
        case .addTitle: return "We don't know this barcode yet"
        case .titleNotConfirmed: return "We found this disc, not its title"
        }
    }
    
    public var unmatchedCardText: String {
        switch self {
        case .addTitle(let upc):
            switch upc {
            case .some(let upc): return "UPC \(upc) • Search by title and we'll keep the barcode with your disc."
            case .none: return ""
            }
        case .titleNotConfirmed(let upc, _): return "UPC \(upc) • Pick the movie or show it belongs to. Your disc's format and details stay as scanned."
        }
    }
    
    public var footerText: String {
        switch self {
        case .addTitle: return ""
        case .titleNotConfirmed: return "Pick a title to attach it to your disc. Nothing about the match leaves this iPhone."
        }
    }
    
    public var upc: String? {
        switch self {
        case .addTitle(let upc): return upc
        case .titleNotConfirmed(let upc, _): return upc
        }
    }
    
    public var prefillQuery: String {
        switch self {
        case .addTitle: return ""
        case .titleNotConfirmed(_, let prefillQuery): return prefillQuery
        }
    }
}
