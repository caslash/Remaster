//
//  TitleService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import FactoryKit
import Foundation

nonisolated public class TitleService: TitleServicing {
    @Injected(\.remasterService) private var remasterService: any RemasterServicing
    
    func searchTitle(_ searchText: String) async throws -> [Title] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: searchText)
        ]
        
        let data = try await self.remasterService.fetchRemaster("/search", httpMethod: "GET", queryItems: queryItems)
        
        do {
            return try JSONDecoder().decode([Title].self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
