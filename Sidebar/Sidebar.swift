import SwiftUI

// You may see the error message:
//
// `onChange(of: Bool) action tried to update multiple times per frame.`
//
// It seems to be a SwiftUI bug, as it can be reproduced with a minimal list.

struct Sidebar: View {
    @Binding var selection: SidebarPane?
    
    var body: some View {
        List(selection: $selection) {
            GeneralSidebarSection()
        }
        .listStyle(SidebarListStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Sidebar_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar(selection: .constant(.rename))
    }
}
