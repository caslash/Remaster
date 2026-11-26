//
//  TitleSearchView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import SwiftUI

struct TitleSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TitleSearchViewModel
    @FocusState private var isSearchFocused
    
    let searchType: TitleSearchType
    
    var body: some View {
        List {
            Section {
                UnmatchedDiscCard(searchType: searchType)
            }
            .padding(14)
            .listRowInsets(EdgeInsets())
            
            Section {
                SearchTextField(titleKey: "Search for a title", searchText: $viewModel.query, isFocused: $isSearchFocused)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            Section {
                listContent
            } header: {
                Text("Results")
                    .textCase(.uppercase)
                    .font(.footnote.weight(.regular))
            } footer: {
                Text(searchType.footerText)
            }
        }
        .contentMargins(.top, 0)
        .listSectionSpacing(12)
        .navigationTitle(searchType.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .close) {
                    dismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView("Find a title", image: "magnifyingglass", description: Text("Start typing to search."))
        case .loading:
            ProgressView()
        case .waitingToRetry(let until, _):
            ContentUnavailableView {
                Label("Server is busy", systemImage: "hourglass")
            } description: {
                Text("Retrying in \(Text(timerInterval: Date.now...until, countsDown: true))")
            } actions: {
                Button("Retry now") { viewModel.retry() }
            }
        case .results(let titles):
            ForEach(titles) { title in
                TitleSearchCard(title: title)
            }
        case .noMatches(let query):
            ContentUnavailableView.search(text: query)
        case .failed(let error):
            ContentUnavailableView {
                Label("Search failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try again") { viewModel.retry() }
            }
        }
    }
    
    init(searchType: TitleSearchType) {
        self.viewModel = TitleSearchViewModel()
        self.searchType = searchType
    }
}

#Preview("Barcode Not Found") {
    NavigationStack {
        TitleSearchView(searchType: .barcodeNotFound(upc: "043396648654"))
    }
}

#Preview("Title Not Confirmed") {
    NavigationStack {
        TitleSearchView(searchType: .titleNotConfirmed(upc: "043396648654"))
    }
}
