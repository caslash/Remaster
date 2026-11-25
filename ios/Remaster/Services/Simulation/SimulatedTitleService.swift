//
//  SimulatedTitleService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

#if DEBUG
nonisolated public class SimulatedTitleService: TitleServicing {
    func searchTitle(_ searchText: String) async throws -> [Title] {
        return []
    }
}
#endif
