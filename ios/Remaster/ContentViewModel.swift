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

    init() { 
        self.barcodeService = BarcodeService()
    }

    func processBarcode(barcode: String) throws {
        self.edition = try self.barcodeService.fetchBarcode(barcode: barcode)
    }
}
