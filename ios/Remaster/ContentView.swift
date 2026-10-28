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
    
    var body: some View {
        BarcodeScanner(onScanned: fetchBarcode)
            .sheet(item: self.$viewModel.edition) { edition in
                ScrollView([.vertical]) {
                    Text(String(describing: edition))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .alert(error: self.$viewModel.error) { 
                Button("OK", role: .close) { }
            }
    }

    private func fetchBarcode(barcode: String) {
        Task {
            await self.viewModel.processBarcode(barcode: barcode)
        }
    }
}

#Preview {
    ContentView()
}
