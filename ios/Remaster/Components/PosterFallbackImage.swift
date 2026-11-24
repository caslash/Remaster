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
    let title: String?
    
    @ViewBuilder
    var fallbackPoster: some View {
        if let title {
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
    
    init(title: String? = nil) {
        self.title = title
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
            PosterFallbackImage(title: item.displayTitle)
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
