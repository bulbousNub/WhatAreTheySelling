//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import SwiftUI

struct GameView: View {
    @EnvironmentObject var store: DataStore

    // Current game (session-only UI state)
    @State private var participants: [Player] = []
    @State private var sessionScores: [UUID: Int] = [:]
    @State private var round: Int = 1
    @State private var startedAt: Date = Date()

    // Per-round tracking
    @State private var roundsDetail: [RoundSnapshot] = []         // history of completed rounds
    @State private var currentRoundDeltas: [UUID: Int] = [:]      // points earned this (active) round

    // Manage-players sheet
    @State private var showingManagePlayers = false
    @State private var pendingSelection: Set<UUID> = []
    @State private var newPlayerName: String = ""

    // Buttons
    private let defaultPoints = 3
    private let fastestBonus = 1
    private let wildcardBonus = 5

    var body: some View {
        List {
            // Header: round + start time
            Section {
                HStack {
                    Text("Round \(round)")
                        .font(.headline)
                    Spacer()
                    if !participants.isEmpty {
                        Button("End Round") {
                            commitCurrentRound()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                HStack {
                    Text("Started:")
                    Text(dateTimeString(startedAt))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            // Empty state
            if participants.isEmpty {
                Section {
                    Text("No players in this game yet.")
                        .foregroundStyle(.secondary)
                    Text("Tap the “Players” button above to add people to this game.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Players & scoring
                Section("Players (Session)") {
                    ForEach(participants) { p in
                        playerRow(for: p)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            let pid = participants[i].id
                            sessionScores[pid] = nil
                            currentRoundDeltas[pid] = nil
                        }
                        participants.remove(atOffsets: indexSet)
                        pendingSelection = Set(participants.map { $0.id })
                        persist()
                    }
                }

                // Rounds history (this game only) — newest first
                if !roundsDetail.isEmpty {
                    Section("Rounds") {
                        ForEach(roundsDetail.sorted(by: { $0.index > $1.index })) { snap in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Round \(snap.index)")
                                    .font(.subheadline)
                                // Show only players who scored in that round
                                ForEach(snap.entries.filter { $0.delta != 0 }, id: \.id) { entry in
                                    HStack {
                                        Text(entry.name)
                                        Spacer()
                                        Text("+\(entry.delta)").monospacedDigit()
                                    }
                                    .font(.caption)
                                }
                                // If nobody scored that round, show a hint
                                if snap.entries.allSatisfy({ $0.delta == 0 }) {
                                    Text("No points awarded")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Footer actions
                Section {
                    HStack {
                        Button("Reset Session") {
                            // Reset all session & round data, but keep participants
                            for pid in sessionScores.keys { sessionScores[pid] = 0 }
                            currentRoundDeltas = [:]
                            roundsDetail = []
                            round = 1
                            startedAt = Date()
                            persist()
                        }
                        .tint(.gray)
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("End Game") {
                            // If there are uncommitted deltas this round, roll them in as a final round
                            if currentRoundDeltas.values.contains(where: { $0 != 0 }) {
                                commitCurrentRound()
                            }
                            applySessionToAllTimeAndSaveGame()
                            // Clear in-progress and reset UI
                            store.clearInProgress()
                            for pid in sessionScores.keys { sessionScores[pid] = 0 }
                            currentRoundDeltas = [:]
                            roundsDetail = []
                            round = 1
                            startedAt = Date()
                        }
                        .tint(.orange)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Scorekeeper")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Players") {
                    pendingSelection = Set(participants.map { $0.id })
                    newPlayerName = ""
                    showingManagePlayers = true
                }
            }
        }
        .sheet(isPresented: $showingManagePlayers) {
            ManagePlayersSheet(
                players: store.players,
                pendingSelection: $pendingSelection,
                newPlayerName: $newPlayerName,
                onAddPlayer: { name in
                    store.addPlayer(named: name) // persist new player
                    if let p = store.players.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                        pendingSelection.insert(p.id) // include in this game now
                    }
                },
                onDone: {
                    // Apply selection to this game (doesn't change isActive flags)
                    participants = store.players.filter { pendingSelection.contains($0.id) }
                    let ids = Set(participants.map { $0.id })
                    for p in participants {
                        if sessionScores[p.id] == nil { sessionScores[p.id] = 0 }
                        if currentRoundDeltas[p.id] == nil { currentRoundDeltas[p.id] = 0 }
                    }
                    // Prune removed players from maps
                    for key in sessionScores.keys where !ids.contains(key) { sessionScores[key] = nil }
                    for key in currentRoundDeltas.keys where !ids.contains(key) { currentRoundDeltas[key] = nil }
                    showingManagePlayers = false
                    persist()
                },
                onCancel: { showingManagePlayers = false }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear(perform: restoreOrSeed)
    }

    // MARK: - Player row

    @ViewBuilder
    private func playerRow(for p: Player) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.body)
                    Text("All-Time: \(p.allTimeScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Session: \(sessionScores[p.id, default: 0])")
                        .monospacedDigit()
                        .font(.callout)
                    // Show +X earned so far in THIS round
                    let delta = currentRoundDeltas[p.id, default: 0]
                    if delta != 0 {
                        Text("This round: +\(delta)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Compact pill buttons in a horizontal scroller
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill("+\(defaultPoints)", prominent: true) { add(defaultPoints, to: p) }
                    pill("+1") { add(1, to: p) }
                    if store.enableBonusFastest {
                        pill("Fast +\(fastestBonus)") { add(fastestBonus, to: p) }
                    }
                    if store.enableBonusWildcard {
                        pill("Wild +\(wildcardBonus)") { add(wildcardBonus, to: p) }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func restoreOrSeed() {
        if let ip = store.inProgress {
            // Restore from persisted snapshot
            let idSet = Set(ip.participantIDs)
            let scoreMap = Dictionary(uniqueKeysWithValues: ip.scores.map { ($0.id, $0.score) })
            let existing = store.players.filter { idSet.contains($0.id) }

            participants = existing
            sessionScores = scoreMap
            round = max(1, ip.round)
            startedAt = ip.startedAt
            roundsDetail = ip.roundsDetail

            // Ensure deltas map has keys for current participants
            currentRoundDeltas = [:]
            for p in participants { currentRoundDeltas[p.id] = 0 }

            // Drop scores for players that no longer exist
            let ids = Set(existing.map { $0.id })
            for key in sessionScores.keys where !ids.contains(key) { sessionScores[key] = nil }
        } else {
            // Seed from active roster for a new game
            let actives = store.players.filter { $0.isActive }
            participants = actives
            for p in actives {
                if sessionScores[p.id] == nil { sessionScores[p.id] = 0 }
                currentRoundDeltas[p.id] = 0
            }
            round = 1
            startedAt = Date()
            roundsDetail = []
            persist()
        }
    }

    private func persist() {
        store.updateInProgress(
            participants: participants,
            sessionScores: sessionScores,
            round: round,
            startedAt: startedAt,
            roundsDetail: roundsDetail
        )
    }

    private func add(_ points: Int, to player: Player) {
        sessionScores[player.id, default: 0] += points
        currentRoundDeltas[player.id, default: 0] += points
        if sessionScores[player.id, default: 0] < 0 { sessionScores[player.id] = 0 }
        persist()
    }

    private func commitCurrentRound() {
        // Snapshot current round deltas into history (capture names now)
        let entries = participants.map { p in
            RoundEntry(id: p.id, name: p.name, delta: currentRoundDeltas[p.id, default: 0])
        }
        let snap = RoundSnapshot(index: round, entries: entries)
        roundsDetail.append(snap)

        // Prepare for next round
        round += 1
        currentRoundDeltas = [:]
        for p in participants { currentRoundDeltas[p.id] = 0 }

        persist()
    }

    private func applySessionToAllTimeAndSaveGame() {
        let entries: [GameEntry] = participants.map {
            GameEntry(playerName: $0.name, score: sessionScores[$0.id, default: 0])
        }
        let record = GameRecord(
            start: startedAt,
            end: Date(),
            rounds: max(1, round - 1),
            entries: entries,
            roundsDetail: roundsDetail // persist per-round breakdown with names
        )
        store.addGame(record)

        for p in participants {
            let delta = sessionScores[p.id, default: 0]
            if delta != 0 { store.addPoints(delta, to: p) }
        }
    }

    private func dateTimeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - Compact pill button helper

@ViewBuilder
func pill(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
    let btn = Button(title, action: action)
        .font(.caption)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: true)
        .controlSize(.small)
        .buttonBorderShape(.capsule)
    if prominent {
        btn.buttonStyle(.borderedProminent)
    } else {
        btn.buttonStyle(.bordered)
    }
}

// MARK: - Manage Players Sheet

private struct ManagePlayersSheet: View {
    let players: [Player]
    @Binding var pendingSelection: Set<UUID>
    @Binding var newPlayerName: String

    var onAddPlayer: (String) -> Void
    var onDone: () -> Void
    var onCancel: () -> Void

    @State private var showInactive: Bool = false

    var visiblePlayers: [Player] {
        let source = showInactive ? players : players.filter { $0.isActive }
        return source.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Add New Player") {
                    HStack {
                        TextField("Player name", text: $newPlayerName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                        Button("Add") {
                            let name = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            onAddPlayer(name)
                            newPlayerName = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section {
                    Toggle("Show inactive players", isOn: $showInactive)
                }

                Section("Include in This Game") {
                    ForEach(visiblePlayers) { p in
                        Toggle(isOn: Binding(
                            get: { pendingSelection.contains(p.id) },
                            set: { isOn in
                                if isOn { pendingSelection.insert(p.id) }
                                else { pendingSelection.remove(p.id) }
                            }
                        )) {
                            HStack {
                                Text(p.name)
                                if !p.isActive { Text("(inactive)").foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Players")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
