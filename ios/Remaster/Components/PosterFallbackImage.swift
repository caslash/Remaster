//
//  PosterFallbackImage.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import SwiftUI

struct PosterFallbackImage: View {
    var body: some View {
        VStack {
            Image(systemName: "opticaldisc")
                .resizable()
                .frame(width: 30, height: 30)
            
            Text("No cover")
                .font(.caption.bold())
        }
        .foregroundStyle(.gray)
        .frame(width: 76, height: 114)
        .background(Color(uiColor: .systemGray3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PosterFallbackImage()
}
