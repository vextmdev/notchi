import Foundation
import IOKit.pwr_mgt

// same idea as `caffeinate -d`, the display won't sleep while this is on
@MainActor
final class KeepAwake: ObservableObject {
    @Published private(set) var isOn = false

    private var assertionID: IOPMAssertionID = 0

    func setOn(_ on: Bool) {
        on ? start() : stop()
    }

    func toggle() {
        setOn(!isOn)
    }

    private func start() {
        guard !isOn else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Notchi keep awake" as CFString,
            &assertionID
        )
        isOn = result == kIOReturnSuccess
    }

    private func stop() {
        guard isOn else { return }
        IOPMAssertionRelease(assertionID)
        isOn = false
    }
}
