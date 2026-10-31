//
//  BarcodeSymbologyTests.swift
//  RemasterTests
//
//  Mapping Vision symbologies to the backend's `shape` values
//  (backend/docs/upc-endpoint.md, Request).
//

import Testing
import Vision
@testable import Remaster

@Suite("Barcode shape query value")
struct BarcodeSymbologyTests {

    @Test("Scanned retail barcode types map to the backend's names", arguments: [
        (VNBarcodeSymbology.ean13, "EAN-13"),
        (VNBarcodeSymbology.upce, "UPC-E"),
        (VNBarcodeSymbology.ean8, "EAN-8"),
    ])
    func retailSymbologies(_ symbology: VNBarcodeSymbology, _ expected: String) {
        #expect(symbology.queryString == expected)
    }

    @Test("Every other symbology has no shape value", arguments: VNBarcodeSymbology.allCases)
    func otherSymbologies(_ symbology: VNBarcodeSymbology) {
        let retail: [VNBarcodeSymbology] = [.ean13, .upce, .ean8]
        guard !retail.contains(symbology) else { return }

        #expect(symbology.queryString == nil)
    }

    @Test("Nothing maps to UPC-A, which Vision reports as EAN-13")
    func noUPCA() {
        #expect(!VNBarcodeSymbology.allCases.contains { $0.queryString == "UPC-A" })
    }
}

private extension VNBarcodeSymbology {
    static var allCases: [VNBarcodeSymbology] {
        (try? VNDetectBarcodesRequest().supportedSymbologies()) ?? []
    }
}
