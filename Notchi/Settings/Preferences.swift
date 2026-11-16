import Foundation

enum Preferences {
    static let hoverDelay = "hoverDelay"
    static let hapticsEnabled = "hapticsEnabled"
    static let showNowPlaying = "showNowPlaying"
    static let clipboardEnabled = "clipboardEnabled"
    static let clipboardLimit = "clipboardLimit"

    // keep these in sync with the @AppStorage defaults in SettingsView
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            hoverDelay: 0.12,
            hapticsEnabled: true,
            showNowPlaying: true,
            clipboardEnabled: true,
            clipboardLimit: 30,
        ])
    }
}
