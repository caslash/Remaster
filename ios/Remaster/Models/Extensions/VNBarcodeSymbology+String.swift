//
//  VNBarcodeSymbology+String.swift
//  Remaster
//
//  Created by Cameron Slash on 10/30/26.
//

import Vision

nonisolated extension VNBarcodeSymbology {
    var queryString: String? {
        switch (self) {
            case .ean13: "EAN-13"
            case .upce: "UPC-E"
            case .ean8: "EAN-8"
            default: nil
        }
    }
}
