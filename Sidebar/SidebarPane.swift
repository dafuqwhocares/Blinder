import Foundation

enum SidebarPane {
    case rename
    case restore
}

// MARK: - Protocol Conformances

extension SidebarPane: Equatable, Identifiable {
    var id: Self { self }
}
