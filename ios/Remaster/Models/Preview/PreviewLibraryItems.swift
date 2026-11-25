//
//  PreviewLibraryItems.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

#if DEBUG
import FactoryKit
import Foundation
import SwiftData
import SwiftUI
import Vision

struct PreviewLibraryItems: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let modelContainer = Container.shared.modelContainer()
        
        let hoppers = try await SimulatedBarcodeService().fetchBarcode("043396648654", shape: .ean13)
        let grinch = try await SimulatedBarcodeService().fetchBarcode("0191329282809", shape: .ean13)
        let wandavision = try await SimulatedBarcodeService().fetchBarcode("786936900378", shape: .ean13)
        
        let editions = [hoppers, grinch, wandavision]
        
        editions.forEach({ edition in
            let item = LibraryItem(upc: edition.barcodes.upc, ean: edition.barcodes.ean, kind: edition.title?.kind.rawValue, tmdbId: edition.title?.tmdbId, ownedFormats: edition.discContents?.map { $0.format.rawValue }, edition: edition)
            
            modelContainer.mainContext.insert(item)
        })
        
        return modelContainer
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}
#endif
