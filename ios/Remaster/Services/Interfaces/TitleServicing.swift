//
//  TitleServicing.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

nonisolated protocol TitleServicing: Sendable {
    func searchTitle(_ query: String) async throws(TitleSearchError) -> [Title]
}
