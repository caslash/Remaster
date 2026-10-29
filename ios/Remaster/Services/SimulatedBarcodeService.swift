//
//  SimulatedBarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import Foundation

nonisolated public class SimulatedBarcodeService: IBarcodeService {
    public required init () { print("SIMULATING BARCODESERVICE") }
    
    public func fetchBarcode(_ barcode: String) async throws -> Edition {
        var editions: [Edition] = []
        
        do {
            guard let jsonURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
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
            throw NetworkError.invalidResponse
        }
        
        guard let edition = editions.first(where: { $0.barcodes.upc == barcode }) else {
            throw NetworkError.serverError(statusCode: 404, statusText: "Could not find UPC \(barcode)")
        }
        
        print("Found \(edition.title)")
        
        return edition
    }
}
