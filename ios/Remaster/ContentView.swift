//
//  ContentView.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import Observation
import SwiftUI

struct ContentView: View {
    @State private var viewModel: ContentViewModel = .init()
    
    private var isSearching: Binding<Bool> {
        Binding(
            get: { viewModel.edition == nil && viewModel.error == nil },
            set: { _ in }
        )
    }
    
    var body: some View {
        BarcodeScanner(isSearching: self.isSearching, onScanned: fetchBarcode)
            .sheet(item: self.$viewModel.edition) { edition in
                VStack {
                    AsyncImage(url: edition.coverImageURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                        .frame(height: 200)
                    
                    Text(edition.title)
                        .font(.title2)
                    
                    Text(edition.format?.rawValue ?? "Unknown Format")
                        .font(.subheadline)
                }
            }
            .alert(error: self.$viewModel.error) { 
                Button("OK", role: .close) { }
            }
    }

    private func fetchBarcode(_ barcode: String) {
        Task {
            await self.viewModel.processBarcode(barcode)
        }
    }
}

#Preview {
    ContentView()
}
