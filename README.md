<div align="center">

# Notchi

**Your MacBook notch, but useful.**
Hover over the notch for your clipboard history, a file shelf and music controls.

<!-- TODO: demo gif -->
<!-- ![Notchi demo](docs/demo.gif) -->

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

</div>

## Features

- **Hover to open**: move your mouse to the notch and it smoothly expands. Move away and it tucks back in.
- **Clipboard history**: the last 30 things you copied (text and images). Click to copy again, search, pin favorites.
- **File shelf**: drag files onto the notch to park them there, then drag them out wherever you need them. Click for Quick Look.
- **Respects passwords**: items marked as concealed by password managers are never recorded.
- **Media controls**: see what's playing in Spotify or Apple Music, with artwork, play/pause and skip.
- **Lightweight**: native Swift, no Electron, no tracking, nothing leaves your Mac.
- Works on Macs without a notch too (shows a small pill at the top of the screen).

## Install

Prebuilt releases are coming soon. For now, build from source:

```bash
brew install xcodegen
git clone https://github.com/vextmdev/notchi.git
cd notchi
xcodegen generate
open Notchi.xcodeproj
```

Then press **Run** (⌘R) in Xcode.

## Permissions

| Permission | Why |
|---|---|
| Automation (Spotify / Music) | To show the current track and control playback. macOS asks the first time. |
| Clipboard | To build the history. Newer macOS versions may ask before apps read the clipboard. |

## Roadmap

- [ ] Prebuilt, notarized releases + Homebrew cask
- [x] File shelf
- [ ] More media sources (browsers, other players)
- [ ] Settings window (history size, hover delay, which widgets to show)
- [ ] Calendar and battery widgets

## Contributing

Issues and pull requests are welcome. The Xcode project is generated from `project.yml`, so add new files under `Notchi/` and run `xcodegen generate` again.

## License

[MIT](LICENSE)
