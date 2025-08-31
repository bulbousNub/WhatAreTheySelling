import SwiftUI

struct JoinLobbyView: View {
    let displayName: String
    @State private var code: String = ""
    @StateObject private var mpc = MPCManager.shared

    private var me: MPPlayer {
        MPPlayer(id: UUID(), displayName: displayName, isHost: false, isConnected: true)
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter room code (e.g., 7KQ4)", text: $code)
                .textInputAutocapitalization(.characters)
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())
                .padding(.horizontal)

            Button("Join") {
                MPCManager.shared.configurePeer(displayName: displayName)
                MPCManager.shared.join(code: code.uppercased())
                // Send a join event once connected; for MVP, we fire shortly after
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    MPCManager.shared.send(.join(player: me))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)

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

            if (mpc.session?.status ?? .lobby) != .lobby {
                NavigationLink("Open In-Game View") { MultiplayerGameView() }
            }
        }
        .navigationTitle("Join Lobby")
    }
}