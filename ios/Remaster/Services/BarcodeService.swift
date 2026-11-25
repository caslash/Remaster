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
        
        let data = try await self.remasterService.fetchRemaster("/upc/\(trimmedBarcode)", httpMethod: "GET", queryItems: queryItems)

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
