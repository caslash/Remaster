//
//  Fixtures.swift
//  RemasterTests
//
//  Normalized edition bodies as the backend returns them, written against
//  backend/docs/edition-schema.md. These are not UPCMDB responses: the raw
//  recordings in backend/src/upc/mock/ never reach the app.
//
//  The bodies live as JSON files in Fixtures/ and are copied into the test
//  bundle, so they can be read and edited like real responses.
//

import Foundation
import Testing
@testable import Remaster

enum Fixtures {
    /// Only the keys the schema says are always present. The backend always
    /// sends `barcodes`, `packaging` and `editionFlags` as objects, dropping
    /// any keys whose value is unknown, so they can arrive empty.
    static var minimal: String { load("minimal") }

    /// Zootopia 2 (movie4kdv.json): a combo pack, 4K disc first.
    static var comboPack: String { load("combo-pack") }

    /// Black Panther: Wakanda Forever (movie4khdr.json): every flag an explicit false.
    static var explicitFalse: String { load("explicit-false") }

    /// Barnyard (moviebr.json): thin record, SDR Blu-ray.
    static var sdrBluray: String { load("sdr-bluray") }

    /// The schema's missing fixture: a 4K edition with no HDR information.
    static var uhdUnknownHDR: String { load("uhd-unknown-hdr") }

    /// SpongeBob SquarePants: The First 100 Episodes (tvdvd.json): fourteen region 1 DVDs.
    static var fourteenDVDs: String { load("fourteen-dvds") }

    /// A disc whose region the backend couldn't read: `region` is left out.
    static var discWithoutRegion: String { load("disc-without-region") }

    /// Keys a later backend might add (TMDB mapping, response wrapper).
    static var withUnknownKeys: String { load("unknown-keys") }

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

    /// Reads `<name>.json` from the test bundle.
    static func load(_ name: String) -> String {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            Issue.record("Fixture \(name).json is missing from the test bundle")
            return ""
        }
        return contents
    }

    private final class BundleToken { }
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
