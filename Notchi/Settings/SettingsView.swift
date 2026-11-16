import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var keepAwake: KeepAwake

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }

            StorageSettings(clipboard: clipboard, shelf: shelf)
                .tabItem { Label("Clipboard & Shelf", systemImage: "doc.on.clipboard") }

            TweakSettings(keepAwake: keepAwake)
                .tabItem { Label("Tweaks", systemImage: "wand.and.stars") }

            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 480)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(Preferences.hoverDelay) private var hoverDelay = 0.12
    @AppStorage(Preferences.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Preferences.showNowPlaying) private var showNowPlaying = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section("Notch") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Open delay")
                        Spacer()
                        Text("\(Int(hoverDelay * 1000)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $hoverDelay, in: 0...0.5, step: 0.02)
                }
                Toggle("Haptic feedback when opening", isOn: $hapticsEnabled)
                Toggle("Show now playing next to the notch", isOn: $showNowPlaying)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Notchi: could not change launch at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Clipboard & Shelf

private struct StorageSettings: View {
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var shelf: ShelfStore

    @AppStorage(Preferences.clipboardEnabled) private var clipboardEnabled = true
    @AppStorage(Preferences.clipboardLimit) private var clipboardLimit = 30

    var body: some View {
        Form {
            Section("Clipboard") {
                Toggle("Save clipboard history", isOn: $clipboardEnabled)

                Picker("Keep", selection: $clipboardLimit) {
                    ForEach([10, 30, 50, 100], id: \.self) { count in
                        Text("\(count) items").tag(count)
                    }
                }
                .disabled(!clipboardEnabled)

                LabeledContent("Saved items", value: "\(clipboard.items.count)")

                Button("Clear History") { clipboard.clearUnpinned() }
                    .disabled(clipboard.items.isEmpty)
            }

            Section {
                LabeledContent("Files on shelf", value: "\(shelf.items.count)")

                Button("Clear Shelf") { shelf.clear() }
                    .disabled(shelf.items.isEmpty)
            } header: {
                Text("Shelf")
            } footer: {
                Text("Pinned clipboard items are kept when you clear the history. Clearing the shelf never deletes the actual files.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tweaks

private struct TweakSettings: View {
    @ObservedObject var keepAwake: KeepAwake

    @State private var states: [String: Bool] = [:]
    @State private var screenshotFormat = "png"
    @State private var screenshotFolder = ""

    private let formats = [("PNG", "png"), ("JPEG", "jpg"), ("HEIC", "heic"), ("PDF", "pdf")]

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { keepAwake.isOn }, set: { keepAwake.setOn($0) })) {
                    TweakLabel(
                        title: "Keep Mac awake",
                        detail: "Stops the display from sleeping until you turn it off.",
                        symbol: "cup.and.saucer"
                    )
                }
            }

            Section("Finder & Dock") {
                ForEach(MacTweak.all) { tweak in
                    Toggle(isOn: binding(for: tweak)) {
                        TweakLabel(title: tweak.title, detail: tweak.detail, symbol: tweak.symbol)
                    }
                    .disabled(states[tweak.id] == nil)
                }
            }

            Section {
                Picker("Format", selection: formatBinding) {
                    ForEach(formats, id: \.1) { format in
                        Text(format.0).tag(format.1)
                    }
                }

                LabeledContent("Save to") {
                    HStack {
                        Text(screenshotFolder)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…", action: chooseScreenshotFolder)
                    }
                }
            } header: {
                Text("Screenshots")
            } footer: {
                Text("Tweaks change hidden macOS settings and restart Finder or the Dock to apply them. Turning a tweak off restores the macOS default.")
            }
        }
        .formStyle(.grouped)
        .task { await load() }
    }

    private func binding(for tweak: MacTweak) -> Binding<Bool> {
        Binding(
            get: { states[tweak.id] ?? false },
            set: { enabled in
                states[tweak.id] = enabled
                Task.detached { tweak.setEnabled(enabled) }
            }
        )
    }

    private var formatBinding: Binding<String> {
        Binding(
            get: { screenshotFormat },
            set: { format in
                screenshotFormat = format
                Task.detached {
                    Shell.writeDefault("com.apple.screencapture", "type", type: "string", value: format)
                    Shell.restart("SystemUIServer")
                }
            }
        )
    }

    private func chooseScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        screenshotFolder = (url.path as NSString).abbreviatingWithTildeInPath
        Task.detached {
            Shell.writeDefault("com.apple.screencapture", "location", type: "string", value: url.path)
            Shell.restart("SystemUIServer")
        }
    }

    // reading defaults spawns a process per key, so keep it off the main thread
    private func load() async {
        let loaded = await Task.detached { () -> ([String: Bool], String, String) in
            let states = Dictionary(uniqueKeysWithValues: MacTweak.all.map { ($0.id, $0.isEnabled) })
            let format = Shell.readDefault("com.apple.screencapture", "type") ?? "png"
            let folder = Shell.readDefault("com.apple.screencapture", "location") ?? "~/Desktop"
            return (states, format, folder)
        }.value

        states = loaded.0
        screenshotFormat = loaded.1
        screenshotFolder = (loaded.2 as NSString).abbreviatingWithTildeInPath
    }
}

private struct TweakLabel: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Notchi")
                .font(.title.bold())

            Text("Version \(version)")
                .foregroundStyle(.secondary)

            Text("Your MacBook notch, but useful.")
                .padding(.top, 4)

            Link("github.com/vextmdev/notchi", destination: URL(string: "https://github.com/vextmdev/notchi")!)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
