import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    var hasInProgress: Bool { store.inProgress != nil }

    // MARK: - Ticker Content
    private let tickerItems: [TickerItem] = [
        .init(title: "Goal", detail: "Guess what the hosts are selling based on the live segment."),
        .init(title: "Setup", detail: "Pick your players. Everyone shouts a category before the segment starts."),
        .init(title: "Default Score", detail: "+3 points for a correct category guess."),
        .init(title: "Fastest Bonus", detail: "+1 point for the first correct guess (optional in Settings)."),
        .init(title: "Wildcard Bonus", detail: "+5 points for a bold/funny spot-on guess (optional in Settings)."),
        .init(title: "Rounds", detail: "Play in rounds. Tap End Round to snapshot who scored."),
        .init(title: "End Game", detail: "Tap End Game to save totals to Recent Games and update the All-Time Leaderboard."),
        .init(title: "Fair Play", detail: "No pausing live TV. Majority rules on disputes.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack {
                    Spacer(minLength: 20)

                    VStack(spacing: 36) {
                        // MARK: Title (two lines, centered)
                        Text("What are they\nSelling?")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding(.horizontal, 24)

                        // MARK: Menu
                        VStack(spacing: 16) {
                            MenuLink(
                                label: hasInProgress ? "▶️ Resume Game" : "🎮 Start New Game",
                                destination: AnyView(GameView())
                            )

                            MenuLink(label: "📦 Categories",
                                     destination: AnyView(CategoriesView()))

                            MenuLink(label: "🏆 All-Time Leaderboard",
                                     destination: AnyView(AllTimeLeaderboardView()))

                            MenuLink(label: "🕑 Recent Games",
                                     destination: AnyView(RecentGamesView()))

                            MenuLink(label: "📖 Rules & Scoring",
                                     destination: AnyView(RulesView()))

                            MenuLink(label: "⚙️ Settings",
                                     destination: AnyView(SettingsView()))
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 20)

                    // MARK: Rules & Scoring Ticker
                    RulesTicker(items: tickerItems, fixedHeight: 116)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: 700)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Large Menu Card Link

private struct MenuLink: View {
    let label: String
    let destination: AnyView

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink {
            destination
                .toolbar(.automatic, for: .navigationBar)
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .opacity(0.4)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Ticker Models

private struct TickerItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

// MARK: - Rules & Scoring Auto-Rotating Ticker
// Fixed height; content vertically centered; page dots at bottom;
// Clipped to rounded shape so transitions don’t bleed outside the border.

private struct RulesTicker: View {
    let items: [TickerItem]
    let fixedHeight: CGFloat

    @State private var index: Int = 0
    @State private var timerCancellable: AnyCancellable?

    private let interval: TimeInterval = 4.0
    private let animation = Animation.spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .imageScale(.medium)
                    .opacity(0.8)
                Text("Rules & Scoring")
                    .font(.headline)
                Spacer()
            }

            // Content
            ZStack {
                if items.indices.contains(index) {
                    let item = items[index]
                    VStack(alignment: .center, spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(item.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(item.id)
                }
            }
            .frame(height: fixedHeight, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // fix bleed
            .overlay(
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        Circle()
                            .frame(width: 6, height: 6)
                            .opacity(i == index ? 0.9 : 0.25)
                    }
                }
                .padding(.bottom, 8),
                alignment: .bottom
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.06))
        )
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onTapGesture { advance() }
        .animation(animation, value: index)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rules and Scoring")
        .accessibilityValue(items.indices.contains(index) ? "\(items[index].title). \(items[index].detail)" : "")
    }

    private func startTimer() {
        stopTimer()
        guard !items.isEmpty else { return }
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in advance() }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func advance() {
        guard !items.isEmpty else { return }
        withAnimation(animation) {
            index = (index + 1) % items.count
        }
    }
}
