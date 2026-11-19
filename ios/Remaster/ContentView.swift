//
//  ContentView.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import SwiftUI

enum RemasterTab: String, Hashable {
    case library, upgrades, watchlist, settings, scanner
}

struct ContentView: View {
    @State private var selection: RemasterTab = .library
    @State private var lastSelection: RemasterTab = .library
    @State private var isScannerPresented = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Library", systemImage: "books.vertical", value: .library) {
                LibraryView()
            }
            .accessibilityIdentifier("tab.library")
            
            Tab("Upgrades", systemImage: "arrow.up.circle", value: .upgrades) {
                UpgradesView()
            }
            .badge(0)
            .accessibilityIdentifier("tab.upgrades")
            
            Tab("Watchlist", systemImage: "bell", value: .watchlist) {
                WatchlistView()
            }
            .accessibilityIdentifier("tab.watchlist")
            
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
            .accessibilityIdentifier("tab.settings")
            
            Tab("Scan", systemImage: "barcode.viewfinder", value: .scanner, role: .prominent) {
                Color.clear
            }
        }
        .fullScreenCover(isPresented: $isScannerPresented, onDismiss: {
            selection = lastSelection
        }) {
            ScanningView()
        }
        .onChange(of: selection) {oldValue, newValue in
            if (newValue == .scanner) {
                lastSelection = oldValue
                isScannerPresented = true
            }
        }
    }
}

#Preview {
    ContentView()
}
