import SwiftUI

struct RecentGamesView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        List {
            if store.games.isEmpty {
                Text("No games yet. Play a game to see it here.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Recent Games") {
                    ForEach(store.games.prefix(50)) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            // Align label to the top and add slight bottom padding
                            // so the system chevron feels a touch higher visually.
                            VStack(alignment: .leading, spacing: 6) {
                                Text(dateTimeString(game.start))
                                    .font(.subheadline)
                                Text("Rounds: \(game.rounds)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Totals summary inline
                                ForEach(game.entries, id: \.playerName) { entry in
                                    HStack {
                                        Text(entry.playerName)
                                        Spacer()
                                        Text("\(entry.score)").monospacedDigit()
                                    }
                                    .font(.caption)
                                }
                            }
                            .padding(.bottom, 6) // <- subtle shift to give chevron more breathing room
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recent Games")
    }

    private func dateTimeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
