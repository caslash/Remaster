import SwiftUI

struct ManualEntryView: View {
    var isSearching: Binding<Bool>
    let onSubmit: (String) -> Void
    
    @State private var searchText: String = ""
    
    var body: some View {
        VStack { }
            .alert("Search a UPC", isPresented: isSearching) {
                TextField("UPC", text: $searchText)
                
                Button("OK") {
                    self.onSubmit(searchText)
                }
            }
    }
}

#Preview {
    ManualEntryView(isSearching: Binding.constant(true), onSubmit: { string in
        print(string)
    })
}
