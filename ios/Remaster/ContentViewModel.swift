//
//  ContentViewModel.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import Combine
import FactoryKit
import Foundation
import Observation
import SwiftUI

@Observable
public class ContentViewModel {
    private static let MINIMUM_WAIT: Duration = .milliseconds(500)
    
    @ObservationIgnored @Injected(\.barcodeService) private var barcodeService: any IBarcodeService

    public var edition: Edition?
    public var networkError: NetworkError?
    public var error: any Error?
    public var isFetching: Bool = false
    public var isIdle: Bool {
        self.isFetching == false && self.edition == nil && self.networkError == nil && self.error == nil
    }
    
    private var previousBarcode: String?

    init() { }
    
    func processBarcode(_ barcode: String) {
        if (self.isFetching) { return }
        
        self.previousBarcode = barcode
        self.networkError = nil
        self.error = nil
        
        self.isFetching = true
        
        Task {
            let clock = ContinuousClock()
            var success: Edition?
            var failure: Error?
            
            let elapsed = await clock.measure {
                do {
                    success = try await self.barcodeService.fetchBarcode(barcode)
                } catch {
                    failure = error
                }
            }
            
            if (elapsed < Self.MINIMUM_WAIT) { try? await Task.sleep(for: Self.MINIMUM_WAIT - elapsed) }
            
            if (failure == nil) {
                self.edition = success
            }
            
            if let networkFailure = failure as? NetworkError {
                self.networkError = networkFailure
            } else if let failure {
                self.error = failure
            }
            
            self.isFetching = false
        }
    }
    
    func retry() {
        if let retryBarcode = self.previousBarcode {
            self.processBarcode(retryBarcode)
        }
    }
}
