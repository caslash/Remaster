//
//  BarcodeTextField.swift
//  Remaster
//
//  Created by Cameron Slash on 11/26/26.
//

import SwiftUI

struct BarcodeTextField: View {
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack {
            TextField("12 or 13 digits", text: $searchText)
                .font(.title.weight(.medium))
                .kerning(1.5)
                .keyboardType(.numberPad)
                .focused(isFocused)
                .limitCharacters($searchText, to: 13)
                .accessibilityIdentifier("page.scanning.manualEntry.field")
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear barcode")
                .accessibilityIdentifier("page.scanning.manualEntry.clear")
            }
        }
        .background(Color.clear)
    }
}

#Preview {
    @Previewable @FocusState var focused: Bool
    BarcodeTextField(searchText: .constant(""), isFocused: $focused)
}
