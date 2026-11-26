//
//  SimulatedTitleService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

#if DEBUG
nonisolated final public class SimulatedTitleService: TitleServicing {
    private let errorSearches: [String] = ["000", "503", "400", "404"]
    
    public required init() { print ("SIMULATING TITLESERVICE") }
    
    func searchTitle(_ searchText: String) async throws -> [Title] {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty && trimmedText.count > 2 else { return [] }
        var titles: [Title] = []
        
        if (errorSearches.contains(searchText)) {
            switch (searchText) {
            case "000": throw NetworkError.transportError(URLError(.notConnectedToInternet))
            case "503": throw NetworkError.serverError(statusCode: 503)
            case "400": throw NetworkError.badRequest
            default: throw NetworkError.notFound
            }
        }
        
        do {
            guard let url = Bundle.main.url(forResource: searchText, withExtension: "json", subdirectory: "Titles.bundle") else { throw NetworkError.invalidURL }
            
            let decoder = JSONDecoder()
            
            do {
                let data = try Data(contentsOf: url)
                titles = try decoder.decode([Title].self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch {
            if let networkError = error as? NetworkError {
                throw networkError
            } else {
                throw NetworkError.decodingError(error)
            }
        }
        
        return titles
    }
}
#endif
