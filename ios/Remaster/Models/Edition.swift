//
//  Edition.swift
//  Remaster
//
//  Created by Cameron Slash on 10/27/26.
//

import Foundation

public nonisolated struct Edition: Codable, Identifiable {
    public var id: String
    var barcodes: Barcodes
    var asin: String?
    var imdbId: String?
    var upcTitle: String
    var enrichedTitle: String?
    var kind: Kind?
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
    var title: Title?
    var unmatchedTitle: Bool
}

nonisolated struct Barcodes: Codable {
    var upc: String?
    var ean: String?
}

nonisolated struct DiscContent: Codable {
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

nonisolated struct Packaging: Codable {
    var steelbook: Bool?
    var slipcover: Bool?
    var memorabilia: Bool?
}

extension Packaging {
    var allNil: Bool {
        Mirror(reflecting: self).children.allSatisfy { ($0.value as? Bool) == nil }
    }
}

nonisolated struct EditionFlags: Codable {
    var limited: Bool?
    var collector: Bool?
    var special: Bool?
    var anniversary: Bool?
    var boxset: Bool?
}

extension EditionFlags {
    var allFalse: Bool {
        Mirror(reflecting: self).children.allSatisfy { ($0.value as? Bool) == false }
    }
}

public nonisolated enum Kind: String, Codable {
    case movie = "movie", tv = "tv"
    
    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tv: return "TV"
        }
    }
}

public nonisolated enum DiscFormat: String, Comparable, Codable, CaseIterable, Identifiable {
    public static func < (lhs: DiscFormat, rhs: DiscFormat) -> Bool {
        return lhs.upgradeOrder < rhs.upgradeOrder
    }
    
    public static func sortList(_ list: [DiscFormat.RawValue]) -> [DiscFormat.RawValue] {
        return list.sorted(by: { lhs, rhs in
            switch (DiscFormat(rawValue: lhs), DiscFormat(rawValue: rhs)) {
            case let (lFormat?, rFormat?):
                return lFormat > rFormat
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return false
            }
        })
    }
    
    case dvd = "DVD", bluray = "Blu-ray", uhd = "4K UHD"
    
    public var id: Self { self }
    
    var displayString: String {
        switch self {
        case .dvd: return "DVD"
        case .bluray: return "BR"
        case .uhd: return "4K"
        }
    }
    
    var chipString: String {
        switch self {
        case .dvd: return "DVD"
        case .bluray: return "BD"
        case .uhd: return "4K"
        }
    }
    
    private var upgradeOrder: Int {
        switch self {
        case .dvd: return 0
        case .bluray: return 1
        case .uhd: return 2
        }
    }
}

nonisolated enum HDRFormat: String, Codable {
    case hdr10 = "HDR10", hdr10plus = "HDR10+", dolbyvision = "Dolby Vision"
}

nonisolated enum Resolution: String, Codable {
    case native = "native", upscaled = "upscaled"
}
