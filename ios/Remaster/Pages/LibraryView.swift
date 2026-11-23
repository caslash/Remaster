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
            List {
                ForEach(items) { item in
                    if let edition = item.edition {
                        Text(edition.upcTitle)
                    }
                }
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView()
}
