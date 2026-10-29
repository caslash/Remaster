//
//  IBarcodeService.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import Foundation

nonisolated protocol IBarcodeService {
    init()
    
    func fetchBarcode(_ barcode: String) async throws -> Edition
}
