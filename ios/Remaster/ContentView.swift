//
//  ContentView.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import Observation
import SwiftUI
import Vision

struct ContentView: View {
    @State private var viewModel: ContentViewModel = .init()
    
    var body: some View {
        ZStack {
            BarcodeScanner(symbologies: [.ean13, .upce, .ean8], isPresented: self.viewModel.isIdle, onScanned: self.viewModel.processBarcode)
                .alert(error: self.$viewModel.error) {
                    Button("OK", role: .close) {  }
                }
                .alert(error: self.$viewModel.networkError) { error in
                    if (error.isRetryable) {
                        Button("Retry") {
                            self.viewModel.retry()
                        }
                    }
                    
                    Button("OK", role: .close) {  }
                } message: { error in
                    Text(error.recoverySuggestion ?? "")
                }
                .sheet(item: self.$viewModel.edition) { edition in
                    VStack {
                        AsyncImage(url: edition.coverImageURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                            } else if phase.error != nil {
                                
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(height: 200)
                        .accessibilityIdentifier("sheet.edition.coverImage")
                        
                        Text(edition.title)
                            .font(.title2)
                            .accessibilityIdentifier("sheet.edition.title")
                        
                        Text(edition.format?.rawValue ?? "Unknown Format")
                            .font(.subheadline)
                            .accessibilityIdentifier("sheet.edition.format")
                    }
                }
            
            if (self.viewModel.isFetching) {
                ProgressView()
            }
        }
    }
}

#Preview {
    ContentView()
}
