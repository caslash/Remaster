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
    @ObservationIgnored @Injected(\.barcodeService) private var barcodeService: any IBarcodeService

    public var edition: Edition?
    public var error: any Error?

    init() { }

    func processBarcode(_ barcode: String) async {
        do {
            self.edition = try await self.barcodeService.fetchBarcode(barcode)
        } catch {
            self.error = error
        }
    }
}
