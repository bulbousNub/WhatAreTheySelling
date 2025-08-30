//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import SwiftUI

struct RulesView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        List {
            Section("Objective") {
                Text("Guess the category of the next QVC segment before the product is revealed. Keep score as you play.")
            }

            Section("Setup") {
                Text("Agree on your categories (see the Categories screen). Players will shout guesses out loud — the app is just your scorekeeper.")
            }

            Section("How to Play") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1) When a new segment starts, each player quickly shouts their category guess.")
                    Text("2) Once the host reveals the product, determine the correct category.")
                    Text("3) Award points in the Scorekeeper (+3 default).")
                    Text("4) Tap End Round to increment rounds; tap End Game to finalize and save the game with date/time.")
                }
            }

            Section("Scoring") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Exact Match: +3 points (default button).")
                    Text("• Optional Bonuses (toggle in Settings):")
                    Text("   – Fastest: +1 (first correct guess before hints).")
                    Text("   – Wildcard: +5 (bizarre/miscellaneous item).")
                    Text("• You can also add +1 for partial credit when both players agree.")
                }
            }

            Section("Close Calls") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("If an item fits multiple categories, use the primary category shown on-screen or on QVC’s site.")
                    Text("House rule: award partial credit (+1) if everyone agrees the guess was close.")
                }
            }

            Section("Winning & Variations") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Play to a target (e.g., first to 15), or for a set number of rounds, or as long as you’re watching.")
                    Text("• Lightning Round: during special events, double all points.")
                    Text("• Category Draft: each player claims a few categories at the start; only the owner scores on those.")
                    Text("• Loser’s Tax: the night’s loser buys dessert (or a funny QVC item under $20).")
                }
            }
        }
        .navigationTitle("Rules & Scoring")
    }
}
