//
//  LibraryError.swift
//  Remaster
//
//  Created by Cameron Slash on 11/21/26.
//

import Foundation

public enum LibraryError: Error, LocalizedError, Equatable {
    case duplicate
    case ownedInOtherFormats(formats: [DiscFormat.RawValue])
    
    public var errorDescription: String? {
        switch self {
        case .duplicate: return "Already in your library"
        case .ownedInOtherFormats(let formats): return "You own this on \(formats.joined(separator: " + "))"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .duplicate: return "Own a second copy? Add it so your library count stays right."
        case .ownedInOtherFormats: return "This is a different edition. Add it as another copy?"
        }
    }
}
