//
//  ContentView.swift
//  KnightFork
//
//  Created by David Marton on 2026. 03. 21..
//

import SwiftUI

struct ContentView: View {
    @State var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            GamesLibraryView()
                .tabItem { Label("Games", systemImage: "list.bullet") }
                .tag(1)

            PuzzleHomeView()
                .tabItem { Label("Puzzles", systemImage: "puzzlepiece.extension") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
    }
}
