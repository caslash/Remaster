//
//  Edition.swift
//  Remaster
//
//  Created by Cameron Slash on 10/27/26.
//

import Foundation

struct Edition: Codable, Identifiable {
    var id: String
    var barcodes: Barcodes
    var asin: String?
    var imdbId: String?
    var title: String
    var enrichedTitle: String?
    var kind: EditionKind?
    var year: Int?
    var format: DiscFormat?
    var discContents: [DiscContent]?
    var hdr: [HDRFormat]?
    var packaging: Packaging?
    var editionFlags: EditionFlags
    var masterResolution: Resolution?
    var releaseDate: String?
    var distributor: String?
    var country: String?
    var coverImageURL: URL?
    var runtime: Int?
    var audio: String?
    var subtitles: [String]?
    var hasDigital: Bool?
}

struct Barcodes: Codable {
    var upc: String?
    var ean: String?
}

struct DiscContent: Codable {
    var format: DiscFormat
    var regionFree: Bool?
    var regions: [String]?
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.format = try container.decode(DiscFormat.self, forKey: .format)
        
        do {
            if let listOfRegions = try container.decodeIfPresent([String].self, forKey: .region) {
                self.regions = listOfRegions
                self.regionFree = false
            } else {
                self.regions = nil
                self.regionFree = nil
            }
        } catch {
            self.regionFree = (try container.decodeIfPresent(String.self, forKey: .region)) == "Region free" ? true : nil
            self.regions = nil
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.format, forKey: .format)
        if regionFree ?? false {
            try container.encode("Region free", forKey: .region)
        } else {
            try container.encodeIfPresent(regions, forKey: .region)
        }
    }
    
    enum CodingKeys: CodingKey {
        case format, region
    }
}

struct Packaging: Codable {
    var steelbook: Bool?
    var slipcover: Bool?
    var memorabilia: Bool?
}

struct EditionFlags: Codable {
    var limited: Bool?
    var collector: Bool?
    var special: Bool?
    var anniversary: Bool?
    var boxset: Bool?
}

enum EditionKind: String, Codable {
    case movie = "movie", tv = "tv"
}

enum DiscFormat: String, Codable {
    case dvd = "DVD", bluray = "Blu-ray", uhd = "4K UHD"
}

enum HDRFormat: String, Codable {
    case hdr10 = "HDR10", hdr10plus = "HDR10+", dolbyvision = "Dolby Vision"
}

enum Resolution: String, Codable {
    case native = "native", upscaled = "upscaled"
}
