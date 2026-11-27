//
//  BarcodeScanner.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import SwiftUI
import Vision
import VisionKit

struct BarcodeScanner<ManualEntry: View>: View {
    @Environment(\.closeScanner) private var closeScanner
    var symbologies: [VNBarcodeSymbology] = []
    let isPresented: Bool
    let onScanned: (String, VNBarcodeSymbology?) -> Void
    @ViewBuilder let manualEntry: () -> ManualEntry

    init(
        symbologies: [VNBarcodeSymbology] = [],
        isPresented: Bool,
        onScanned: @escaping (String, VNBarcodeSymbology?) -> Void,
        @ViewBuilder manualEntry: @escaping () -> ManualEntry
    ) {
        self.symbologies = symbologies
        self.isPresented = isPresented
        self.onScanned = onScanned
        self.manualEntry = manualEntry
    }

    var body: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(canScan: isPresented, symbologies: symbologies, onScanned: onScanned)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    NavigationLink {
                        manualEntry()
                    } label: {
                        Label("Enter manually", systemImage: "keyboard")
                    }
                    .foregroundStyle(.primary)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .toolbar {
                    if #available(anyAppleOS 27.1, *) {
                        ToolbarItem(placement: .automatic) {
                            Button(role: .close) {
                                closeScanner()
                            }
                            .accessibilityIdentifier("page.scanning.dismiss")
                        }
                        .axisBehavior(.verticalPreferred)
                    } else {
                        ToolbarItem(placement: .automatic) {
                            Button(role: .close) {
                                closeScanner()
                            }
                            .accessibilityIdentifier("page.scanning.dismiss")
                        }
                    }
                }
        } else {
            manualEntry()
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
    NavigationStack {
        BarcodeScanner(isPresented: true, onScanned: { _,_ in }) {
            ManualEntryView(onSubmit: { _,_ in })
        }
    }
}
