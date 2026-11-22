//
//  ConfirmView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/19/26.
//

import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct ConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ConfirmViewModel
    
    let onSuccess: (LibraryItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                EditionSummaryCard(edition: viewModel.edition, titleNotConfirmed: viewModel.titleNotConfirmed, someDetailsMissing: viewModel.someDetailsMissing)
                    .confirmationDialog(viewModel.libraryError?.errorDescription ?? "", isPresented: $viewModel.isDuplicate, titleVisibility: .visible, presenting: viewModel.libraryError) { error in
                        Button(error == .duplicate ? "Add Another Copy" : "Add as Another Copy") { viewModel.saveToLibrary(isRetry: true) }
                        Button("Cancel", role: .cancel) {}
                    } message: { error in
                        Text(error.recoverySuggestion ?? "")
                    }
                
                Section {
                    Picker("Format You Own", selection: $viewModel.discFormat) {
                        ForEach(DiscFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("page.confirm.format")
                } header: {
                    Text("Format you own")
                        .textCase(.uppercase)
                        .font(.footnote.weight(.regular))
                }
                
                Section {
                    if let secondFormat = viewModel.secondFormatName, viewModel.selectedFormatIncludedAndHasLeftover {
                        Toggle(isOn: $viewModel.includesOtherFormats) {
                            Text("Also includes \(secondFormat)")
                            Text("Combo pack - you own both formats")
                        }
                    }
                    
                    LabeledContent("HDR", value: viewModel.hdrFormats)
                    
                    LabeledContent("Edition", value: viewModel.editionText)
                } footer: {
                    Text("Details come from the barcode. You can change them later.")
                }
            }
            .navigationTitle("Is this right?")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaBar(edge: .bottom) {
                VStack {
                    Button("Add to Library") {
                        viewModel.saveToLibrary()
                    }
                    .disabled(viewModel.discFormat == nil || viewModel.isSaving)
                    .padding()
                    .fontWeight(.heavy)
                    .buttonSizing(.flexible)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("page.confirm.add")
                    
                    Button("Not this title? Search instead") {
                        
                    }
                    .accessibilityIdentifier("page.confirm.notThis")
                }
                .safeAreaPadding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .alert(error: $viewModel.error) {
                Button("OK") { }
            }
            .onChange(of: viewModel.savedItem) { _, savedItem in
                if let savedItem {
                    dismiss()
                    onSuccess(savedItem)
                }
            }
        }
    }
    
    init(edition: Edition, onSuccess: @escaping (LibraryItem) -> Void) {
        self.viewModel = ConfirmViewModel(edition: edition)
        self.onSuccess = onSuccess
    }
}

#if DEBUG && canImport(Vision)
#Preview {
    @Previewable @State var edition: Edition?
    
    Group {
        if let edition {
            ConfirmView(edition: edition) { _ in }
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
#endif
