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
    
    let item: LibraryItem?
    
    @Environment(\.posterService) private var posterService: any PosterStore
    @State private var posterImage: UIImage?
    
    var body: some View {
        if let item {
            VStack(alignment: .leading) {
                Poster(title: item.displayTitle, posterURL: item.posterURL, posterImage: posterImage)
                    .frame(width: Self.POSTER_WIDTH, height: (Self.POSTER_WIDTH*3)/2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        if let formats = item.ownedFormats?.map({ DiscFormat(rawValue: $0) }) {
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
                self.posterImage = await self.posterService.getPoster(persistentModelID: item.id)
            }
        }
    }
    
    init(item: LibraryItem?) {
        self.item = item
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

        struct Cache {
            var frames: [CGRect] = []
            var size: CGSize = .zero
        }

        func makeCache(subviews: Subviews) -> Cache {
            guard !subviews.isEmpty else { return Cache() }

            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            let frontWidth = sizes[0].width

            var frames: [CGRect] = []
            frames.reserveCapacity(sizes.count)
            var minX = CGFloat.infinity
            var maxX = -CGFloat.infinity
            var maxHeight: CGFloat = 0

            for (index, size) in sizes.enumerated() {
                let trailing = frontWidth + CGFloat(index) * peek
                let frame = CGRect(x: trailing - size.width, y: 0,
                                   width: size.width, height: size.height)
                frames.append(frame)
                minX = min(minX, frame.minX)
                maxX = max(maxX, frame.maxX)
                maxHeight = max(maxHeight, size.height)
            }

            return Cache(
                frames: frames.map { $0.offsetBy(dx: -minX, dy: 0) },
                size: CGSize(width: maxX - minX, height: maxHeight)
            )
        }

        func updateCache(_ cache: inout Cache, subviews: Subviews) {
            cache = makeCache(subviews: subviews)
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
            cache.size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
            for (subview, frame) in zip(subviews, cache.frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.midY),
                    anchor: .leading,
                    proposal: ProposedViewSize(frame.size)
                )
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
        return .init(upc: edition.barcodes.upc, ean: edition.barcodes.ean, kind: edition.title?.kind.rawValue, tmdbId: edition.title?.tmdbId, ownedFormats: [DiscFormat.uhd, DiscFormat.bluray, DiscFormat.dvd].map { $0.rawValue }, edition: edition)
    }

    LibraryCardView(item: item)
}
#endif
