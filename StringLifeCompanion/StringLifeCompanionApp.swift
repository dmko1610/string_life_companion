<<<<<<< HEAD
//
//  StringLifeCompanionApp.swift
//  StringLifeCompanion
//
//  Created by Dmitry Kovalev on 02.11.2026.
//

=======
>>>>>>> cebe7bc (Initial Commit)
import SwiftUI

@main
struct StringLifeCompanionApp: App {
<<<<<<< HEAD
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
=======
    @StateObject private var probe = AmplifierProbe()
    
    var body: some Scene {
        MenuBarExtra("String Life Companion", systemImage: "guitars") {
            ContentView(probe: probe)
        }
        .menuBarExtraStyle(.window)
>>>>>>> cebe7bc (Initial Commit)
    }
}
