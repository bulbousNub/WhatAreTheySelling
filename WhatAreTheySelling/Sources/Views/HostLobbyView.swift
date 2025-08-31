import SwiftUI

struct HostLobbyView: View {
    let displayName: String
    let code: String

    @StateObject private var mpc = MPCManager.shared
    @Environment(\.dismiss) private var dismiss

    private var me: MPPlayer {
        MPPlayer(id: UUID(), displayName: displayName, isHost: true, isConnected: true)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Room Code")
                .font(.headline)
            Text(code).font(.system(size: 36, weight: .bold, design: .rounded))
                .monospaced()

            List {
                Section("Players") {
                    ForEach(mpc.session?.players ?? []) { p in
                        HStack {
                            Text(p.displayName)
                            if p.isHost { Text(" (Host/Judge)").foregroundStyle(.secondary) }
                            Spacer()
                            Text("\(p.sessionScore)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Button("Start 15s Category Timer") {
                    let deadline = Date().addingTimeInterval(15)
                    mpc.send(.startPicking(round: (mpc.session?.round ?? 1), pickDeadline: deadline))
                }
                .buttonStyle(.bordered)

                Button("Start 60s Judge Timer") {
                    let deadline = Date().addingTimeInterval(60)
                    mpc.send(.startJudging(round: (mpc.session?.round ?? 1), judgeDeadline: deadline))
                }
                .buttonStyle(.borderedProminent)
            }

            NavigationLink("Open In-Game View") {
                MultiplayerGameView()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Host Lobby")
        .onAppear {
            MPCManager.shared.configurePeer(displayName: displayName)
            MPCManager.shared.host(code: code.uppercased(), me: me)
        }
        .onDisappear { MPCManager.shared.stop() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}