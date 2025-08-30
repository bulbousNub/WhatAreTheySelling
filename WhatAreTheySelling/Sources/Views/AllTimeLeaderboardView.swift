//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//


import SwiftUI

struct AllTimeLeaderboardView: View {
    @EnvironmentObject var store: DataStore

    var sortedPlayers: [Player] {
        store.players.sorted { $0.allTimeScore > $1.allTimeScore }
    }

    var body: some View {
        List {
            Section("Leaderboard (All-Time)") {
                if sortedPlayers.isEmpty {
                    Text("No players yet. Add players from Settings or Scorekeeper.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlayers) { p in
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text("\(p.allTimeScore)")
                                .bold()
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("All-Time Leaderboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Settings") { SettingsView() }
            }
        }
    }
}
