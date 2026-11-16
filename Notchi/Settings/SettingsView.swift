import ServiceManagement
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case storage
    case tweaks
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: return "General"
        case .storage: return "Clipboard & Shelf"
        case .tweaks: return "Tweaks"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .storage: return "doc.on.clipboard.fill"
        case .tweaks: return "wand.and.stars"
        case .about: return "info"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .storage: return .blue
        case .tweaks: return .purple
        case .about: return .pink
        }
    }
}

struct SettingsView: View {
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var keepAwake: KeepAwake

    @State private var page: SettingsPage? = .general

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPage.allCases, selection: $page) { page in
                Label {
                    Text(page.title)
                } icon: {
                    SettingsIcon(symbol: page.symbol, color: page.color)
                }
                .tag(page)
            }
            .listStyle(.sidebar)
            .contentMargins(.top, 30, for: .scrollContent)
            .frame(width: 200)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text((page ?? .general).title)
                    .font(.title2.bold())
                    .padding(.horizontal, 28)
                    .padding(.top, 14)

                detail
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 520)
        // sidebar goes all the way up under the traffic lights
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder
    private var detail: some View {
        switch page ?? .general {
        case .general:
            GeneralSettings()
        case .storage:
            StorageSettings(clipboard: clipboard, shelf: shelf)
        case .tweaks:
            TweakSettings(keepAwake: keepAwake)
        case .about:
            AboutSettings()
        }
    }
}

// colored rounded square like in System Settings
private struct SettingsIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
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
                        symbol: "cup.and.saucer.fill",
                        color: .orange
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
    var color: Color = .indigo

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: symbol, color: color, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notchi")
                            .font(.title2.bold())
                        Text("Your MacBook notch, but useful.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Source code") {
                    Link("github.com/vextmdev/notchi", destination: URL(string: "https://github.com/vextmdev/notchi")!)
                }
                LabeledContent("License", value: "MIT")
            }
        }
        .formStyle(.grouped)
    }
}
