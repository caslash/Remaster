//
//  BackendError.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

public enum BackendError: Error {
    case generic(any Error), invalidURL, transportError(urlError: URLError), invalidResponse, serverError(statusCode: Int, retryAfter: Int?)
}
