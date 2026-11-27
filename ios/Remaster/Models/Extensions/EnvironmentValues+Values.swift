//
//  EnvironmentValues+Values.swift
//  Remaster
//
//  Created by Cameron Slash on 11/25/26.
//

import FactoryKit
import SwiftUI

extension EnvironmentValues {
    @Entry var posterService: any PosterStore = Container.shared.posterService()
    @Entry var openScanner = OpenScannerAction(isPresented: .constant(false))
    @Entry var closeScanner = CloseScannerAction(isPresented: .constant(false))
}

struct OpenScannerAction {
    var isPresented: Binding<Bool>

    func callAsFunction() {
        isPresented.wrappedValue = true
    }
}

struct CloseScannerAction {
    var isPresented: Binding<Bool>
    
    func callAsFunction() {
        isPresented.wrappedValue = false
    }
}
