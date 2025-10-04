import SwiftUI

@main
struct TruthLens: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create the menu-bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // 👇 use your own custom image from Assets.xcassets
            button.image = NSImage(named: "MyIcon") ?? NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            button.action = #selector(togglePopover)
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient // closes when clicking outside
        popover.contentViewController = NSHostingController(rootView: MyPopoverView())
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

// SwiftUI view for the popover
struct MyPopoverView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Hello from the popover!")
                .font(.headline)
            Button("Quit App") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 250, height: 120)
    }
}
