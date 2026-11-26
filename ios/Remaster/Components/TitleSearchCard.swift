//
//  TitleSearchCard.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import SwiftUI

struct TitleSearchCard: View {
    let title: Title
    
    var body: some View {
        HStack(spacing: 12) {
            Poster(title: title.name, posterURL: title.posterURL)
                .frame(width: 38, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            
            VStack(alignment: .leading) {
                Text(title.name)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(getSubtitleText())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func getSubtitleText() -> String {
        var entries: [String] = []
        
        entries.append(title.kind.displayName)
        if let year = title.year { entries.append("\(year.formatted(.number.grouping(.never)))") }
        
        return entries.joined(separator: " · ")
    }
}

#Preview {
    TitleSearchCard(title: Title(tmdbId: "1327819", kind: .movie, name: "Hoppers", year: 2026, posterURL: URL(string: "https://image.tmdb.org/t/p/w500/xjtWQ2CL1mpmMNwuU5HeS4Iuwuu.jpg")))
}
