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
    
    var body: some View {
        List {
            Section {
                UnmatchedDiscCard(searchType: viewModel.searchType)
            }
            .padding(14)
            .listRowInsets(EdgeInsets())
            
            Section {
                SearchTextField(titleKey: "Search for a title", searchText: $viewModel.searchText, isFocused: $isSearchFocused)
                    .onSubmit {
                        Task {
                            await viewModel.searchTitle()
                        }
                    }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            Section {
                if viewModel.searchState == .idle || viewModel.searchState == .empty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else if viewModel.searchState == .loading {
                    ProgressView()
                } else {
                    ForEach(viewModel.results) { item in
                        TitleSearchCard(title: item)
                    }
                }
            } header: {
                Text("Results")
                    .textCase(.uppercase)
                    .font(.footnote.weight(.regular))
            } footer: {
                Text(viewModel.searchType.footerText)
            }
        }
        .contentMargins(.top, 0)
        .listSectionSpacing(12)
        .task(id: viewModel.searchText) {
            let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty && trimmed.count > 2 else {
                self.viewModel.clearResults()
                return
            }
            
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            await viewModel.searchTitle()
        }
        .navigationTitle(viewModel.searchType.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(error: $viewModel.error) {
            Button("OK", role: .close) { }
        }
        .alert(error: $viewModel.networkError) { error in
            if (error.isRetryable) {
                Button("Retry") {
                    Task {
                        await viewModel.searchTitle()
                    }
                }
            }
            
            Button("OK", role: .close) { }
        } message: { error in
            Text(error.recoverySuggestion ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .close) {
                    dismiss()
                }
            }
        }
    }
    
    init(searchType: TitleSearchType) {
        self.viewModel = TitleSearchViewModel(searchType: searchType)
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
