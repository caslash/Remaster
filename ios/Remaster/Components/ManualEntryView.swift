import SwiftUI
import Vision

struct ManualEntryView: View {
    let isPresented: Bool
    let onSubmit: (String, VNBarcodeSymbology?) -> Void
    
    @State private var searchText: String = ""
    
    var body: some View {
        VStack { }
            .alert("Search a UPC", isPresented: Binding(get: { isPresented }, set: { _ in })) {
                TextField("UPC", text: $searchText)
                
                Button("OK") {
                    self.onSubmit(searchText, nil)
                    searchText = ""
                }
            }
    }
}

#Preview {
    ManualEntryView(isPresented: true, onSubmit: { string, _ in
        print(string)
    })
}
