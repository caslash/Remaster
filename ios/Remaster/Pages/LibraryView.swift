//
//  LibraryView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/12/26.
//

import SwiftData
import SwiftUI

struct LibraryView: View {
    @State private var viewModel: LibraryViewModel
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var items: [LibraryItem]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: LibraryCardView.POSTER_WIDTH), spacing: 16)], spacing: 16) {
                    ForEach(items, id: \.id) { item in
                        LibraryCardView(item: item)
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        self.viewModel.deleteItem(item)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Library")
        }
    }
    
    init() {
        self.viewModel = LibraryViewModel()
    }
}

#if DEBUG
#Preview(traits: .modifier(PreviewLibraryItems())) {
    LibraryView()
}
#endif
