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

    var body: some View {
        NavigationStack {
            Form {
                EditionSummaryCard(edition: viewModel.edition, titleNotConfirmed: viewModel.titleNotConfirmed, someDetailsMissing: viewModel.someDetailsMissing)
                
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
            .confirmationDialog(viewModel.libraryError?.errorDescription ?? "", isPresented: $viewModel.isDuplicate, presenting: viewModel.libraryError) { error in
                Button(error == .duplicate ? "Add Another Copy" : "Add as Another Copy") { viewModel.saveToLibrary(isRetry: true) }
                Button("Cancel", role: .cancel) {}
            } message: { error in
                Text(error.recoverySuggestion ?? "")
            }
            .alert(error: $viewModel.error) {
                Button("OK") { }
            }
            .onChange(of: viewModel.saved) { _, saved in
                if saved {
                    dismiss()
                }
            }
        }
    }
    
    init(edition: Edition) {
        self.viewModel = ConfirmViewModel(edition: edition)
    }
}

#if DEBUG && canImport(Vision)
#Preview {
    @Previewable @State var edition: Edition?
    
    Group {
        if let edition {
            ConfirmView(edition: edition)
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
#endif
