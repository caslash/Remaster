//
//  LibraryView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/12/26.
//

import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LibraryItem.dateAdded, order: .reverse) private var items: [LibraryItem]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 111), spacing: 16)], spacing: 16) {
                    ForEach(items, id: \.id) { item in
                        if let edition = item.edition {
                            LibraryCardView(edition: edition, formats: item.ownedFormats?.unique())
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            do {
                                                self.modelContext.delete(item)
                                                try self.modelContext.save()
                                            } catch {
                                                print(error)
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Library")
        }
    }
}

#if DEBUG
#Preview(traits: .modifier(PreviewLibraryItems())) {
    LibraryView()
}
#endif
