//
//  PosterService.swift
//  Remaster
//
//  Created by Cameron Slash on 11/23/26.
//

import FactoryKit
import Foundation
import ImageIO
import OSLog
import Synchronization
import SwiftData
import UIKit
import UniformTypeIdentifiers

public nonisolated class PosterService: PosterStore {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PosterService")
    private static let maxConcurrentDownloads = 4

    @Injected(\.modelContainer) private var modelContainer
    
    private let posterCache: NSCache<PosterCacheKey, UIImage> = {
        let cache = NSCache<PosterCacheKey, UIImage>()
        cache.totalCostLimit = 75 * 1024 * 1024
        return cache
    }()
    
    private let backfillTask = Mutex<Task<Void, Error>?>(nil)
    
    @concurrent
    func savePoster(persistentModelID: PersistentIdentifier, posterURL: URL) async throws {
        let (data, response) = try await URLSession.shared.data(from: posterURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            Self.logger.error("Failed to create CGImageSource")
            return
        }
        
        let count = CGImageSourceGetCount(source)
        let index = 0
        
        guard count > index else {
            Self.logger.error("The image has zero frames")
            return
        }
        
        let cgImageOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 500,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, cgImageOptions as CFDictionary) else {
            Self.logger.error("Failed to create CGImage")
            return
        }
        
        guard let imageData = await cgImage.encodedData(as: .jpeg) else {
            Self.logger.error("Image data could not be encoded")
            return
        }
        
        try await MainActor.run {
            var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.persistentModelID == persistentModelID })
            descriptor.fetchLimit = 1
            let model = try self.modelContainer.mainContext.fetch(descriptor).first
            
            model?.imageData = imageData
            model?.posterUpdatedAt = .now
            
            try self.modelContainer.mainContext.save()
        }
        
        posterCache.removeObject(forKey: PosterCacheKey(persistentModelID))
    }
    
    func backfillPosters() async throws {
        let task = backfillTask.withLock { current in
            if let current { return current }
            let new = Task {
                defer { self.backfillTask.withLock { $0 = nil } }
                try await self.performBackfill()
            }
            current = new
            return new
        }
        try await task.value
    }
    
    @concurrent
    func getPoster(persistentModelID: PersistentIdentifier) async -> UIImage? {
        let key = PosterCacheKey(persistentModelID)
        
        if let cached = posterCache.object(forKey: key) {
            return cached
        }
        
        let imageData: Data?
        let marker: Date?
        do {
            let context = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.persistentModelID == persistentModelID })
            descriptor.fetchLimit = 1
            let item = try context.fetch(descriptor).first
            imageData = item?.imageData
            marker = item?.posterUpdatedAt
        } catch {
            Self.logger.error("Failed to fetch poster data: \(error.localizedDescription)")
            return nil
        }
        
        guard let imageData else {
            return nil
        }
        
        guard let image = UIImage(data: imageData), let prepared = await image.byPreparingForDisplay() else {
            Self.logger.error("Stored poster is corrupt (\(imageData.count) bytes); clearing so the backfill re-downloads it")
            if !Task.isCancelled {
                await discardCorruptPoster(persistentModelID: persistentModelID, expectedMarker: marker)
            }
            return nil
        }
        
        let pixelWidth = prepared.size.width * prepared.scale
        let pixelHeight = prepared.size.height * prepared.scale
        let cost = Int(pixelWidth * pixelHeight) * 4
        posterCache.setObject(prepared, forKey: key, cost: cost)
        
        return prepared
    }
    
    private func performBackfill() async throws {
        let descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.posterURL != nil && $0.imageData == nil })

        let items = try await MainActor.run {
            try self.modelContainer.mainContext.fetch(descriptor).compactMap { item in
                item.posterURL.map { (id: item.persistentModelID, posterURL: $0) }
            }
        }

        await withTaskGroup(of: Void.self) { group in
            var remaining = items.makeIterator()

            func addNext() -> Bool {
                guard let item = remaining.next() else { return false }
                group.addTask {
                    do {
                        try await self.savePoster(persistentModelID: item.id, posterURL: item.posterURL)
                    } catch {
                        Self.logger.error("Failed to backfill poster from \(item.posterURL): \(error)")
                    }
                }
                return true
            }

            for _ in 0..<Self.maxConcurrentDownloads {
                guard addNext() else { break }
            }

            while await group.next() != nil {
                _ = addNext()
            }
        }
    }
    
    private func discardCorruptPoster(persistentModelID: PersistentIdentifier, expectedMarker: Date?) async {
        do {
            let context = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.persistentModelID == persistentModelID } )
            descriptor.fetchLimit = 1
            guard let item = try context.fetch(descriptor).first else { return }
            
            guard item.posterUpdatedAt == expectedMarker else { return }
            
            item.imageData = nil
            item.posterUpdatedAt = nil
            try context.save()
        } catch {
            Self.logger.error("Failed to clear corrupt poster: \(error.localizedDescription)")
        }
    }
    
    private class PosterCacheKey: NSObject {
        let id: PersistentIdentifier
        
        init(_ id: PersistentIdentifier) {
            self.id = id
        }
        
        override var hash: Int { id.hashValue }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? PosterCacheKey else { return false }
            return id == other.id
        }
    }
}
