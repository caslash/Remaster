//
//  TitleSearchError.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

public enum TitleSearchError: Error, LocalizedError {
    case serviceUnavailable(retryAfterSeconds: Int), offline, tempUnavailable, unexpected, cancelled
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable: return "Server is busy"
        case .offline: return "You're offline"
        case .tempUnavailable: return "Search isn't responding"
        case .unexpected: return "Something went wrong"
        case .cancelled: return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .serviceUnavailable: return "Try again in a minute."
        case .offline: return "Connect to Wi-Fi or mobile data to search."
        case .tempUnavailable: return "Try again in a moment."
        case .unexpected: return "Try different words, or try again later."
        case .cancelled: return nil
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .serviceUnavailable, .offline, .tempUnavailable: return true
        case .unexpected, .cancelled: return false
        }
    }
}
