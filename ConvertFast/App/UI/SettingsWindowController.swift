import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ConvertFast Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        // Create and set the SwiftUI view as the window's content view
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
        
        super.init(window: window)
    }
    
    convenience init() {
        self.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
} 
