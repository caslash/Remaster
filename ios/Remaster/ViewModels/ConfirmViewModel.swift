//
//  ConfirmViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 11/19/26.
//

import Foundation
import Observation

@Observable
public class ConfirmViewModel {
    public var edition: Edition
    
    public var ownedFormat: DiscFormat?
    public var hdrFormats: String
    public var editionText: String
    
    public var hasMultipleFormats: Bool
    public var secondFormatName: String?
    public var includesSecondFormat: Bool = true
    
    public var titleNotConfirmed: Bool
    public var someDetailsMissing: Bool
    
    public init(edition: Edition) {
        self.edition = edition
        
        self.ownedFormat = edition.format
        self.hdrFormats = ConfirmViewModel.getEditionHDRText(edition: edition)
        self.editionText = ConfirmViewModel.getEditionText(edition: edition)
        
        let multiFormatInfo = ConfirmViewModel.getSecondFormatName(edition: edition)
        
        self.hasMultipleFormats = multiFormatInfo.0
        self.secondFormatName = multiFormatInfo.1
        
        self.titleNotConfirmed = edition.unmatchedTitle == true
        self.someDetailsMissing = edition.unmatchedTitle == false && (edition.hdr == nil || (edition.packaging == nil || edition.packaging!.allNil))
    }
    
    private static func getEditionHDRText(edition: Edition) -> String {
        guard let formats = edition.hdr else { return "Unknown" }
        if formats.isEmpty { return "SDR" }
        
        return formats.map { $0.rawValue }.joined(separator: ", ")
    }
    
    private static func getEditionText(edition: Edition) -> String {
        if edition.packaging?.steelbook == false && edition.editionFlags.allFalse { return "Standard" }
        
        if edition.packaging?.steelbook ?? false { return "Steelbook" }
        if edition.editionFlags.collector ?? false { return "Collector's" }
        if edition.editionFlags.limited ?? false { return "Limited" }
        if edition.editionFlags.boxset ?? false { return "Boxset" }
        if edition.editionFlags.special ?? false { return "Special" }
        if edition.editionFlags.anniversary ?? false { return "Anniversary" }
            
        return "Unknown"
    }
    
    private static func getSecondFormatName(edition: Edition) -> (Bool, String?) {
        let discContentFormats = (edition.discContents ?? []).map { $0.format }.unique().sorted(sortedBy: \.upgradeOrder)
        
        let filteredFormats = discContentFormats.filter { $0 != edition.format }.map { $0.rawValue }
        
        return (discContentFormats.count > 1, edition.format == nil ? filteredFormats.last : filteredFormats.first)
    }
}
