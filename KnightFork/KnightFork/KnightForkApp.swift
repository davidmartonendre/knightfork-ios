//
//  KnightForkApp.swift
//  KnightFork
//
//  Created by David Marton on 2026. 03. 21..
//

import SwiftUI
import SwiftData

@main
struct KnightForkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            GameRecord.self,
            EngineDescriptorModel.self
        ])
    }
}
