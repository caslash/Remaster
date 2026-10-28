//
//  BarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/28/26.
//

import Combine
import Foundation

public class BarcodeService {
    private static var remasterURL = Bundle.main.object(forInfoDictionaryKey: "RemasterURL") as? String ?? ""

    init () { }

    public func fetchBarcode(barcode: String) async throws -> Edition {
        guard let url = URL(string: "\(Self.remasterURL)/upc/\(barcode.trimmingCharacters(in: [" "]))") else {
            throw NetworkError.invalidURL
        }

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

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, statusText: errorResponse?.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }

        do {
            return try JSONDecoder().decode(Edition.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case transportError(URLError)
    case serverError(statusCode: Int, statusText: String)
    case decodingError(Error)

    public var errorDescription: String? {
        switch (self) {
            case .invalidURL: "Invalid URL"
            case .invalidResponse: "Invalid response"
            case .transportError: "Error request"
            case .serverError(_, let statusText): statusText
            case .decodingError: "Error decoding response"
        }
    }
}

private struct ErrorResponse: Decodable {
    var message: String
}
