import AppKit

// no public now-playing API on macOS, so we talk to Spotify/Music directly
@MainActor
final class MediaController: ObservableObject {
    enum Player: String {
        case spotify
        case music

        var bundleID: String {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            }
        }

        var appName: String {
            switch self {
            case .spotify: return "Spotify"
            case .music: return "Music"
            }
        }
    }

    struct NowPlaying {
        let isPlaying: Bool
        let title: String
        let artist: String
        let artworkURL: URL?
    }

    @Published private(set) var activePlayer: Player?
    @Published private(set) var title: String?
    @Published private(set) var artist: String?
    @Published private(set) var artworkURL: URL?
    @Published private(set) var isPlaying = false

    private var timer: Timer?
    private let scriptQueue = DispatchQueue(label: "notchi.media.applescript")

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Reading

    func refresh() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        // don't launch players that aren't running
        let candidates = [Player.spotify, .music].filter { running.contains($0.bundleID) }

        guard !candidates.isEmpty else {
            apply(nil)
            return
        }

        scriptQueue.async {
            var best: (Player, NowPlaying)?
            for player in candidates {
                guard let info = Self.queryNowPlaying(player) else { continue }
                if info.isPlaying {
                    best = (player, info)
                    break
                }
                if best == nil { best = (player, info) }
            }
            let result = best
            Task { @MainActor [weak self] in self?.apply(result) }
        }
    }

    private func apply(_ result: (Player, NowPlaying)?) {
        guard let (player, info) = result else {
            activePlayer = nil
            title = nil
            artist = nil
            artworkURL = nil
            isPlaying = false
            return
        }
        activePlayer = player
        title = info.title
        artist = info.artist
        artworkURL = info.artworkURL
        isPlaying = info.isPlaying
    }

    nonisolated private static func queryNowPlaying(_ player: Player) -> NowPlaying? {
        let artworkLine = player == .spotify
            ? "set artURL to artwork url of current track"
            : "set artURL to \"\""

        let source = """
        tell application "\(player.appName)"
            if player state is stopped then return "stopped"
            set trackName to name of current track
            set trackArtist to artist of current track
            set stateText to player state as string
            \(artworkLine)
            return stateText & "|||" & trackName & "|||" & trackArtist & "|||" & artURL
        end tell
        """

        guard let output = runScript(source), output != "stopped" else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count == 4 else { return nil }

        return NowPlaying(
            isPlaying: parts[0] == "playing",
            title: parts[1],
            artist: parts[2],
            artworkURL: parts[3].isEmpty ? nil : URL(string: parts[3])
        )
    }

    @discardableResult
    nonisolated private static func runScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Notchi: AppleScript error: \(error)")
            return nil
        }
        return result?.stringValue
    }

    // MARK: - Controls

    func playPause() {
        isPlaying.toggle()
        send("playpause")
    }

    func next() { send("next track") }

    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let player = activePlayer else { return }
        let source = "tell application \"\(player.appName)\" to \(command)"
        scriptQueue.async {
            Self.runScript(source)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self?.refresh()
            }
        }
    }
}
