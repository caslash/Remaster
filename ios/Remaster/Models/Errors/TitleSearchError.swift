//
//  TitleSearchError.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

public enum TitleSearchError: Error, LocalizedError {
    case serviceUnavailable(retryAfterSeconds: Int)
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable: return "The search service is busy. Please try again shortly"
        }
    }
}
