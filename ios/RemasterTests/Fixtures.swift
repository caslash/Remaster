//
//  Fixtures.swift
//  RemasterTests
//
//  Normalized edition bodies as the backend returns them, written against
//  backend/docs/edition-schema.md. These are not UPCMDB responses: the raw
//  recordings in backend/src/upc/mock/ never reach the app.
//

import Foundation
@testable import Remaster

enum Fixtures {
    /// Only the keys the schema says are always present. The backend always
    /// sends `barcodes`, `packaging` and `editionFlags` as objects, dropping
    /// any keys whose value is unknown, so they can arrive empty.
    static let minimal = """
    {
      "id": "0786936900378",
      "title": "WandaVision: The Complete Series",
      "barcodes": {},
      "packaging": {},
      "editionFlags": {}
    }
    """

    /// Zootopia 2 (movie4kdv.json): a combo pack, 4K disc first.
    static let comboPack = """
    {
      "id": "0786936900001",
      "barcodes": { "upc": "786936900001", "ean": "0786936900001" },
      "imdbId": "tt26443597",
      "title": "Zootopia 2 (4K Ultra HD + Blu-ray) SteelBook",
      "enrichedTitle": "Zootopia 2",
      "kind": "movie",
      "year": 2025,
      "format": "4K UHD",
      "discContents": [
        { "format": "4K UHD", "region": "Region free" },
        { "format": "Blu-ray", "region": ["A", "B"] }
      ],
      "hdr": ["Dolby Vision", "HDR10"],
      "packaging": { "steelbook": true },
      "editionFlags": {},
      "masterResolution": "upscaled",
      "releaseDate": "2026-03-03",
      "coverImageURL": "https://imagestorage.org/786936900001.jpg",
      "runtime": 108,
      "hasDigital": true
    }
    """

    /// Black Panther: Wakanda Forever (movie4khdr.json): every flag an explicit false.
    static let explicitFalse = """
    {
      "id": "0786936900002",
      "barcodes": { "upc": "786936900002" },
      "title": "Black Panther: Wakanda Forever",
      "format": "4K UHD",
      "hdr": ["HDR10"],
      "packaging": { "steelbook": false, "slipcover": true },
      "editionFlags": {
        "limited": false,
        "collector": false,
        "special": false,
        "anniversary": false,
        "boxset": false
      },
      "masterResolution": "native",
      "hasDigital": false
    }
    """

    /// Barnyard (moviebr.json): thin record, SDR Blu-ray.
    static let sdrBluray = """
    {
      "id": "0097361180047",
      "barcodes": { "upc": "097361180047" },
      "title": "Barnyard",
      "format": "Blu-ray",
      "hdr": [],
      "packaging": {},
      "editionFlags": {},
      "runtime": 90
    }
    """

    /// The schema's missing fixture: a 4K edition with no HDR information.
    static let uhdUnknownHDR = """
    {
      "id": "0786936900003",
      "barcodes": {},
      "title": "Unknown HDR 4K",
      "format": "4K UHD",
      "packaging": {},
      "editionFlags": {}
    }
    """

    /// SpongeBob SquarePants: The First 100 Episodes (tvdvd.json): fourteen region 1 DVDs.
    static let fourteenDVDs: String = {
        let discs = Array(repeating: #"{ "format": "DVD", "region": ["1"] }"#, count: 14)
            .joined(separator: ", ")
        return """
        {
          "id": "0097368000003",
          "barcodes": {},
          "title": "SpongeBob SquarePants: The First 100 Episodes",
          "format": "DVD",
          "discContents": [\(discs)],
          "hdr": [],
          "packaging": { "slipcover": true },
          "editionFlags": {}
        }
        """
    }()

    /// A disc whose region the backend couldn't read: `region` is left out.
    static let discWithoutRegion = """
    {
      "id": "0786936900004",
      "barcodes": {},
      "title": "Region Unknown",
      "format": "4K UHD",
      "discContents": [{ "format": "4K UHD" }],
      "packaging": {},
      "editionFlags": {}
    }
    """

    /// Keys a later backend might add (TMDB mapping, response wrapper).
    static let withUnknownKeys = """
    {
      "id": "0786936900378",
      "title": "WandaVision: The Complete Series",
      "barcodes": {},
      "packaging": {},
      "editionFlags": {},
      "tmdbId": 85271,
      "posterURL": "https://example.com/poster.jpg",
      "provenance": { "source": "upcmdb" }
    }
    """

    /// The minimal body with one top-level key replaced or added.
    static func minimal(with key: String, _ jsonValue: String) -> String {
        """
        {
          "id": "0786936900378",
          "title": "WandaVision: The Complete Series",
          "barcodes": {},
          "packaging": {},
          "editionFlags": {},
          "\(key)": \(jsonValue)
        }
        """
    }

    static func decode(_ json: String) throws -> Edition {
        try JSONDecoder().decode(Edition.self, from: Data(json.utf8))
    }
}

extension NetworkError {
    /// The case without its payload, so tests can compare errors.
    var caseName: String {
        switch self {
        case .invalidURL: "invalidURL"
        case .invalidResponse: "invalidResponse"
        case .transportError: "transportError"
        case .serverError: "serverError"
        case .decodingError: "decodingError"
        case .badRequest: "badRequest"
        case .notFound: "notFound"
        }
    }
}
