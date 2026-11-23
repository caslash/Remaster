//
//  RemasterApp.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import FactoryKit
import SwiftData
import SwiftUI

@main
struct RemasterApp: App {
    private let container = Container.shared.modelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
