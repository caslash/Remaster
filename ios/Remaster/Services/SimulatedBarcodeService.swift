//
//  SimulatedBarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import Foundation
import Vision

#if DEBUG

nonisolated public class SimulatedBarcodeService: BarcodeServicing {
    private let errorBarcodes: [String] = ["000", "503", "400", "404"]
    
    public required init () { print("SIMULATING BARCODESERVICE") }
    
    public func fetchBarcode(_ barcode: String, shape: VNBarcodeSymbology?) async throws -> Edition {
        try await Task.sleep(for: .milliseconds(200))
        var editions: [Edition] = []
        
        if (errorBarcodes.contains(barcode)) {
            switch (barcode) {
            case "000": throw NetworkError.transportError(URLError(.notConnectedToInternet))
            case "503": throw NetworkError.serverError(statusCode: 503)
            case "400": throw NetworkError.badRequest
            default: throw NetworkError.notFound
            }
        }
        
        do {
            guard let jsonURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Editions.bundle") else {
                throw NetworkError.invalidURL
            }
            
            let decoder = JSONDecoder()
            
            for url in jsonURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let item = try decoder.decode(Edition.self, from: data)
                    editions.append(item)
                } catch {
                    throw NetworkError.decodingError(error)
                }
            }
        } catch {
            if let networkError = error as? NetworkError {
                throw networkError
            } else {
                throw NetworkError.decodingError(error)
            }
        }
        
        guard let edition = editions.first(where: { $0.barcodes.upc == barcode || $0.barcodes.ean == barcode }) else {
            throw NetworkError.notFound
        }
        
        print("Found \(edition.title)")
        
        return edition
    }
}

#endif
