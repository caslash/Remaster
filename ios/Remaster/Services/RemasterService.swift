//
//  RemasterService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation
import OSLog

nonisolated public final class RemasterService: RemasterServicing {
    private static let remasterBaseUrl = Bundle.main.object(forInfoDictionaryKey: "RemasterBaseUrl") as? String ?? ""
    private static let remasterLocalPort = Bundle.main.object(forInfoDictionaryKey: "RemasterLocalPort") as? String
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RemasterService")
    
    func fetchRemaster(_ pathName: String, httpMethod: String, queryItems: [URLQueryItem]?) async throws(BackendError) -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.remasterBaseUrl
        components.path = pathName
        components.queryItems = queryItems
        
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        
        if let port = Self.remasterLocalPort, let portNumber = Int(port) {
            components.port = portNumber
        }
        
        guard let url = components.url else { throw BackendError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            guard let urlError = error as? URLError else { throw BackendError.generic(error) }
            
            throw BackendError.transportError(urlError: urlError)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            Self.logger.warning("Server responded with \(httpResponse.statusCode): \(errorResponse?.message ?? "")")
            
            let seconds = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw BackendError.serverError(statusCode: httpResponse.statusCode, retryAfter: seconds)
        }
        
        return data
    }
}

private struct ErrorResponse: Decodable {
    var message: String
}
