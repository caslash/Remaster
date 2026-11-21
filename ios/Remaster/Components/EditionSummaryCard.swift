//
//  EditionSummaryCard.swift
//  Remaster
//
//  Created by Cameron Slash on 11/19/26.
//

import SwiftUI
import Vision

struct EditionSummaryCard: View {
    @State var edition: Edition

    var body: some View {
        HStack {
            AsyncImage(url: edition.title?.posterURL){ phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else if phase.error != nil {
                    
                } else {
                    ProgressView()
                }
            }
            .frame(height: 114)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            VStack {
                Text(edition.upcTitle)
                    .font(.title2)
                    .fontWeight(.heavy)
                
                EditionSubtitleView(edition: edition)
                
                Text("UPC \(edition.barcodes.upc ?? "")")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

private struct EditionSubtitleView: View {
    @State var edition: Edition
    
    var body: some View {
        HStack(spacing: 2) {
            if let kind = edition.kind {
                Text(kind.displayName)
            }
            
            if let year = edition.year {
                Text("·")
                
                Text(year, format: .number.grouping(.never))
            }
            
            if let distributor = edition.distributor {
                Text("·")
                
                Text(distributor)
            }
        }
        .font(.caption.weight(.regular))
        .foregroundStyle(.secondary)
    }
}

#Preview {
    @Previewable @State var edition: Edition?
    
    Group {
        if let edition {
            Form {
                EditionSummaryCard(edition: edition)
            }
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
