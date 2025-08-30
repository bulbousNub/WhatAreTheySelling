//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import Foundation

struct GameEntry: Codable, Hashable {
    var playerName: String
    var score: Int
}

struct GameRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var start: Date
    var end: Date
    var rounds: Int
    var entries: [GameEntry]
    // Persist per-round breakdown (now with names in RoundEntry)
    var roundsDetail: [RoundSnapshot] = []

    private enum CodingKeys: String, CodingKey {
        case id, start, end, rounds, entries, roundsDetail, date
    }

    init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        rounds: Int,
        entries: [GameEntry],
        roundsDetail: [RoundSnapshot] = []
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.rounds = rounds
        self.entries = entries
        self.roundsDetail = roundsDetail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 0
        self.entries = try c.decodeIfPresent([GameEntry].self, forKey: .entries) ?? []
        self.roundsDetail = try c.decodeIfPresent([RoundSnapshot].self, forKey: .roundsDetail) ?? []

        if let s = try c.decodeIfPresent(Date.self, forKey: .start),
           let e = try c.decodeIfPresent(Date.self, forKey: .end) {
            self.start = s
            self.end = e
        } else {
            // Legacy fallback when only `date` existed
            let legacy = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
            self.start = legacy
            self.end = legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(start, forKey: .start)
        try c.encode(end, forKey: .end)
        try c.encode(rounds, forKey: .rounds)
        try c.encode(entries, forKey: .entries)
        try c.encode(roundsDetail, forKey: .roundsDetail)
    }
}
