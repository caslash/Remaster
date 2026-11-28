//
//  SimulatedTitleService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

#if DEBUG
nonisolated final public class SimulatedTitleService: TitleServicing {
    private let errorSearches: [String] = ["000", "503", "504", "unexpected"]
    
    public required init() { print ("SIMULATING TITLESERVICE") }
    
    func searchTitle(_ query: String) async throws(TitleSearchError) -> [Title] {
        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            throw TitleSearchError.cancelled
        }
        
        let trimmedText = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard trimmedText.count > 1 else { return [] }
        var titles: [Title] = []
        
        if (errorSearches.contains(trimmedText)) {
            switch (trimmedText) {
            case "000": throw TitleSearchError.offline
            case "503": throw TitleSearchError.serviceUnavailable(retryAfterSeconds: 5)
            case "504": throw TitleSearchError.tempUnavailable
            default: throw TitleSearchError.unexpected
            }
        }
        
        do {
            guard let url = Bundle.main.url(forResource: trimmedText, withExtension: "json", subdirectory: "Titles.bundle") else { return [] }
            
            let decoder = JSONDecoder()
            
            let data = try Data(contentsOf: url)
            titles = try decoder.decode([Title].self, from: data)
        } catch {
            throw TitleSearchError.unexpected
        }
        
        return titles
    }
}
#endif
