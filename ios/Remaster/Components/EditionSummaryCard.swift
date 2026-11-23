//
//  EditionSummaryCard.swift
//  Remaster
//
//  Created by Cameron Slash on 11/19/26.
//

import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct EditionSummaryCard: View {
    let edition: Edition
    
    let titleNotConfirmed: Bool
    let someDetailsMissing: Bool
    
    var chipText: String? {
        if titleNotConfirmed {
            return "Title not confirmed"
        } else if someDetailsMissing {
            return "Some details missing"
        }
        
        return nil
    }

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: edition.title?.posterURL ?? edition.coverImageURL) { phase in
                if (edition.title?.posterURL ?? edition.coverImageURL) != nil {
                    if let image = phase.image {
                        image
                            .resizable()
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
            .frame(width: 76, height: 114)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) {
                if let format = edition.format?.displayString {
                    Text(format)
                        .font(.caption2.weight(.heavy))
                        .padding(2)
                        .background(in: RoundedRectangle(cornerRadius: 4))
                        .backgroundStyle(.ultraThickMaterial)
                        .padding(4)
                }
            }
            
            VStack(alignment: .leading) {
                Text(edition.upcTitle)
                    .multilineTextAlignment(.leading)
                    .font(.title2.weight(.heavy))
                    .accessibilityIdentifier("page.confirm.title")
                
                Text(getSubtitleText())
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)
                
                
                Text("UPC \(edition.barcodes.upc ?? edition.barcodes.ean ?? "")")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(.secondary)
                
                if let chipText {
                    Text(chipText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(4)
                        .background(in: RoundedRectangle(cornerRadius: 6))
                        .backgroundStyle(.orange.opacity(0.15))
                }
            }
        }
    }
    
    init(edition: Edition, titleNotConfirmed: Bool = false, someDetailsMissing: Bool = false) {
        self.edition = edition
        self.titleNotConfirmed = titleNotConfirmed
        self.someDetailsMissing = someDetailsMissing
    }
    
    private func getSubtitleText() -> String {
        var entries: [String] = []
        
        if let kind = edition.title?.kind ?? edition.kind { entries.append(kind.displayName) }
        if let year = edition.title?.year ?? edition.year { entries.append(year.formatted(.number.grouping(.never))) }
        if let distributor = edition.distributor { entries.append(distributor) }
        
        return entries.joined(separator: " · ")
    }
}

#if DEBUG && canImport(Vision)
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
#endif
