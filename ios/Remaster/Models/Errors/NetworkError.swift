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
    case serverError(statusCode: Int, statusText: String)
    case decodingError(Error)
    case notFound(barcode: String)

    public var errorDescription: String? {
        switch (self) {
            case .invalidURL: "Invalid URL"
            case .invalidResponse: "Invalid response"
            case .transportError: "Error request"
            case .serverError(_, let statusText): statusText
            case .decodingError: "Error decoding response"
            case .notFound(let barcode): "We couldn't find the disc for \(barcode)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch (self) {
            case .notFound(_): "Try manually entering the disc's barcode number"
            default: nil
        }
    }
}
