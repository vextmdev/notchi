import Foundation

// a hidden macOS setting that's normally only reachable with `defaults write`
struct MacTweak: Identifiable, Sendable {
    struct Value: Sendable {
        let domain: String
        let key: String
        let type: String
        let value: String
        let readsAs: String

        static func bool(_ domain: String, _ key: String, _ value: Bool) -> Value {
            Value(domain: domain, key: key, type: "bool", value: value ? "true" : "false", readsAs: value ? "1" : "0")
        }

        static func float(_ domain: String, _ key: String, _ value: String) -> Value {
            Value(domain: domain, key: key, type: "float", value: value, readsAs: value)
        }
    }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let values: [Value]
    let restarts: String?

    var isEnabled: Bool {
        values.allSatisfy { Shell.readDefault($0.domain, $0.key) == $0.readsAs }
    }

    // turning a tweak off deletes the keys, which puts macOS back to its default
    func setEnabled(_ enabled: Bool) {
        for value in values {
            if enabled {
                Shell.writeDefault(value.domain, value.key, type: value.type, value: value.value)
            } else {
                Shell.deleteDefault(value.domain, value.key)
            }
        }
        if let restarts {
            Shell.restart(restarts)
        }
    }
}

extension MacTweak {
    static let all: [MacTweak] = [
        MacTweak(
            id: "hideDesktopIcons",
            title: "Hide desktop icons",
            detail: "Clean desktop for screenshots and screen sharing.",
            symbol: "eye.slash",
            values: [.bool("com.apple.finder", "CreateDesktop", false)],
            restarts: "Finder"
        ),
        MacTweak(
            id: "showHiddenFiles",
            title: "Show hidden files",
            detail: "Show dotfiles like .gitignore in Finder.",
            symbol: "doc.badge.ellipsis",
            values: [.bool("com.apple.finder", "AppleShowAllFiles", true)],
            restarts: "Finder"
        ),
        MacTweak(
            id: "showExtensions",
            title: "Show all file extensions",
            detail: "Always show .pdf, .png and so on in Finder.",
            symbol: "textformat",
            values: [.bool("NSGlobalDomain", "AppleShowAllExtensions", true)],
            restarts: "Finder"
        ),
        MacTweak(
            id: "finderPathBar",
            title: "Finder path bar",
            detail: "Show the current folder path at the bottom of Finder windows.",
            symbol: "folder",
            values: [.bool("com.apple.finder", "ShowPathbar", true)],
            restarts: "Finder"
        ),
        MacTweak(
            id: "instantDock",
            title: "Instant Dock",
            detail: "No delay and a faster animation when the hidden Dock appears.",
            symbol: "dock.rectangle",
            values: [
                .float("com.apple.dock", "autohide-delay", "0"),
                .float("com.apple.dock", "autohide-time-modifier", "0.3"),
            ],
            restarts: "Dock"
        ),
        MacTweak(
            id: "noScreenshotShadow",
            title: "No window shadow in screenshots",
            detail: "Window screenshots (⇧⌘4, Space) without the big drop shadow.",
            symbol: "camera.viewfinder",
            values: [.bool("com.apple.screencapture", "disable-shadow", true)],
            restarts: "SystemUIServer"
        ),
    ]
}
