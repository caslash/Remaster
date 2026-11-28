//
//  ToolbarCloseButton.swift
//  Remaster
//
//  Created by Cameron Slash on 11/27/26.
//

import SwiftUI

struct ToolbarCloseButton: ToolbarContent {
    var accessibilityIdentifier: String
    var closeAction: () -> Void
    
    var body: some ToolbarContent {
        if #available(anyAppleOS 27.1, *) {
            ToolbarItem(placement: .automatic) {
                Button(role: .close) {
                    closeAction()
                }
                .accessibilityIdentifier(accessibilityIdentifier)
            }
            .axisBehavior(.verticalPreferred)
        } else {
            ToolbarItem(placement: .automatic) {
                Button(role: .close) {
                    closeAction()
                }
                .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .toolbar {
                ToolbarCloseButton(accessibilityIdentifier: "preview.dismiss") { }
            }
    }
}
