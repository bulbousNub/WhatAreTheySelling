import SwiftUI

struct MultiplayerGameView: View {
    @StateObject private var mpc = MPCManager.shared
    @State private var myCategory: String = ""

    var isHostJudge: Bool {
        guard let s = mpc.session else { return false }
        return s.judgeID == s.hostID && s.players.first(where: { $0.isHost }) != nil && mpc.isHost
    }

    var body: some View {
        List {
            Section("Round") {
                Text("Round \(mpc.session?.round ?? 1)")
            }

            if mpc.session?.status == .picking {
                Section("Pick your category (15s)") {
                    HStack {
                        TextField("Your category", text: $myCategory)
                            .textInputAutocapitalization(.words)
                        Button("Submit") {
                            // In a fuller build, track local player id persistently.
                            // For MVP, broadcast name-only; host reconciles by display name (ok locally).
                            if let me = mpc.session?.players.first(where: { $0.displayName == mpc.peerName }) {
                                mpc.send(.setCategory(playerID: me.id, category: myCategory))
                                myCategory = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Players") {
                ForEach(mpc.session?.players ?? []) { p in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(p.displayName + (p.isHost ? " (Judge)" : ""))
                            Spacer()
                            Text("\(p.sessionScore)").monospacedDigit()
                        }
                        if let cat = p.selectedCategory {
                            Text("Category: \(cat)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if isHostJudge && mpc.session?.status == .judging {
                Section("Judge Awards (60s)") {
                    ForEach(mpc.session?.players ?? []) { p in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Button("+3") {
                                mpc.send(.awardPoints(deltas: [p.id: 3]))
                            }
                            .buttonStyle(.borderedProminent)
                            Button("+1") {
                                mpc.send(.awardPoints(deltas: [p.id: 1]))
                            }
                            .buttonStyle(.bordered)
                            Button("Wild +5") {
                                mpc.send(.awardPoints(deltas: [p.id: 5]))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Button("End Round") {
                        mpc.send(.endRound(round: mpc.session?.round ?? 1))
                    }
                    .tint(.orange)
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Multiplayer Game")
    }
}

private extension MPCManager {
    var peerName: String { peerID.displayName }
}