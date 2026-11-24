//
//  LibraryCardViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import FactoryKit
import Foundation
import Observation
import SwiftData
import UIKit

@Observable
public class LibraryCardViewModel {
    @ObservationIgnored @Injected(\.posterService) private var posterService: any PosterStore
    
    init() {}
    
    public func getPoster(persistentModelID: PersistentIdentifier) async -> UIImage? {
        return await self.posterService.getPoster(persistentModelID: persistentModelID)
    }
}
