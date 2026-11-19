import SwiftUI
import Vision

struct ManualEntryView: View {
    let isEnabled: Bool
    let onSubmit: (String, VNBarcodeSymbology?) -> Void
    
    @State private var upc: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            TextField("Search a UPC", text: $upc)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .accessibilityIdentifier("page.scanning.manualEntry.field")
            
            Button("Search") {
                onSubmit(upc, nil)
                upc = ""
                isFocused = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(upc.isEmpty)
            .accessibilityIdentifier("page.scanning.manualEntry.search")
        }
        .disabled(!isEnabled)
        .padding()
    }
}

#Preview {
    ManualEntryView(isEnabled: true, onSubmit: { string, _ in
        print(string)
    })
}
