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
    @Environment(\.openScanner) private var openScanner
    
    @State private var viewModel: LibraryViewModel
    @State private var selection: LibraryItem? = nil
    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var items: [LibraryItem]
    
    var body: some View {
        if hSizeClass == .regular {
            NavigationSplitView {
                libraryContent
                    .navigationTitle("Library")
                    .alert(error: self.$viewModel.error) {
                        Button("OK") { }
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Add new", systemImage: "plus") {
                                self.openScanner()
                            }
                        }
                    }
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
                libraryContent
                    .background(Color(.secondarySystemBackground))
                    .navigationTitle("Library")
                    .navigationDestination(item: $selection) { item in
                        LibraryItemDetailView(item: item) {
                            self.selection = nil
                        }
                    }
                    .alert(error: self.$viewModel.error) {
                        Button("OK") { }
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Add new", systemImage: "plus") {
                                self.openScanner()
                            }
                        }
                    }
            }
        }
    }
    
    init() {
        self.viewModel = LibraryViewModel()
    }
    
    @ViewBuilder
    private var libraryContent: some View {
        if items.isEmpty {
            VStack(spacing: 18) {
                Image(systemName: "barcode.viewfinder")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.secondary)
                
                Text("Start your library")
                    .font(.title2.bold())
                
                Text("Scan the barcode on each case and we'll identify the release and tell you when a better version exists.")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
                
                VStack(spacing: 12) {
                    Button {
                        self.openScanner()
                    } label: {
                        Label("Scan a Shelf", systemImage: "barcode.viewfinder")
                    }
                    .fontWeight(.heavy)
                    .buttonSizing(.flexible)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Search by Title") {
                        
                    }
                    .fontWeight(.heavy)
                    .buttonSizing(.flexible)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock")
                        .foregroundStyle(.blue)
                    
                    Text("No account needed. Your library is stored only on this iPhone")
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.top)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LibraryGrid(items: items, selection: $selection, onDelete: self.viewModel.deleteItem)
        }
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
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.secondarySystemBackground)))
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

#Preview("Empty State") {
    LibraryView()
}

#if DEBUG
#Preview(traits: .modifier(PreviewLibraryItems())) {
    LibraryView()
}
#endif
