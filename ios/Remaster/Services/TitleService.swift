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

    func searchTitle(_ query: String) async throws(TitleSearchError) -> [Title] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query)
        ]
        
        do {
            let data = try await self.remasterService.fetchRemaster("/search", httpMethod: "GET", queryItems: queryItems)
            return try JSONDecoder().decode([Title].self, from: data)
        } catch let error as BackendError {
            switch error {
            case .generic, .invalidResponse, .invalidURL: throw TitleSearchError.unexpected
            case .transportError(let urlError):
                switch urlError.code {
                case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .networkConnectionLost: throw TitleSearchError.offline
                case .cancelled: throw TitleSearchError.cancelled
                default: throw TitleSearchError.tempUnavailable
                }
            case .serverError(let statusCode, let retryAfter):
                switch statusCode {
                case 503: throw TitleSearchError.serviceUnavailable(retryAfterSeconds: retryAfter ?? 5)
                case 502, 504: throw TitleSearchError.tempUnavailable
                default: throw TitleSearchError.unexpected
                }
            }
        } catch {
            throw TitleSearchError.unexpected
        }
    }
}
