import SwiftUI
import Vision

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var upc: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var isFetching: Bool = false
    var error: (any Error)?
    let onSubmit: (String, VNBarcodeSymbology?) -> Void
    
    private var errorTitle: String? {
        guard let error else { return nil }
        return (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
    }
    
    private var errorSuggestion: String? {
        (error as? any LocalizedError)?.recoverySuggestion
    }
    
    var body: some View {
        Form {
            Section {
                BarcodeTextField(searchText: $upc, isFocused: $isSearchFocused)
                    .disabled(isFetching)
            } header: {
                Text("Barcode Number")
                    .textCase(.uppercase)
                    .font(.footnote)
            } footer: {
                if let errorTitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(errorTitle, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("page.scanning.manualEntry.error")
                        
                        if let errorSuggestion {
                            Text(errorSuggestion)
                                .font(.footnote)
                                .accessibilityIdentifier("page.scanning.manualEntry.error.suggestion")
                        }
                    }
                } else {
                    Text("Digits only, no spaces or dashes")
                        .font(.footnote)
                }
            }
            
            Button {
                isSearchFocused = false
                onSubmit(upc, nil)
            } label: {
                if isFetching {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Looking Up…")
                    }
                } else {
                    Text("Look Up")
                }
            }
            .fontWeight(.bold)
            .buttonSizing(.flexible)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .disabled(upc.isEmpty || isFetching)
            .accessibilityIdentifier("page.scanning.manualEntry.search")
            
            Section {
                HStack {
                    Image(.barcodeExample)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 72)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Type the numbers under the bars")
                            .font(.subheadline.bold())
                            .multilineTextAlignment(.leading)
                        
                        Text("They're on the back of the case. Most discs have a 12-digit UPC or a 13-digit EAN; small labels have 8.")
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Only the barcode number is sent to look up the disc.")
                    .font(.footnote)
            }
        }
        .onChange(of: isFetching) { _, isFetching in
            if !isFetching && error == nil {
                upc = ""
            }
        }
        .navigationTitle("Enter Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            if #available(anyAppleOS 27.1, *) {
                ToolbarItem(placement: .automatic) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .accessibilityIdentifier("page.scanning.manualEntry.dismiss")
                }
                .axisBehavior(.verticalPreferred)
            } else {
                ToolbarItem(placement: .automatic) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .accessibilityIdentifier("page.scanning.manualEntry.dismiss")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
    }
    .sheet(isPresented: .constant(true)) {
        NavigationStack {
            ManualEntryView(onSubmit: { string, _ in
                print(string)
            })
        }
    }
}
