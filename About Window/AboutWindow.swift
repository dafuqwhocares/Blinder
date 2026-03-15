import AppKit
import SwiftUI

class AboutWindow: NSWindowController {
    
    static func show() {
        AboutWindow().window?.makeKeyAndOrderFront(nil)
    }

    convenience init() {
        
        let window = Self.makeWindow()
                
        window.backgroundColor = NSColor.controlBackgroundColor
                
        self.init(window: window)

        let contentView = makeAboutView()
            
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.title = "About Blinder App"
        window.contentView = NSHostingView(rootView: contentView)
        window.alwaysOnTop = true
    }
    
    private static func makeWindow() -> NSWindow {
        let contentRect = NSRect(x: 0, y: 0, width: 620, height: 300)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .fullSizeContentView
        ]
        return NSWindow(contentRect: contentRect,
                        styleMask: styleMask,
                        backing: .buffered,
                        defer: false)
    }

    private func makeAboutView() -> some View {
        AboutView(
            icon: BrandingIcon.makeAppIcon(pointSize: 128),
            name: Bundle.main.name,
            version: Bundle.main.version,
            build: Bundle.main.buildVersion,
            copyright: Bundle.main.copyright,
            developerName: "Dr. med. Ansgar Scheffold\nwww.ansgarscheffold.com\ninfo@ansgarscheffold.com")
            .frame(width: 620, height: 300)
    }
}
