import AppKit

enum Theme: String, CaseIterable, Identifiable {
    case off
    case snow
    case christmas

    var id: Self { self }

    var title: String {
        switch self {
        case .off: return "Off"
        case .snow: return "Snow"
        case .christmas: return "Christmas"
        }
    }

    var symbol: String {
        switch self {
        case .off: return "circle.slash"
        case .snow: return "snowflake"
        case .christmas: return "gift.fill"
        }
    }
}

enum SnowAmount: String, CaseIterable, Identifiable {
    case light
    case medium
    case heavy

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var birthRate: Float {
        switch self {
        case .light: return 12
        case .medium: return 26
        case .heavy: return 55
        }
    }
}

enum SnowPlacement: String, CaseIterable, Identifiable {
    case everywhere
    case desktop

    var id: Self { self }

    var title: String {
        switch self {
        case .desktop: return "Behind windows"
        case .everywhere: return "Over everything"
        }
    }
}

// everything the theme effects depend on, so we only rebuild when something actually changed
struct ThemeConfig: Equatable {
    var theme: Theme
    var snowfall: Bool
    var amount: SnowAmount
    var placement: SnowPlacement
    var windowSnow: Bool
    var decorations: Bool
    var fairyLights: Bool
    var puffs: Bool
    var reduceMotion: Bool
    var lowPower: Bool

    var isFestive: Bool { theme == .christmas }
    var showsSnowfall: Bool { theme != .off && snowfall && !reduceMotion }
    // keep it light on battery saver instead of turning it off
    var effectiveAmount: SnowAmount { lowPower ? .light : amount }
    var showsWindowSnow: Bool { theme != .off && windowSnow }
    var showsLights: Bool { theme == .christmas && fairyLights }
    var showsPuffs: Bool { theme != .off && puffs && !reduceMotion }

    static var current: ThemeConfig {
        let defaults = UserDefaults.standard
        return ThemeConfig(
            theme: Theme(rawValue: defaults.string(forKey: Preferences.theme) ?? "") ?? .off,
            snowfall: defaults.bool(forKey: Preferences.snowfallEnabled),
            amount: SnowAmount(rawValue: defaults.string(forKey: Preferences.snowAmount) ?? "") ?? .light,
            placement: SnowPlacement(rawValue: defaults.string(forKey: Preferences.snowPlacement) ?? "") ?? .everywhere,
            windowSnow: defaults.bool(forKey: Preferences.windowSnowEnabled),
            decorations: defaults.bool(forKey: Preferences.snowmanEnabled),
            fairyLights: defaults.bool(forKey: Preferences.fairyLightsEnabled),
            puffs: defaults.bool(forKey: Preferences.snowPuffsEnabled),
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
