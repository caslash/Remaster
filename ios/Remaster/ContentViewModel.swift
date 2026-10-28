//
//  ContentViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import Combine
import Foundation
import Observation

@Observable
public class ContentViewModel {
    private var barcodeService: BarcodeService

    public var edition: Edition?
    public var error: any Error?

    init() { 
        self.barcodeService = BarcodeService()
    }

    func processBarcode(barcode: String) async {
        do {
            self.edition = try await self.barcodeService.fetchBarcode(barcode: barcode)
        } catch {
            self.error = error
        }
    }
}
