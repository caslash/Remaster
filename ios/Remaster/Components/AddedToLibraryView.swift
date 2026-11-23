//
//  AddedToLibraryView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/22/26.
//

import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct AddedToLibraryView: View {
    let libraryItem: LibraryItem
    let saveType: SaveType
    
    var detail: String? {
        guard let edition = libraryItem.edition, let ownedFormats = libraryItem.ownedFormats else { return nil }
        
        return "\(edition.upcTitle) · \(ownedFormats.joined(separator: " + "))"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading) {
                Text(saveType == .new ? "Added to Library" : "Updated your copy")
                    .font(.subheadline.bold())
                
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThickMaterial)
                .shadow(radius: 30, y: 10)
        )
        .safeAreaPadding()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("banner.added")
    }
}

#if DEBUG && canImport(Vision)
#Preview {
    @Previewable @State var edition: Edition?
    
    var item: LibraryItem? {
        return .init(upc: edition?.barcodes.upc, ean: edition?.barcodes.ean, kind: edition?.title?.kind.rawValue, tmdbId: edition?.title?.tmdbId, ownedFormats: edition?.discContents?.map { $0.format.rawValue }, edition: edition)
    }
    
    Group {
        if let item {
            AddedToLibraryView(libraryItem: item, saveType: .new)
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
#endif
