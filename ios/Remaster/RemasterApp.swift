//
//  RemasterApp.swift
//  Remaster
//
//  Created by Cameron Slash on 9/24/26.
//

import FactoryKit
import OSLog
import SwiftData
import SwiftUI

@main
struct RemasterApp: App {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RemasterApp")
    @Environment(\.scenePhase) private var scenePhase
    @Injected(\.posterService) private var posterService: any PosterStore
    
    private let container = Container.shared.modelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.posterService, posterService)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    do {
                        try await self.posterService.backfillPosters()
                    } catch {
                        Self.logger.error("Failed to backfill posters: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
