//
//  BarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/28/26.
//

import FactoryKit
import Foundation
import Vision

nonisolated public class BarcodeService: BarcodeServicing {
    @Injected(\.remasterService) private var remasterService: any RemasterServicing

    public func fetchBarcode(_ barcode: String, shape: VNBarcodeSymbology?) async throws -> Edition {
        guard !barcode.isEmpty else { throw NetworkError.badRequest }
        
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedBarcode.isEmpty else { throw NetworkError.badRequest }
        
        var queryItems: [URLQueryItem]?
        
        if let shapeString = shape?.queryString {
            queryItems = []
            queryItems?.append(URLQueryItem(name: "shape", value: shapeString))
        }

        do {
            let data = try await self.remasterService.fetchRemaster("/upc/\(trimmedBarcode)", httpMethod: "GET", queryItems: queryItems)
            return try JSONDecoder().decode(Edition.self, from: data)
        } catch let error as BackendError {
            switch error {
            case .generic(let error): throw error
            case .invalidURL: throw NetworkError.invalidURL
            case .invalidResponse: throw NetworkError.invalidResponse
            case .serverError(let statusCode, _):
                switch statusCode {
                case 400: throw NetworkError.badRequest
                case 404: throw NetworkError.notFound
                default: throw NetworkError.serverError(statusCode: statusCode)
                }
            case .transportError(let urlError): throw NetworkError.transportError(urlError)
            }
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
