//
//  PosterStore.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import Foundation
import SwiftData
import UIKit

protocol PosterStore {
    func savePoster(persistentModelID: PersistentIdentifier, posterURL: URL) async throws
    func backfillPosters() async throws
    func getPoster(persistentModelID: PersistentIdentifier) async -> UIImage?
}
