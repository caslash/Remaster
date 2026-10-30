//
//  BarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/28/26.
//

import Combine
import Foundation
import OSLog
import Vision

nonisolated public class BarcodeService: BarcodeServicing {
    private static let remasterBaseUrl = Bundle.main.object(forInfoDictionaryKey: "RemasterBaseUrl") as? String ?? ""
    private static let remasterLocalPort = Bundle.main.object(forInfoDictionaryKey: "RemasterLocalPort") as? String
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BarcodeService")

    public required init () { }

    public func fetchBarcode(_ barcode: String, shape: VNBarcodeSymbology?) async throws -> Edition {
        guard !barcode.isEmpty else { throw NetworkError.badRequest }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.remasterBaseUrl
        components.path = "/upc/\(barcode.trimmingCharacters(in: .whitespacesAndNewlines))"
        
        if let port = Self.remasterLocalPort, let portNumber = Int(port) {
            components.port = portNumber
        }
        
        if let shapeString = shape?.queryString {
            components.queryItems = []
            components.queryItems?.append(URLQueryItem(name: "shape", value: shapeString))
        }
        
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            guard let urlError = error as? URLError else {
                throw error
            }

            throw NetworkError.transportError(urlError)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if (httpResponse.statusCode == 400) { throw NetworkError.badRequest }
        if (httpResponse.statusCode == 404) { throw NetworkError.notFound }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            Self.logger.warning("Server responded with \(httpResponse.statusCode): \(errorResponse?.message ?? "")")
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Edition.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}

private struct ErrorResponse: Decodable {
    var message: String
}
