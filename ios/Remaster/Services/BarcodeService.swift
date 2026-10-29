//
//  BarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/28/26.
//

import Combine
import Foundation

nonisolated public class BarcodeService: IBarcodeService {
    private static let remasterURL = Bundle.main.object(forInfoDictionaryKey: "RemasterURL") as? String ?? ""

    public required init () { }

    public func fetchBarcode(_ barcode: String) async throws -> Edition {
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
        
        if (httpResponse.statusCode == 404) { throw NetworkError.notFound(barcode: barcode) }

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

private struct ErrorResponse: Decodable {
    var message: String
}
