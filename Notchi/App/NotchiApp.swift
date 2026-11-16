import SwiftUI

@main
struct NotchiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // no main window, everything lives in the notch + menu bar
        Settings { EmptyView() }
    }
}
