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
    let onSelect: (Title) -> Void
    
    var body: some View {
        List {
            if let _ = searchType.upc {
                Section {
                    UnmatchedDiscCard(searchType: searchType)
                }
                .padding(14)
                .listRowInsets(EdgeInsets())
            }
            
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
        .navigationBarBackButtonHidden()
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
            ContentUnavailableView("Find a title", systemImage: "magnifyingglass", description: Text("Start typing to search."))
        case .loading:
            ProgressView()
        case .waitingToRetry(let until, _):
            ContentUnavailableView {
                Label("Search is busy", systemImage: "hourglass")
            } description: {
                Text("Retrying in \(Text(timerInterval: Date.now...until, countsDown: true))")
            } actions: {
                Button("Retry now") { viewModel.retry() }
            }
        case .results(let titles):
            ForEach(titles) { title in
                Button {
                    onSelect(title)
                    dismiss()
                } label: {
                    TitleSearchCard(title: title)
                }
                .buttonStyle(.plain)
            }
        case .noMatches(let query):
            ContentUnavailableView.search(text: query)
        case .failed(let error):
            ContentUnavailableView {
                Label(error.errorDescription ?? "Search failed", systemImage: "exclamationmark.triangle")
            } description: {
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                }
            } actions: {
                if (error.isRetryable) {
                    Button("Try again") { viewModel.retry() }
                }
            }
        }
    }
    
    init(searchType: TitleSearchType, onSelect: @escaping (Title) -> Void) {
        self.viewModel = TitleSearchViewModel(searchType: searchType)
        self.searchType = searchType
        self.onSelect = onSelect
    }
}

#Preview("Barcode Not Found") {
    NavigationStack {
        TitleSearchView(searchType: .barcodeNotFound(upc: "043396648654")) { _ in }
    }
}

#Preview("Title Not Confirmed") {
    NavigationStack {
        TitleSearchView(searchType: .titleNotConfirmed(upc: "043396648654", prefillQuery: "Hoppers")) { _ in }
    }
}
