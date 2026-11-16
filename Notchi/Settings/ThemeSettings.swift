import AppKit
import SwiftUI

struct ThemeSettings: View {
    @AppStorage(Preferences.theme) private var theme: Theme = .off
    @AppStorage(Preferences.snowfallEnabled) private var snowfall = true
    @AppStorage(Preferences.snowAmount) private var amount: SnowAmount = .light
    @AppStorage(Preferences.snowPlacement) private var placement: SnowPlacement = .everywhere
    @AppStorage(Preferences.windowSnowEnabled) private var windowSnow = true
    @AppStorage(Preferences.snowmanEnabled) private var snowman = true
    @AppStorage(Preferences.fairyLightsEnabled) private var fairyLights = true
    @AppStorage(Preferences.snowPuffsEnabled) private var puffs = true

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ForEach(Theme.allCases) { item in
                        ThemeCard(theme: item, isSelected: theme == item) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { theme = item }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Falling snow", isOn: $snowfall)

                Picker("Amount", selection: $amount) {
                    ForEach(SnowAmount.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(!snowfall)

                Picker("Snow falls", selection: $placement) {
                    ForEach(SnowPlacement.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!snowfall)
            } header: {
                Text("Snowfall")
            } footer: {
                if reduceMotion {
                    Label("Falling snow is paused because Reduce Motion is on in System Settings → Accessibility → Display.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Text("In Low Power Mode the snow switches to Light to save battery.")
                }
            }
            .disabled(theme == .off)

            Section("Winter fun") {
                Toggle("Snow settles on top of windows", isOn: $windowSnow)
                Toggle("Snowman and rolling snowballs", isOn: $snowman)
                    .disabled(!windowSnow)
                Toggle("Snow puffs from the menu bar and notch", isOn: $puffs)
            }
            .disabled(theme == .off)

            Section {
                Toggle("Fairy lights under the menu bar", isOn: $fairyLights)
            } header: {
                Text("Christmas")
            } footer: {
                Text("The Christmas theme also gives the snowman a Santa hat and adds colorful sparkles to the snow puffs.")
            }
            .disabled(theme != .christmas)
        }
        .formStyle(.grouped)
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .frame(height: 64)
                    .overlay(
                        Image(systemName: theme.symbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .scaleEffect(isSelected ? 1.15 : 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .scaleEffect(isHovered && !isSelected ? 1.03 : 1)

                Text(theme.title)
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var background: LinearGradient {
        let colors: [Color]
        switch theme {
        case .off:
            colors = [Color.gray.opacity(0.6), Color.gray.opacity(0.35)]
        case .snow:
            colors = [Color(red: 0.4, green: 0.65, blue: 0.95), Color(red: 0.15, green: 0.3, blue: 0.6)]
        case .christmas:
            colors = [Color(red: 0.8, green: 0.15, blue: 0.2), Color(red: 0.1, green: 0.45, blue: 0.25)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
