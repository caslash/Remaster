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
    
    public var searchType: TitleSearchType
    public var upc: String
    public var searchText: String
    public var results: [Title] = []
    
    public var networkError: NetworkError?
    public var error: any Error?
    
    init(searchType: TitleSearchType, textPrefill: String? = nil) {
        self.searchType = searchType
        self.upc = searchType.upc
        self.searchText = textPrefill ?? ""
    }
    
    public func searchTitle() async {
        do {
            self.results = try await self.titleService.searchTitle(self.searchText)
        } catch let error as NetworkError {
            self.networkError = error
        } catch {
            self.error = error
        }
    }
}

public enum TitleSearchType {
    case barcodeNotFound(upc: String), titleNotConfirmed(upc: String)
    
    public var navigationTitle: String {
        switch self {
        case .barcodeNotFound: return "Add Title"
        case .titleNotConfirmed: return "Find Title"
        }
    }
    
    public var unmatchedCardTitle: String {
        switch self {
        case .barcodeNotFound: return "We don't know this barcode yet"
        case .titleNotConfirmed: return "We found this disc, not its title"
        }
    }
    
    public var unmatchedCardText: String {
        switch self {
        case .barcodeNotFound(let upc): return "UPC \(upc) • Search by title and we'll keep the barcode with your disc."
        case .titleNotConfirmed(let upc): return "UPC \(upc) • Pick the movie or show it belongs to. Your disc's format and details stay as scanned."
        }
    }
    
    public var footerText: String {
        switch self {
        case .barcodeNotFound: return "Optional. Sends only the barcode and the title and format you choose, so the next collector gets a match. Nothing about you or your library is sent."
        case .titleNotConfirmed: return "Pick a title to attach it to your disc. Nothing about the match leaves this iPhone."
        }
    }
    
    public var upc: String {
        switch self {
        case .barcodeNotFound(let upc): return upc
        case .titleNotConfirmed(let upc): return upc
        }
    }
}
