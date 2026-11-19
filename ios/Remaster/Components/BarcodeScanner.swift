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
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScanned = onScanned
        context.coordinator.isPaused = !canScan
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScanned: (String, VNBarcodeSymbology?) -> Void
        var isPaused = false
        private var handledIds = Set<RecognizedItem.ID>()

        init(onScanned: @escaping (String, VNBarcodeSymbology?) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !isPaused else { return }
            for item in addedItems where !handledIds.contains(item.id) {
                guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue else {
                    continue
                }
                
                handledIds.insert(item.id)
                isPaused = true
                onScanned(payload, barcode.observation.symbology)
                return
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            removedItems.forEach { handledIds.remove($0.id) }
        }
    }
}

#Preview {
    BarcodeScanner (isPresented: true, onScanned: { payload, _ in
        print("Scanned: \(payload)")
    })
}
