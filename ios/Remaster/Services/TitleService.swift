//
//  TitleService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import FactoryKit
import Foundation

nonisolated public final class TitleService: TitleServicing {
    private let remasterService: any RemasterServicing

    init(remasterService: any RemasterServicing = Container.shared.remasterService()) {
        self.remasterService = remasterService
    }

    func searchTitle(_ query: String) async throws -> [Title] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query)
        ]
        
        do {
            let data = try await self.remasterService.fetchRemaster("/search", httpMethod: "GET", queryItems: queryItems)
            return try JSONDecoder().decode([Title].self, from: data)
        } catch let error as BackendError {
            switch error {
            case .serverError(_, let retryAfter):
                if let retryAfter { throw TitleSearchError.serviceUnavailable(retryAfterSeconds: retryAfter) }
                throw error
            default: throw error
            }
        } catch {
            throw error
        }
    }
}
