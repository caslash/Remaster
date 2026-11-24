//
//  Poster.swift
//  Remaster
//
//  Created by Cameron Slash on 11/24/26.
//

import SwiftUI

struct Poster: View {
    let title: String?
    let posterURL: URL?
    let posterImage: UIImage?
    
    var body: some View {
        if let posterImage {
            Image(uiImage: posterImage)
                .resizable()
                .scaledToFill()
        } else if posterURL != nil {
            AsyncImage(url: posterURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    PosterFallbackImage(title: title)
                } else {
                    ProgressView()
                }
            }
        } else {
            PosterFallbackImage(title: title)
        }
    }
    
    init(title: String? = nil, posterURL: URL? = nil, posterImage: UIImage? = nil) {
        self.title = title
        self.posterURL = posterURL
        self.posterImage = posterImage
    }
}

#Preview {
    Poster()
}
