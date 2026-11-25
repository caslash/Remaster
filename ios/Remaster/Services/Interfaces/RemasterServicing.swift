//
//  RemasterServicing.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import Foundation

nonisolated protocol RemasterServicing {
    func fetchRemaster(_ pathName: String, httpMethod: String?, queryItems: [URLQueryItem]?) async throws -> Data
}
