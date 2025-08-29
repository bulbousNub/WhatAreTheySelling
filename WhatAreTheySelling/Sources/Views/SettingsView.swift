import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: DataStore

    // Appearance preference shared with App
    @AppStorage("appearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    // UI state
    @State private var newPlayerName: String = ""
    @State private var newCategory: String = ""
    @State private var showExporter = false
    @State private var showImporter = false

    // Confirmations
    @State private var showConfirmResetAllTime = false
    @State private var showConfirmClearRecent = false

    var body: some View {
        List {
            // Appearance
            Section {
                Picker("Theme", selection: $appearanceRaw) {
                    Text("Follow System").tag(AppAppearance.system.rawValue)
                    Text("Light").tag(AppAppearance.light.rawValue)
                    Text("Dark").tag(AppAppearance.dark.rawValue)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            // Game options
            Section {
                Toggle("Enable Fastest (+1) button", isOn: $store.enableBonusFastest)
                    .onChange(of: store.enableBonusFastest) { _, _ in
                        store.save()
                    }
                Toggle("Enable Wildcard (+5) button", isOn: $store.enableBonusWildcard)
                    .onChange(of: store.enableBonusWildcard) { _, _ in
                        store.save()
                    }
            } header: {
                Text("Game Options")
            }

            // Manage players
            Section {
                HStack {
                    TextField("New player name", text: $newPlayerName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    Button("Add") {
                        store.addPlayer(named: newPlayerName)
                        newPlayerName = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                ForEach(store.players) { p in
                    HStack {
                        Text(p.name)
                        Spacer()
                        if p.isActive {
                            if p.name.caseInsensitiveCompare("TeJay") != .orderedSame {
                                Button("Remove from Active") { store.setActive(p, false) }
                                    .buttonStyle(.bordered)
                            } else {
                                Text("(always active)").foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Reactivate") { store.setActive(p, true) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } header: {
                Text("Manage Players")
            }

            // Categories
            Section {
                HStack {
                    TextField("Add category", text: $newCategory)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    Button("Add") {
                        let trimmed = newCategory.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.categories.append(trimmed)
                        newCategory = ""
                        store.save()
                    }
                    .buttonStyle(.borderedProminent)
                }
                ForEach(store.categories, id: \.self) { cat in
                    Text(cat)
                }
                .onDelete { idx in
                    store.categories.remove(atOffsets: idx)
                    store.save()
                }
            } header: {
                Text("Edit Categories")
            }

            // Backup / Restore
            Section {
                Button("Export Backup to Files") { showExporter = true }
                Button("Import Backup from Files") { showImporter = true }
                    .tint(.purple)
            } header: {
                Text("Backup / Restore")
            } footer: {
                Text("Exports all app data — players, categories, scores, settings, and recent games — into a single JSON file. Importing restores everything from that file.")
            }

            // Dangerous actions (Clear before Reset)
            Section {
                Button(role: .destructive) {
                    showConfirmClearRecent = true
                } label: {
                    Text("Clear Recent Games")
                }

                Button(role: .destructive) {
                    showConfirmResetAllTime = true
                } label: {
                    Text("Reset All-Time Scores")
                }
            } footer: {
                Text("Clearing recent games removes the history list but does not affect all-time totals. Resetting scores sets every player's all-time score to 0 but does not delete players or categories.")
            }
        }
        .fileExporter(isPresented: $showExporter,
                      document: JSONDoc(url: store.exportJSON()!),
                      contentType: .json,
                      defaultFilename: "WATS_Data_Backup") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case let .success(url) = result {
                Task { try? await store.importJSON(from: url) }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Reset All-Time Scores?",
                            isPresented: $showConfirmResetAllTime,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) { store.resetAllTime() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This sets every player's all-time score to 0. Recent games remain intact.")
        }
        .confirmationDialog("Clear Recent Games?",
                            isPresented: $showConfirmClearRecent,
                            titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { store.clearRecentGames() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes the list of saved games (history). All-time scores are not changed.")
        }
    }
}

// Reuse your JSON export doc
struct JSONDoc: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var url: URL
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { self.url = URL(fileURLWithPath: "") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return .init(regularFileWithContents: data)
    }
}
