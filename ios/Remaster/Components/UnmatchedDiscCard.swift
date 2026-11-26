//
//  UnmatchedDiscCard.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import SwiftUI

struct UnmatchedDiscCard: View {
    let searchType: TitleSearchType
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "barcode.viewfinder")
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding(6)
                .background(Circle().fill(.thickMaterial))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(searchType.unmatchedCardTitle)
                    .font(.footnote.bold())
                
                Text(searchType.unmatchedCardText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

#Preview("Barcode Not Found") {
    UnmatchedDiscCard(searchType: .barcodeNotFound(upc: "043396648654"))
}

#Preview("Title Not Confirmed") {
    UnmatchedDiscCard(searchType: .titleNotConfirmed(upc: "043396648654", prefillQuery: "Hoppers"))
}
