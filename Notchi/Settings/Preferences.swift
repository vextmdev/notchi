import Foundation

enum Preferences {
    static let hoverDelay = "hoverDelay"
    static let hapticsEnabled = "hapticsEnabled"
    static let showNowPlaying = "showNowPlaying"
    static let clipboardEnabled = "clipboardEnabled"
    static let clipboardLimit = "clipboardLimit"
    static let clipboardRemember = "clipboardRemember"

    static let theme = "theme"
    static let snowfallEnabled = "snowfallEnabled"
    static let snowAmount = "snowAmount"
    static let snowPlacement = "snowPlacement"
    static let windowSnowEnabled = "windowSnowEnabled"
    static let fairyLightsEnabled = "fairyLightsEnabled"
    static let snowPuffsEnabled = "snowPuffsEnabled"
    static let snowmanEnabled = "snowmanEnabled"

    // keep these in sync with the @AppStorage defaults in SettingsView
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            hoverDelay: 0.12,
            hapticsEnabled: true,
            showNowPlaying: true,
            clipboardEnabled: true,
            clipboardLimit: 30,
            clipboardRemember: true,

            theme: "off",
            snowfallEnabled: true,
            snowAmount: "light",
            snowPlacement: "everywhere",
            windowSnowEnabled: true,
            fairyLightsEnabled: true,
            snowPuffsEnabled: true,
            snowmanEnabled: true,
        ])
    }
}
