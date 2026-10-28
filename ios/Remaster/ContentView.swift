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
        BarcodeScanner { do { try self.viewModel.processBarcode(barcode: $0) } catch { fatalError() }  }
            .sheet(isPresented: self.isShowingMovie) {
                ScrollView([.vertical]) {
                    Text(String(describing: self.viewModel.edition))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
    }

    /// Presents the sheet while a response is loaded, and clears it when the sheet is dismissed.
    private var isShowingMovie: Binding<Bool> {
        Binding(
            get: { self.viewModel.edition != nil },
            set: { if !$0 { self.viewModel.edition = nil } }
        )
    }
}

#Preview {
    ContentView()
}
