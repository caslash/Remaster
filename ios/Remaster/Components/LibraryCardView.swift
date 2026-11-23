//
//  LibraryCardView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct LibraryCardView: View {
    let edition: Edition
    let formats: [DiscFormat?]?

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: edition.title?.posterURL ?? edition.coverImageURL) { phase in
                if (edition.title?.posterURL ?? edition.coverImageURL) != nil {
                    if let image = phase.image {
                        image.resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        PosterFallbackImage()
                    } else {
                        ProgressView()
                    }
                } else {
                    PosterFallbackImage()
                }
            }
            .frame(width: 111, height: 167)
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
            
            Text(edition.upcTitle)
                .lineLimit(1)
                .truncationMode(.tail)
                .bold()
            
            if let year = edition.title?.year ?? edition.year {
                Text(year.formatted(.number.grouping(.never)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    init(edition: Edition, formats: [DiscFormat.RawValue]?) {
        self.edition = edition
        self.formats = formats?.map { DiscFormat(rawValue: $0) }
    }
    
    struct FormatChip: View {
        let format: DiscFormat
        
        var backgroundColor: Color {
            switch format {
            case .dvd: return .gray
            case .bluray: return .blue
            case .uhd: return .black
            }
        }
        
        var body: some View {
            Text(format.chipString)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(backgroundColor))
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

#if DEBUG && canImport(Vision)
#Preview {
    @Previewable @State var edition: Edition?
    
    Group {
        if let edition {
            LibraryCardView(edition: edition, formats: [DiscFormat.uhd.rawValue, DiscFormat.bluray.rawValue, DiscFormat.dvd.rawValue])
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
#endif
