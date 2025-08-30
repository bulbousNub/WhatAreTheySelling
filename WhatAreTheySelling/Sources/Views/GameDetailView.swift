//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import SwiftUI

struct GameDetailView: View {
    let game: GameRecord

    // Sort rounds ascending (1 → N). Flip if you prefer newest first.
    private var sortedRounds: [RoundSnapshot] {
        game.roundsDetail.sorted { $0.index < $1.index }
    }

    var body: some View {
        List {
            // Summary
            Section("Summary") {
                HStack {
                    Text("Start")
                    Spacer()
                    Text(dateTimeString(game.start)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("End")
                    Spacer()
                    Text(dateTimeString(game.end)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(durationString(from: game.start, to: game.end)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Rounds")
                    Spacer()
                    Text("\(game.rounds)").foregroundStyle(.secondary)
                }
            }

            // Totals
            Section("Final Totals") {
                ForEach(game.entries, id: \.playerName) { entry in
                    HStack {
                        Text(entry.playerName)
                        Spacer()
                        Text("\(entry.score)").monospacedDigit()
                    }
                }
            }

            // Round-by-round
            Section("Round Details") {
                if sortedRounds.isEmpty {
                    Text("No per-round details were saved for this game.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedRounds) { snap in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Round \(snap.index)")
                                .font(.subheadline.weight(.semibold))

                            let nonZero = snap.entries.filter { $0.delta != 0 }
                            if nonZero.isEmpty {
                                Text("No points awarded")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(nonZero, id: \.id) { entry in
                                    HStack {
                                        Text(entry.name) // <- accurate player names
                                        Spacer()
                                        Text("+\(entry.delta)").monospacedDigit()
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Game Details")
    }

    // MARK: - Helpers

    private func dateTimeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let sec = max(0, Int(end.timeIntervalSince(start)))
        let mins = sec / 60
        let hrs = mins / 60
        if hrs > 0 {
            let rem = mins % 60
            return "\(hrs)h \(rem)m"
        } else {
            return "\(mins)m"
        }
    }
}
