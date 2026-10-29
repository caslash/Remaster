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
        Factory(self) { BarcodeService() }
            .singleton
#if DEBUG
            .onArg("SIMULATED_SERVICES", factory: {
                SimulatedBarcodeService()
            })
#endif
    }
}
