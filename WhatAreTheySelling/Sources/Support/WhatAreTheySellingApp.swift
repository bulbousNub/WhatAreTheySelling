//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@main
struct WhatAreTheySellingApp: App {
    @StateObject private var store = DataStore()

    // Persisted user preference for appearance (defaults to "system")
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    private var appAppearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(appAppearance.colorScheme) // follows system unless Light/Dark forced in Settings
        }
    }
}
