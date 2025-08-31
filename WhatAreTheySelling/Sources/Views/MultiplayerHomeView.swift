import SwiftUI

struct MultiplayerHomeView: View {
    @State private var displayName: String = UserDefaults.standard.string(forKey: "mpDisplayName") ?? "Player"
    @State private var code: String = String((0..<4).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section("Your Multiplayer Name") {
                    TextField("Display name", text: $displayName)
                        .onChange(of: displayName) { _, val in
                            UserDefaults.standard.setValue(val, forKey: "mpDisplayName")
                        }
                }

                Section {
                    NavigationLink("Host a Lobby (You’re Judge)") {
                        HostLobbyView(displayName: displayName, code: code)
                    }
                    NavigationLink("Join a Lobby") {
                        JoinLobbyView(displayName: displayName)
                    }
                }
            }
            .navigationTitle("Multiplayer (Local)")
        }
    }
}