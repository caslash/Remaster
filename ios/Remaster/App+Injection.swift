//
//  App+Injection.swift
//  Remaster
//
//  Created by Cameron Slash on 10/29/26.
//

import FactoryKit
import Foundation

extension Container {
    var barcodeService: Factory<any IBarcodeService> {
        Factory(self) {
            #if targetEnvironment(simulator)
            SimulatedBarcodeService()
            #else
            BarcodeService()
            #endif
        }.singleton
    }
}
