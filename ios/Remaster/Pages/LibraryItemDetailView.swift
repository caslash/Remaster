//
//  LibraryItemDetailView.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import SwiftUI

#if DEBUG && canImport(Vision)
import Vision
#endif

struct LibraryItemDetailView: View {
    @State private var viewModel: LibraryItemDetailViewModel
    @State private var showDeleteConfirmation = false
    
    let onDelete: () -> Void
    
    var body: some View {
        Form {
            HStack(alignment: .bottom) {
                Poster(title: viewModel.libraryItem.displayTitle, posterURL: viewModel.libraryItem.posterURL, posterImage: viewModel.posterImage)
                    .frame(width: 76, height: 114)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomLeading) {
                        if let format = viewModel.edition?.format?.displayString {
                            Text(format)
                                .font(.caption2.weight(.heavy))
                                .padding(2)
                                .background(in: RoundedRectangle(cornerRadius: 4))
                                .backgroundStyle(.ultraThickMaterial)
                                .padding(4)
                        }
                    }
                
                VStack(alignment: .leading) {
                    if let displayTitle = viewModel.libraryItem.displayTitle {
                        Text(displayTitle)
                            .font(.title.bold())
                            .multilineTextAlignment(.leading)
                            .truncationMode(.tail)
                    }
                    
                    Text(getSubtitleText())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                if let ownedFormats = viewModel.libraryItem.ownedFormats {
                    LabeledContent("Formats", value: ownedFormats.joined(separator: " + "))
                }
                
                if let hdrFormats = viewModel.edition?.hdr {
                    LabeledContent("HDR", value: hdrFormats.map { $0.rawValue }.joined(separator: ", "))
                }
                
                if let editionText = viewModel.editionText {
                    LabeledContent("Edition", value: editionText)
                }
                
                if viewModel.copies > 1 {
                    LabeledContent("Copies", value: viewModel.copies.formatted(.number))
                }
                
                LabeledContent("Added", value: viewModel.libraryItem.dateAdded.formatted(.dateTime))
                
                if let upc = viewModel.libraryItem.upc ?? viewModel.libraryItem.ean {
                    LabeledContent("UPC", value: upc)
                }
            } header: {
                Text("Your Copy")
                    .textCase(.uppercase)
                    .font(.footnote)
            }
            
            Section {
                Button("Delete from Library", role: .destructive) {
                    showDeleteConfirmation = true
                }
            } footer: {
                Text("Your library is stored only on this iPhone")
            }
        }
        .confirmationDialog("Delete item?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                self.viewModel.deleteItem(onComplete: {
                    onDelete()
                })
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(viewModel.libraryItem.displayTitle ?? viewModel.edition?.upcTitle ?? "This title") will be removed from your libary on this iPhone")
        }
        .alert(error: self.$viewModel.error) {
            Button("OK") { }
        }
        .task {
            self.viewModel.fetchPoster()
            await self.viewModel.observeLibraryChanges()
        }
    }
    
    init(item: LibraryItem, onDelete: @escaping () -> Void) {
        self.viewModel = LibraryItemDetailViewModel(libraryItem: item)
        self.onDelete = onDelete
    }
    
    private func getSubtitleText() -> String {
        var entries: [String] = []
        
        let itemKind = Kind(rawValue: viewModel.libraryItem.kind ?? "")
        
        if let kind = itemKind ?? viewModel.edition?.title?.kind ?? viewModel.edition?.kind { entries.append(kind.displayName) }
        if let year = viewModel.libraryItem.year ?? viewModel.edition?.title?.year ?? viewModel.edition?.year { entries.append(year.formatted(.number.grouping(.never))) }
        if let distributor = viewModel.edition?.distributor { entries.append(distributor) }
        
        return entries.joined(separator: " · ")
    }
}

#if DEBUG && canImport(Vision)
#Preview {
    @Previewable @State var edition: Edition?
    
    var item: LibraryItem {
        return .init(upc: edition?.barcodes.upc, ean: edition?.barcodes.ean, kind: edition?.title?.kind.rawValue, tmdbId: edition?.title?.tmdbId, ownedFormats: edition?.discContents?.map { $0.format.rawValue }, edition: edition)
    }
    
    Group {
        if let edition {
            LibraryItemDetailView(item: item) { }
        } else {
            ProgressView("Loading preview data...")
        }
    }
    .task {
        edition = try? await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
    }
}
#endif
