import SwiftUI

@main
struct StringLifeCompanionApp: App {
    @StateObject private var probe = AmplifierProbe()
    
    var body: some Scene {
        MenuBarExtra("String Life Companion", systemImage: "guitars") {
            ContentView(probe: probe)
        }
        .menuBarExtraStyle(.window)
    }
}
