//
//  ContentView.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import SwiftUI
import PopupView

#if DEBUG && canImport(Vision)
import Vision
#endif

enum RemasterTab: String, Hashable {
    case library, upgrades, watchlist, settings, scanner
}

struct ContentView: View {
    @State private var selection: RemasterTab = .library
    @State private var lastSelection: RemasterTab = .library
    @State private var isScannerPresented = false
    
    @State private var newestLibraryItem: LibraryItem?
    @State private var newestLibraryItemType: SaveType

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
        .popup(item: $newestLibraryItem) { item in
            AddedToLibraryView(libraryItem: item, saveType: newestLibraryItemType)
        } customize: {
            $0
                .type(.floater())
                .position(.top)
                .animation(.spring)
        }
        .fullScreenCover(isPresented: $isScannerPresented, onDismiss: {
            selection = lastSelection
        }) {
            ScanningView() { item, saveType in
                isScannerPresented = false
                self.newestLibraryItem = item
                self.newestLibraryItemType = saveType
            }
        }
        .onChange(of: selection) {oldValue, newValue in
            if (newValue == .scanner) {
                lastSelection = oldValue
                isScannerPresented = true
            }
        }
    }
    
    init(libraryItem: LibraryItem? = nil) {
        self._newestLibraryItem = State(initialValue: libraryItem)
        self._newestLibraryItemType = State(initialValue: .new)
    }
}

#if DEBUG && canImport(Vision)
#Preview {
    @Previewable @State var edition: Edition?
    
    var item: LibraryItem? {
        return .init(upc: edition?.barcodes.upc, ean: edition?.barcodes.ean, kind: edition?.title?.kind.rawValue, tmdbId: edition?.title?.tmdbId, ownedFormats: edition?.discContents?.map { $0.format.rawValue }, edition: edition)
    }
    
    Group {
        if let item, edition != nil {
            ContentView(libraryItem: item)
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
#endif
