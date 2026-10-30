//
//  NetworkError.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import Foundation

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case transportError(URLError)
    case serverError(statusCode: Int)
    case decodingError(Error)
    case badRequest
    case notFound

    public var errorDescription: String? {
        switch (self) {
            case .transportError(let error): return {
                switch (error.code) {
                case .notConnectedToInternet: return "You're offline"
                case .timedOut: return "That took too long"
                default: return "Couldn't reach Remaster"
                }
            }()
            case .serverError(_): return {
                switch (self.isRetryable) {
                case true: return "Remaster is having trouble"
                case false: return "Something went wrong"
                }
            }()
            case .badRequest: return "That's not a disc barcode"
            case .notFound: return "We don't know this disc yet"
            case .decodingError: return "We couldn't read this disc's details"
            case .invalidResponse: return "Something went wrong"
            case .invalidURL: return "We couldn't look up that barcode"
        }
    }
    
    public var recoverySuggestion: String? {
        switch (self) {
            case .transportError(let error): return {
                switch (error.code) {
                case .notConnectedToInternet: return "Connect to the internet and try again."
                default: return "Check your connection and try again."
                }
            }()
            case .serverError: return {
                switch (self.isRetryable) {
                case true: return "This usually clears up quickly. Try again in a moment."
                case false: return "Please try again later."
                }
            }()
            case .badRequest: return "Store stickers and coupons won't work. Scan the barcode printed on the case."
            case .notFound: return "Try entering the barcode number printed under the bars."
            case .decodingError: return "That's a problem on our end. Try another disc, or try again later."
            case .invalidResponse: return "Please try again later."
            case .invalidURL: return "Scan the barcode printed on the case."
        }
    }
    
    public var isRetryable: Bool {
        switch (self) {
        case .badRequest, .notFound:
            return false
        case .serverError(let statusCode): return {
            guard (500...504).contains(statusCode) else { return false }
            return true
        }()
        case .transportError(let error): return {
            switch (error.code) {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                    return true
                default: return false
            }
        }()
        default: return false
        }
    }
}
