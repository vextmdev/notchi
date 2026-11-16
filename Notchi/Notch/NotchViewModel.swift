import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var notchSize = CGSize(width: 200, height: 32)

    let expandedSize = CGSize(width: 580, height: 190)
}
