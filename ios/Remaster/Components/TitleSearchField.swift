//
//  TitleSearchField.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import SwiftUI

struct TitleSearchField: View {
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search for a title", text: $searchText)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("page.titleSearch.field")
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("page.titleSearch.clear")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.fill.tertiary, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isSearchField)
    }
}

#Preview {
    @Previewable @FocusState var focused: Bool
    TitleSearchField(searchText: .constant(""), isFocused: $focused)
}
