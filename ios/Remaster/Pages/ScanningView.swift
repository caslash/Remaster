//
//  ScanningView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/12/26.
//

import Observation
import SwiftUI
import Vision

struct ScanningView: View {
    @State private var viewModel: ScanningViewModel = .init()
    @State private var isManualLookup = false
    
    let onSuccess: (LibraryItem, SaveType) -> Void
    
    var body: some View {
        NavigationStack {
            BarcodeScanner(
                symbologies: [.ean13, .upce, .ean8],
                isPresented: viewModel.isIdle,
                onScanned: { barcode, symbology in
                    isManualLookup = false
                    viewModel.processBarcode(barcode, shape: symbology)
                }
            ) {
                manualEntry
            }
            .navigationBarBackButtonHidden()
            .overlay {
                if (viewModel.isFetching && !isManualLookup) {
                    ProgressView()
                        .accessibilityIdentifier("page.scanning.progress")
                }
            }
            .alert(error: scanOnly($viewModel.error)) {
                Button("OK", role: .close) {  }
                    .accessibilityIdentifier("page.scanning.alert.ok")
            }
            .alert(error: scanOnly($viewModel.networkError)) { error in
                if (error.isRetryable) {
                    Button("Retry") {
                        viewModel.retry()
                    }
                    .accessibilityIdentifier("page.scanning.alert.retry")
                }
                
                Button("OK", role: .close) {  }
                    .accessibilityIdentifier("page.scanning.alert.ok")
            } message: { error in
                Text(error.recoverySuggestion ?? "")
                    .accessibilityIdentifier("page.scanning.alert.message")
            }
            .sheet(item: $viewModel.edition) { edition in
                ConfirmView(edition: edition, onSuccess: onSuccess)
            }
        }
    }
    
    private var manualEntry: some View {
        ManualEntryView(
            isFetching: isManualLookup && viewModel.isFetching,
            error: isManualLookup ? (viewModel.networkError ?? viewModel.error) : nil
        ) { barcode, symbology in
            isManualLookup = true
            viewModel.processBarcode(barcode, shape: symbology)
        }
    }
    
    private func scanOnly<Failure>(_ error: Binding<Failure?>) -> Binding<Failure?> {
        Binding(
            get: { isManualLookup ? nil : error.wrappedValue },
            set: { error.wrappedValue = $0 }
        )
    }
    
    private func manualEntryDismissed() {
        viewModel.networkError = nil
        viewModel.error = nil
        isManualLookup = false
    }
}

#Preview {
    ScanningView() { _, _ in }
}
