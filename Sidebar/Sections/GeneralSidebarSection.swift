import SwiftUI

struct GeneralSidebarSection: View {
    var body: some View {
        Section {
            NavigationLink(value: SidebarPane.rename) {
                Label("Blind", systemImage: "text.cursor")
            }
            NavigationLink(value: SidebarPane.restore) {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
        }
    }
}

struct GeneralSidebarSection_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSidebarSection()
    }
}
