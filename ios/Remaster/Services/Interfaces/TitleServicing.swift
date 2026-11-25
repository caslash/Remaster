//
//  TitleServicing.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

nonisolated protocol TitleServicing {
    func searchTitle(_ searchText: String) async throws -> [Title]
}
