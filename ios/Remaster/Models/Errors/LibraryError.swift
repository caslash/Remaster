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
    case extraFormat(formats: [DiscFormat.RawValue])
    case duplicateNotFound
    
    public var errorDescription: String? {
        switch self {
        case .duplicate, .extraFormat: return "Already in your library"
        case .ownedInOtherFormats(let formats): return "You own this on \(formats.joined(separator: " + "))"
        case .duplicateNotFound: return "Couldn't find your copy"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .duplicate: return "Own a second copy? Add it so your library count stays right."
        case .ownedInOtherFormats: return "This is a different edition. Add it as another copy?"
        case .extraFormat(let formats): return "Add \(formats.joined(separator: " + ")) to your copy?"
        case .duplicateNotFound: return "It may have been removed. Try adding it again."
        }
    }
}
