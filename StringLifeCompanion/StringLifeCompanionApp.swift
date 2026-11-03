import SwiftUI

@main
struct StringLifeCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra("String Life Companion", systemImage: "guitars") {
            ContentView(probe: appDelegate.probe)
        }
        .menuBarExtraStyle(.window)
    }
}
