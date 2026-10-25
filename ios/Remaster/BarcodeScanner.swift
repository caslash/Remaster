//
//  BarcodeScanner.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import SwiftUI
import Vision
import VisionKit

/// A live camera view that recognizes barcodes and reports each newly detected payload.
struct BarcodeScanner: View {
    var symbologies: [VNBarcodeSymbology] = []
    let onScanned: (String) -> Void

    var body: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(symbologies: symbologies, onScanned: onScanned)
                .ignoresSafeArea()
        } else {
            ContentUnavailableView(
                "Scanner Unavailable",
                systemImage: "barcode.viewfinder",
                description: Text("This device doesn't support barcode scanning, or camera access is denied.")
            )
        }
    }
}

/// Wraps VisionKit's `DataScannerViewController` for use in SwiftUI.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let symbologies: [VNBarcodeSymbology]
    let onScanned: (String) -> Void

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
        // Start once the controller is in the hierarchy; starting in make can fail silently.
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScanned: (String) -> Void

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        // Fires once when a barcode first enters view, rather than on every geometry update.
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onScanned(payload)
                }
            }
        }
    }
}

#Preview {
    BarcodeScanner { payload in
        print("Scanned: \(payload)")
    }
}
