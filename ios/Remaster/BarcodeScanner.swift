//
//  BarcodeScanner.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import SwiftUI
import Vision
import VisionKit

struct BarcodeScanner: View {
    var symbologies: [VNBarcodeSymbology] = []
    let isPresented: Bool
    let onScanned: (String, VNBarcodeSymbology?) -> Void

    var body: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(canScan: isPresented, symbologies: symbologies, onScanned: onScanned)
                .ignoresSafeArea()
        } else {
            ManualEntryView(isPresented: isPresented, onSubmit: onScanned)
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let canScan: Bool
    let symbologies: [VNBarcodeSymbology]
    let onScanned: (String, VNBarcodeSymbology?) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScanned = onScanned
        if !scanner.isScanning && canScan {
            try? scanner.startScanning()
        } else if scanner.isScanning && !canScan {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScanned: (String, VNBarcodeSymbology?) -> Void

        init(onScanned: @escaping (String, VNBarcodeSymbology?) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScanned(payload, barcode.observation.symbology)
                }
            }
        }
    }
}

#Preview {
    BarcodeScanner (isPresented: true, onScanned: { payload, _ in
        print("Scanned: \(payload)")
    })
}
