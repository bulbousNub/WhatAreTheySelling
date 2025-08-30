//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import Foundation
import SwiftUI

// MARK: - In-progress game snapshots

struct PlayerScore: Codable, Hashable {
    var id: UUID
    var score: Int
}

// Include player name so historical round details show correct names
struct RoundEntry: Codable, Hashable {
    var id: UUID         // player id
    var name: String     // player name at time of the round
    var delta: Int       // points earned this round

    private enum CodingKeys: String, CodingKey { case id, name, delta }

    init(id: UUID, name: String, delta: Int) {
        self.id = id
        self.name = name
        self.delta = delta
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.delta = try c.decode(Int.self, forKey: .delta)
        // Back-compat: old saves had no name
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Player"
    }
}

struct RoundSnapshot: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var index: Int       // 1-based round number
    var entries: [RoundEntry]
}

struct InProgressGame: Codable, Hashable {
    var participantIDs: [UUID]
    var scores: [PlayerScore]
    var round: Int
    var startedAt: Date
    var roundsDetail: [RoundSnapshot] // per-round breakdown

    private enum CodingKeys: String, CodingKey {
        case participantIDs, scores, round, startedAt, roundsDetail
    }

    init(participantIDs: [UUID],
         scores: [PlayerScore],
         round: Int,
         startedAt: Date,
         roundsDetail: [RoundSnapshot] = []) {
        self.participantIDs = participantIDs
        self.scores = scores
        self.round = round
        self.startedAt = startedAt
        self.roundsDetail = roundsDetail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.participantIDs = try c.decodeIfPresent([UUID].self, forKey: .participantIDs) ?? []
        self.scores = try c.decodeIfPresent([PlayerScore].self, forKey: .scores) ?? []
        self.round = try c.decodeIfPresent(Int.self, forKey: .round) ?? 1
        self.startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        self.roundsDetail = try c.decodeIfPresent([RoundSnapshot].self, forKey: .roundsDetail) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(participantIDs, forKey: .participantIDs)
        try c.encode(scores, forKey: .scores)
        try c.encode(round, forKey: .round)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(roundsDetail, forKey: .roundsDetail)
    }
}

// MARK: - DataStore

@MainActor
final class DataStore: ObservableObject {

    // Your primary user that should always exist and cannot be removed
    private let primaryUserName = "TeJay"

    // Players & Categories
    @Published var players: [Player] = [
        Player(name: "TeJay"),
        Player(name: "Shay")
    ]

    @Published var categories: [String] = [
        "Fashion (Clothing)","Shoes","Jewelry","Cosmetics / Skincare","Fragrance","Haircare / Styling Tools",
        "Handbags / Accessories","Home Décor","Kitchenware / Cookware","Small Appliances","Bedding / Linens",
        "Electronics / Tech Gadgets","Fitness / Wellness","Food & Gourmet Treats","Holiday / Seasonal Items",
        "Cleaning Supplies","Outdoor / Garden","Crafts / Hobbies","Pets","Misc / As Seen on TV"
    ]

    // Game history (finished games)
    @Published var games: [GameRecord] = []

    // In-progress game (persisted so you can navigate away & resume later)
    @Published var inProgress: InProgressGame?

    // Settings toggles
    @Published var enableBonusFastest: Bool = true
    @Published var enableBonusWildcard: Bool = true

    // MARK: - Persistence (single JSON file in Documents)

    private let fileName = "WATS_Data.json"
    private var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    struct PersistBlob: Codable {
        var players: [Player]
        var categories: [String]
        var games: [GameRecord]
        var enableBonusFastest: Bool
        var enableBonusWildcard: Bool
        var inProgress: InProgressGame?
    }

    init() { load() }

    func load() {
        do {
            let data = try Data(contentsOf: url)
            let blob = try JSONDecoder().decode(PersistBlob.self, from: data)
            self.players = blob.players
            self.categories = blob.categories
            self.games = blob.games
            self.enableBonusFastest = blob.enableBonusFastest
            self.enableBonusWildcard = blob.enableBonusWildcard
            self.inProgress = blob.inProgress
        } catch {
            // First run: keep defaults
        }
        // Ensure TeJay exists / migrate legacy "You" → "TeJay"
        migrateYouToPrimary()
        ensurePrimaryExists()
        save()
    }

    func save() {
        do {
            let blob = PersistBlob(
                players: players,
                categories: categories,
                games: games,
                enableBonusFastest: enableBonusFastest,
                enableBonusWildcard: enableBonusWildcard,
                inProgress: inProgress
            )
            let data = try JSONEncoder().encode(blob)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Save error: \(error)")
        }
    }

    // MARK: - Migration / Guards

    private func migrateYouToPrimary() {
        // If a player literally named "You" exists, rename or merge into "TeJay"
        if let youIdx = players.firstIndex(where: { $0.name == "You" }) {
            if let tjIdx = players.firstIndex(where: { $0.name.caseInsensitiveCompare(primaryUserName) == .orderedSame }) {
                players[tjIdx].allTimeScore += players[youIdx].allTimeScore
                players[tjIdx].isActive = players[tjIdx].isActive || players[youIdx].isActive
                players.remove(at: youIdx)
            } else {
                players[youIdx].name = primaryUserName
            }
        }
    }

    private func ensurePrimaryExists() {
        if !players.contains(where: { $0.name.caseInsensitiveCompare(primaryUserName) == .orderedSame }) {
            players.append(Player(name: primaryUserName))
        }
    }

    // MARK: - Players

    func addPlayer(named name: String) {
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Normalize any attempt to add "You" → TeJay
        if clean.caseInsensitiveCompare("You") == .orderedSame {
            clean = primaryUserName
        }

        if let idx = players.firstIndex(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
            players[idx].isActive = true
        } else {
            players.append(Player(name: clean))
        }
        save()
    }

    /// Toggle a player's active flag (TeJay is always active/undeletable)
    func setActive(_ player: Player, _ active: Bool) {
        if player.name.caseInsensitiveCompare(primaryUserName) == .orderedSame { return }
        if let idx = players.firstIndex(of: player) {
            players[idx].isActive = active
            save()
        }
    }

    /// Soft remove (mark inactive). TeJay cannot be removed.
    func removePlayer(_ player: Player) {
        if player.name.caseInsensitiveCompare(primaryUserName) == .orderedSame { return }
        if let idx = players.firstIndex(of: player) {
            players[idx].isActive = false
            save()
        }
    }

    func addPoints(_ points: Int, to player: Player) {
        guard let idx = players.firstIndex(of: player) else { return }
        players[idx].allTimeScore += points
        save()
    }

    func resetAllTime() {
        for i in players.indices { players[i].allTimeScore = 0 }
        save()
    }

    // MARK: - Games

    func addGame(_ record: GameRecord) {
        games.insert(record, at: 0) // newest first
        save()
    }

    /// Clear the entire recent games list (history), keeps players/leaderboard intact.
    func clearRecentGames() {
        games.removeAll()
        save()
    }

    // MARK: - In-Progress helpers

    /// Persist a snapshot of the current game so leaving the screen/app won’t lose it.
    func updateInProgress(participants: [Player],
                          sessionScores: [UUID: Int],
                          round: Int,
                          startedAt: Date,
                          roundsDetail: [RoundSnapshot]) {
        let ids = participants.map { $0.id }
        let scores = ids.map { PlayerScore(id: $0, score: sessionScores[$0] ?? 0) }
        self.inProgress = InProgressGame(
            participantIDs: ids,
            scores: scores,
            round: round,
            startedAt: startedAt,
            roundsDetail: roundsDetail
        )
        save()
    }

    /// Clear snapshot after End Game.
    func clearInProgress() {
        self.inProgress = nil
        save()
    }

    // MARK: - Backup / Restore

    func exportJSON() -> URL? { url }

    func importJSON(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let blob = try JSONDecoder().decode(PersistBlob.self, from: data)
        self.players = blob.players
        self.categories = blob.categories
        self.games = blob.games
        self.enableBonusFastest = blob.enableBonusFastest
        self.enableBonusWildcard = blob.enableBonusWildcard
        self.inProgress = blob.inProgress

        // Re-run safety checks after import
        migrateYouToPrimary()
        ensurePrimaryExists()
        save()
    }
}
