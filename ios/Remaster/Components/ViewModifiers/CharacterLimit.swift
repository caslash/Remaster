//
//  CharacterLimit.swift
//  Remaster
//
//  Created by Cameron Slash on 11/26/26.
//

import SwiftUI

struct CharacterLimitModifier: ViewModifier {
    @Binding var text: String
    let limit: Int

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, newValue in
                if newValue.count > limit {
                    text = String(newValue.prefix(limit))
                }
            }
    }
}

extension View {
    func limitCharacters(_ text: Binding<String>, to limit: Int) -> some View {
        modifier(CharacterLimitModifier(text: text, limit: limit))
    }
}
