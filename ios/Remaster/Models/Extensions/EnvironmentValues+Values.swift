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
}
