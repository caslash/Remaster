//
//  LibraryCardView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import FactoryKit
import SwiftData
import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct LibraryCardView: View {
    static let POSTER_WIDTH: CGFloat = 111
    
    @State private var viewModel: LibraryCardViewModel
    @State private var posterImage: UIImage?
    
    let item: LibraryItem?
    let formats: [DiscFormat?]?

    var body: some View {
        if let item {
            VStack(alignment: .leading) {
                Poster(title: item.displayTitle, posterURL: item.posterURL, posterImage: posterImage)
                    .frame(width: Self.POSTER_WIDTH, height: (Self.POSTER_WIDTH*3)/2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        if let formats {
                            ChipStackLayout(peek: 8) {
                                ForEach(Array(formats.compactMap { $0 }.enumerated()), id: \.offset) { index, format in
                                    FormatChip(format: format)
                                        .zIndex(-Double(index))
                                }
                            }
                            .padding(4)
                        }
                    }
                
                if let displayTitle = item.displayTitle {
                    Text(displayTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .bold()
                }
                
                if let year = item.year {
                    Text(year.formatted(.number.grouping(.never)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Self.POSTER_WIDTH)
            .task(id: item.posterUpdatedAt) {
                posterImage = await self.viewModel.getPoster(persistentModelID: item.persistentModelID)
            }
        }
    }
    
    init(item: LibraryItem?) {
        self.viewModel = LibraryCardViewModel()
        self.item = item
        self.formats = item?.ownedFormats?.map { DiscFormat(rawValue: $0) }
    }
    
    struct FormatChip: View {
        let format: DiscFormat
        
        var body: some View {
            Text(format.chipString)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(format.backgroundColor))
        }
    }
    
    struct ChipStackLayout: Layout {
        var peek: CGFloat
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let frames = frames(for: subviews)
            guard let minX = frames.map(\.minX).min(), let maxX = frames.map(\.maxX).max() else { return .zero }
            return CGSize(width: maxX - minX, height: frames.map(\.height).max() ?? 0)
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let frames = frames(for: subviews)
            let minX = frames.map(\.minX).min() ?? 0
            for (subview, frame) in zip(subviews, frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX - minX, y: bounds.midY),
                    anchor: .leading,
                    proposal: ProposedViewSize(frame.size)
                )
            }
        }
        
        private func frames(for subviews: Subviews) -> [CGRect] {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            guard let front = sizes.first else { return [] }
            return sizes.enumerated().map { index, size in
                let trailing = front.width + CGFloat(index) * peek
                return CGRect(x: trailing - size.width, y: 0, width: size.width, height: size.height)
            }
        }
    }
}

extension DiscFormat {
    var backgroundColor: Color {
        switch self {
        case .dvd: return .gray
        case .bluray: return .blue
        case .uhd: return .black
        }
    }
}

#if DEBUG && canImport(Vision)
#Preview {
    let edition: Edition = Edition.hoppers
    
    var item: LibraryItem? {
        return .init(upc: edition.barcodes.upc, ean: edition.barcodes.ean, kind: edition.title?.kind.rawValue, tmdbId: edition.title?.tmdbId, ownedFormats: edition.discContents?.map { $0.format.rawValue }, edition: edition)
    }

    LibraryCardView(item: item)
}
#endif
