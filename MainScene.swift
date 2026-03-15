import SwiftUI

struct MainScene: Scene {
    @StateObject private var blinderStore = BlinderStore()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(blinderStore)
                .frame(minWidth: 980, minHeight: 560)
                .background(AlwaysOnTop())
        }
        .commands {
            AboutCommand()
            SidebarCommands()
            ExportCommands()
            AlwaysOnTopCommand()
            
            // Remove the "New Window" option from the File menu.
            CommandGroup(replacing: .newItem, addition: { })
        }
        Settings {
            SettingsWindow()
                .environmentObject(blinderStore)
        }
    }
}
