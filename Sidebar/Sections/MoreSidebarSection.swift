import SwiftUI

struct MoreSidebarSection: View {
    
    @Binding var selection: SidebarPane?
    
    var body: some View {
        EmptyView()
    }
}

struct MoreSidebarSection_Previews: PreviewProvider {
    static var previews: some View {
        MoreSidebarSection(selection: .constant(.rename))
    }
}
