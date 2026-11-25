//
//  LibraryView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/12/26.
//

import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: LibraryViewModel
    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var items: [LibraryItem]
    
    @State private var selection: LibraryItem? = nil
    
    var body: some View {
        if hSizeClass == .regular {
            NavigationSplitView {
                LibraryGrid(items: items, selection: $selection, getPoster: self.viewModel.getPoster, onDelete: self.viewModel.deleteItem)
                    .alert(error: self.$viewModel.error) {
                        Button("OK") { }
                    }
                    .navigationTitle("Library")
                
            } detail: {
                if let selection {
                    LibraryItemDetailView(item: selection) {
                        self.selection = nil
                    }
                    .id(selection.persistentModelID)
                } else {
                    ContentUnavailableView("Select an Item", systemImage: "opticaldisc")
                }
            }
        } else {
            NavigationStack {
                LibraryGrid(items: items, selection: $selection, getPoster: self.viewModel.getPoster, onDelete: self.viewModel.deleteItem)
                    .alert(error: self.$viewModel.error) {
                        Button("OK") { }
                    }
                    .navigationTitle("Library")
                    .navigationDestination(item: $selection) { item in
                        LibraryItemDetailView(item: item) {
                            self.selection = nil
                        }
                    }
            }
        }
    }
    
    init() {
        self.viewModel = LibraryViewModel()
    }
    
    private struct LibraryGrid: View {
        let items: [LibraryItem]
        @Binding var selection: LibraryItem?
        let getPoster: (PersistentIdentifier) async -> UIImage?
        var onDelete: (LibraryItem) -> Void
        
        
        var body: some View {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: LibraryCardView.POSTER_WIDTH), spacing: 16)], spacing: 16) {
                    ForEach(items, id: \.id) { item in
                        Button { self.selection = item } label: {
                            LibraryCardView(item: item, getPoster: getPoster)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            self.onDelete(item)
                                            self.selection = nil
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("page.library.card")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#if DEBUG
#Preview(traits: .modifier(PreviewLibraryItems())) {
    LibraryView()
}
#endif
