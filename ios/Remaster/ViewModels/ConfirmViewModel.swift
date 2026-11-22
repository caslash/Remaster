//
//  ConfirmViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 11/19/26.
//

import FactoryKit
import Foundation
import Observation

@Observable
public class ConfirmViewModel {
    public let edition: Edition
    
    public var discFormat: DiscFormat? {
        didSet {
            includesOtherFormats = true
        }
    }
    public var hdrFormats: String { getEditionHDRText() }
    public var editionText: String { getEditionText() }
    
    public var selectedFormatIncludedAndHasLeftover: Bool { getFormatIncludedAndHasLeftover() }
    public var secondFormatName: String? { getSecondFormatName() }
    public var includesOtherFormats: Bool = true
    
    public var titleNotConfirmed: Bool { edition.unmatchedTitle == true }
    public var someDetailsMissing: Bool { edition.unmatchedTitle == false && (edition.hdr == nil || (edition.packaging == nil || edition.packaging!.allNil)) }
    
    public var ownedFormats: [DiscFormat] { getOwnedFormats() }
    
    public var libraryError: LibraryError?
    public var isDuplicate: Bool = false
    public var error: any Error?
    public var isSaving: Bool = false
    public var saved: Bool = false
    
    @ObservationIgnored @Injected(\.libraryService) private var libraryService: any LibraryManaging
    
    public init(edition: Edition) {
        self.edition = edition
        self.discFormat = edition.format
    }
    
    public func saveToLibrary(isRetry: Bool = false) {
        self.isSaving = true
        
        Task {
            let item: LibraryItem = .init(upc: self.edition.barcodes.upc, ean: self.edition.barcodes.ean, kind: self.edition.title?.kind.rawValue, tmdbId: self.edition.title?.tmdbId, ownedFormats: self.ownedFormats.map { $0.rawValue }, edition: self.edition)
            var failure: Error?
            
            do {
                try await self.libraryService.addToLibrary(item, forceDuplicate: isRetry)
            } catch {
                failure = error
            }
            
            if failure == nil {
                self.saved = true
            }
            
            if let libraryFailure = failure as? LibraryError {
                self.libraryError = libraryFailure
                self.isDuplicate = true
            } else if let failure {
                self.error = failure
            }
            
            self.isSaving = false
        }
    }
    
    private func getEditionHDRText() -> String {
        guard let formats = edition.hdr else { return "Unknown" }
        if formats.isEmpty { return "SDR" }
        
        return formats.map { $0.rawValue }.joined(separator: ", ")
    }
    
    private func getEditionText() -> String {
        if edition.packaging?.steelbook == false && edition.editionFlags.allFalse { return "Standard" }

        if edition.packaging?.steelbook ?? false { return "Steelbook" }
        if edition.editionFlags.collector ?? false { return "Collector's" }
        if edition.editionFlags.limited ?? false { return "Limited" }
        if edition.editionFlags.boxset ?? false { return "Boxset" }
        if edition.editionFlags.special ?? false { return "Special" }
        if edition.editionFlags.anniversary ?? false { return "Anniversary" }
            
        return "Unknown"
    }
    
    private func getDiscContentFormats() -> [DiscFormat] {
        return (edition.discContents ?? []).map { $0.format }.unique().sorted(sortedBy: \.upgradeOrder)
    }
    
    private func getLeftoverFormats() -> [DiscFormat] {
        return getDiscContentFormats().filter { $0 != discFormat }
    }
    
    private func getFormatIncludedAndHasLeftover() -> Bool {
        guard let discFormat else { return false }
        let discContentFormats = getDiscContentFormats()
        let selectedFormatIncluded = discContentFormats.contains(discFormat)
        let hasLeftover = getLeftoverFormats().count > 0
        return selectedFormatIncluded && hasLeftover
    }
    
    private func getSecondFormatName() -> String? {
        let formats = getLeftoverFormats()
        return discFormat == nil || formats.isEmpty ? nil : formats.map { $0.rawValue }.joined(separator: ", ")
    }
    
    private func getOwnedFormats() -> [DiscFormat] {
        guard let discFormat = discFormat else { return [] }
        
        return includesOtherFormats && selectedFormatIncludedAndHasLeftover ? [discFormat] + getLeftoverFormats() : [discFormat]
    }
}
