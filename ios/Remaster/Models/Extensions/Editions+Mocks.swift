//
//  Editions+Mocks.swift
//  Remaster
//
//  Created by Cameron Slash on 11/24/26.
//

#if DEBUG
import Foundation

nonisolated extension Edition {
    static let hoppers = Edition(
            id: "0043396648654",
            barcodes: Barcodes(upc: "043396648654", ean: "0043396648654"),
            asin: "B0GZ8H6XWW",
            imdbId: "tt26443616",
            upcTitle: "Hoppers",
            enrichedTitle: "Hoppers",
            kind: .movie,
            year: 2026,
            format: .uhd,
            discContents: [
                DiscContent(format: .uhd, regionFree: true),
                DiscContent(format: .bluray, regionFree: false, regions: ["A"])
            ],
            hdr: [.dolbyvision, .hdr10],
            packaging: Packaging(steelbook: true),
            editionFlags: EditionFlags(),
            masterResolution: .native,
            country: "United States",
            coverImageURL: URL(string: "https://imagestorage.org/043396648654.jpg"),
            audio: "English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) French (Canada): Dolby Digital Plus 7.1 Spanish: Dolby Digital Plus 7.1 Japanese: Dolby Digital Plus 7.1 ( more ) | Audio descriptive",
            subtitles: ["English SDH", "French", "Japanese", "Spanish"],
            title: Title(
                tmdbId: "1327819",
                kind: .movie,
                name: "Hoppers",
                year: 2026,
                imdbId: "tt26443616",
                posterURL: URL(string: "https://image.tmdb.org/t/p/w500/xjtWQ2CL1mpmMNwuU5HeS4Iuwuu.jpg")
            ),
            unmatchedTitle: false
        )

        static let grinch = Edition(
            id: "0191329282809",
            barcodes: Barcodes(upc: "0191329282809", ean: "0191329282809"),
            asin: "B0FMGHFVNZ",
            imdbId: "tt0170016",
            upcTitle: "Dr. Seuss' How the Grinch Stole Christmas",
            year: 2000,
            format: .uhd,
            packaging: Packaging(),
            editionFlags: EditionFlags(anniversary: true),
            coverImageURL: URL(string: "https://imagestorage.org/0191329282809.jpg"),
            unmatchedTitle: true
        )

        static let wandaVision = Edition(
            id: "0786936900378",
            barcodes: Barcodes(upc: "786936900378", ean: "0786936900378"),
            asin: "B0CG6J1JLT",
            imdbId: "tt9140560",
            upcTitle: "WandaVision: The Complete Series",
            enrichedTitle: "WandaVision",
            kind: .tv,
            year: 2021,
            format: .uhd,
            discContents: [
                DiscContent(format: .uhd, regionFree: true),
                DiscContent(format: .uhd, regionFree: true)
            ],
            hdr: [.hdr10],
            packaging: Packaging(steelbook: true, memorabilia: true),
            editionFlags: EditionFlags(limited: false, collector: true, special: false, anniversary: false, boxset: false),
            masterResolution: .native,
            releaseDate: "2023-11-28",
            distributor: "Disney / Buena Vista",
            country: "United States",
            coverImageURL: URL(string: "https://imagestorage.org/786936900378.jpg"),
            runtime: 321,
            audio: "English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) French (Canada): Dolby Digital 5.1 Spanish: Dolby Digital 5.1 (640 kbps) | Audio descriptive",
            subtitles: ["English SDH", "French", "Spanish"],
            hasDigital: false,
            title: Title(tmdbId: "85271", kind: .tv, name: "WandaVision", year: 2021, imdbId: "tt9140560", posterURL: nil),
            unmatchedTitle: false
        )
}

nonisolated extension DiscContent {
    init(format: DiscFormat, regionFree: Bool? = nil, regions: [String]? = nil) {
        self.format = format
        self.regionFree = regionFree
        self.regions = regions
    }
}
#endif
