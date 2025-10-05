import SwiftUI

@main
struct TruthLens: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // no settings window
        }
    }
}

