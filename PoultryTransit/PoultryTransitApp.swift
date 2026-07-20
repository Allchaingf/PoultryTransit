//
//  PoultryTransitApp.swift
//  PoultryTransit
//
//  Offline poultry-transport workspace. No account, no auth — launches
//  straight into Splash → Onboarding (first run) → Main app.
//

import SwiftUI

@main
struct PoultryTransitApp: App {
    @StateObject private var store = FarmStore()
    @StateObject private var prefs = AppPreferences()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(prefs)
                .preferredColorScheme(prefs.theme.scheme)
                .accentColor(PT.primary)
        }
    }
}
