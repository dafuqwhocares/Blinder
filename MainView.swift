import SwiftUI

struct MainView: View {
    @State private var selection: SidebarPane? = .rename
    
    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
        } detail: {
            switch selection ?? .rename {
            case .rename:
                RenamePane()
            case .restore:
                RestorePane()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(BlinderStore())
    }
}
