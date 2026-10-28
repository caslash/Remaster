//
//  ContentViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//
import Combine
import Foundation
import Observation

@Observable
public class ContentViewModel {
    @ObservationIgnored private var anycancellableset = Set<AnyCancellable>()

    public var movie: String?

    /// Injected at build time from `Config/Secrets.xcconfig` via Info.plist.
    private static let remasterURL = Bundle.main.object(forInfoDictionaryKey: "RemasterURL") as? String ?? ""

    init() { }

    func processBarcode(value: String) {
        print(value)
        if let url = URL(string:  "\(Self.remasterURL)/upc/\(value.trimmingCharacters(in: [" "]))") {

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            URLSession.shared.dataTaskPublisher(for: request)
                .map { Self.prettyPrinted($0.data) }
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { print("completion: \($0)") }, receiveValue: { self.movie = $0 })
                .store(in: &anycancellableset)
        }
    }

    /// Re-serializes the response as indented JSON, falling back to the raw text if it isn't valid JSON.
    private static func prettyPrinted(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
              )
        else { return String(decoding: data, as: UTF8.self) }
        return String(decoding: pretty, as: UTF8.self)
    }
}
