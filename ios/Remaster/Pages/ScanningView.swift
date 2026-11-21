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
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ScanningViewModel = .init()
    
    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeScanner(symbologies: [.ean13, .upce, .ean8], isPresented: viewModel.isIdle, onScanned: viewModel.processBarcode) {
                    ManualEntryView(isEnabled: viewModel.isIdle, onSubmit: viewModel.processBarcode)
                }
                .alert(error: $viewModel.error) {
                    Button("OK", role: .close) {  }
                        .accessibilityIdentifier("page.scanning.alert.ok")
                }
                .alert(error: $viewModel.networkError) { error in
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
                    ConfirmView(edition: edition)
                }
                
                if (viewModel.isFetching) {
                    ProgressView()
                        .accessibilityIdentifier("page.scanning.progress")
                }
            }
            .toolbar {
                if #available(anyAppleOS 27.1, *) {
                    ToolbarItem(placement: .automatic) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                        .accessibilityIdentifier("page.scanning.dismiss")
                    }
                    .axisBehavior(.verticalPreferred)
                } else {
                    ToolbarItem(placement: .automatic) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                        .accessibilityIdentifier("page.scanning.dismiss")
                    }
                }
            }
        }
    }
}

#Preview {
    ScanningView()
}
