import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    // Gemini + capture instances
    let gemini = GeminiClient()
    let capture = ScreenshotCapture()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create the menu-bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "MyIcon") ??
                           NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            button.action = #selector(togglePopover)
        }

        // Hook up screenshot → Gemini pipeline
        capture.onFrameCaptured = { [weak self] base64Image in
            let payload: [String: Any] = [
                "realtime_input": [
                    "media_chunks": [
                        ["mime_type": "image/jpeg", "data": base64Image]
                    ]
                ]
            ]
            self?.gemini.send(payload: payload)
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(gemini: gemini, capture: capture)
        )
    }

    // Toggle popover visibility
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
