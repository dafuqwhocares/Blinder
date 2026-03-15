import SwiftUI

@main
struct BlinderApp: App {
    
    /// Legacy app delegate.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MainScene()
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuBarButton: MenuBarButton?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = BrandingIcon.makeAppIcon(pointSize: 512)
        menuBarButton = MenuBarButton()
    }
        
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
