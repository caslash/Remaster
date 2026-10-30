//
//  IBarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import Foundation
import Vision

nonisolated protocol BarcodeServicing {
    func fetchBarcode(_ barcode: String, shape: VNBarcodeSymbology?) async throws -> Edition
}
