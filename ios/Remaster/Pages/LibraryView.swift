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
    @State private var viewModel: LibraryViewModel
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var items: [LibraryItem]
    
    @State private var selection: LibraryItem? = nil
    
    var body: some View {
        if hSizeClass == .regular {
            NavigationSplitView {
                LibraryGrid(items: items, selection: $selection, onDelete: self.viewModel.deleteItem)
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
                LibraryGrid(items: items, selection: $selection, onDelete: self.viewModel.deleteItem)
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
        
        var onDelete: (LibraryItem) -> Void
        
        var body: some View {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: LibraryCardView.POSTER_WIDTH), spacing: 16)], spacing: 16) {
                    ForEach(items, id: \.id) { item in
                        Button { self.selection = item } label: {
                            LibraryCardView(item: item)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            self.onDelete(item)
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
