//
//  PosterFallbackImage.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct PosterFallbackImage: View {
    let item: LibraryItem?
    
    @ViewBuilder
    var fallbackPoster: some View {
        if let item, let title = item.displayTitle {
            Text(title)
                .multilineTextAlignment(.center)
                .truncationMode(.tail)
        } else {
            VStack {
                Image(systemName: "opticaldisc")
                    .resizable()
                    .frame(width: 30, height: 30)
                
                Text("No cover")
                    .font(.caption.bold())
            }
        }
    }

    var body: some View {
        fallbackPoster
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGray3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    init(item: LibraryItem? = nil) {
        self.item = item
    }
}

#Preview("Without Item") {
    PosterFallbackImage()
        .frame(width: LibraryCardView.POSTER_WIDTH, height: (LibraryCardView.POSTER_WIDTH*3)/2)
}

#if DEBUG && canImport(Vision)
#Preview("With Item") {
    @Previewable @State var edition: Edition?
    
    var item: LibraryItem? {
        return .init(upc: edition?.barcodes.upc, ean: edition?.barcodes.ean, kind: edition?.title?.kind.rawValue, tmdbId: edition?.title?.tmdbId, ownedFormats: edition?.discContents?.map { $0.format.rawValue }, edition: edition)
    }
    
    Group {
        if let item {
            PosterFallbackImage(item: item)
                .frame(width: LibraryCardView.POSTER_WIDTH, height: (LibraryCardView.POSTER_WIDTH*3)/2)
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("0191329282809", shape: .ean13)
    }
}
#endif
