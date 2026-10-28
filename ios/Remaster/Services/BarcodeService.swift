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
    private var anycancellableset = Set<AnyCancellable>()

    init () { }

    public func fetchBarcode(barcode: String) throws -> Edition? {
        var edition: Edition?

        if let url: URL = URL(string: "\(Self.remasterURL)/upc/\(barcode.trimmingCharacters(in: [" "]))") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let jsonDecoder = JSONDecoder()

            URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { return try jsonDecoder.decode(Edition.self, from: $0.data) }
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { print("completion: \($0)") }, receiveValue: { edition = $0 })
            .store(in: &self.anycancellableset)
        }

        return edition
    }
}
