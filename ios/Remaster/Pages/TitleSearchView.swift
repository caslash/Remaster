//
//  TitleSearchView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import SwiftUI

struct TitleSearchView: View {
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
                TitleSearchField(searchText: $viewModel.query, isFocused: $isSearchFocused)
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
    }
    
    @ViewBuilder
    private var listContent: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView("Find a title", systemImage: "magnifyingglass", description: Text("Start typing to search."))
                .accessibilityIdentifier("page.titleSearch.idle")
        case .loading:
            ProgressView()
                .accessibilityIdentifier("page.titleSearch.progress")
        case .waitingToRetry(let until, _):
            ContentUnavailableView {
                Label("Search is busy", systemImage: "hourglass")
                    .accessibilityIdentifier("page.titleSearch.busy")
            } description: {
                Text("Retrying in \(Text(timerInterval: Date.now...until, countsDown: true))")
            } actions: {
                Button("Retry now") { viewModel.retry() }
                    .accessibilityIdentifier("page.titleSearch.retryNow")
            }
        case .results(let titles):
            ForEach(titles) { title in
                Button {
                    onSelect(title)
                } label: {
                    TitleSearchCard(title: title)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("page.titleSearch.result")
            }
        case .noMatches:
            ContentUnavailableView {
                Label("No Matches", systemImage: "exclamationmark")
                    .accessibilityIdentifier("page.titleSearch.noMatches")
            } description: {
                Text("Check the spelling, try fewer words, or search for the original title if it came out under another name.")
            }
        case .failed(let error):
            ContentUnavailableView {
                Label(error.errorDescription ?? "Search failed", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("page.titleSearch.error.title")
            } description: {
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .accessibilityIdentifier("page.titleSearch.error.message")
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
        TitleSearchView(searchType: .addTitle(upc: "043396648654")) { _ in }
    }
}

#Preview("Title Not Confirmed") {
    NavigationStack {
        TitleSearchView(searchType: .titleNotConfirmed(upc: "043396648654", prefillQuery: "Hoppers")) { _ in }
    }
}
