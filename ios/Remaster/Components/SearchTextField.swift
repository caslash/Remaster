//
//  SearchTextField.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import SwiftUI

struct SearchTextField: View {
    var titleKey: String
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField(titleKey, text: $searchText)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
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
    SearchTextField(titleKey: "Search for a title", searchText: .constant(""), isFocused: $focused)
}
