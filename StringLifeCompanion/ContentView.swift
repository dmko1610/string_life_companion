<<<<<<< HEAD
//
//  ContentView.swift
//  StringLifeCompanion
//
//  Created by Dmitry Kovalev on 02.11.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
=======
import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var probe: AmplifierProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("String Life Companion")
                .font(.headline)

            Text("Phase 0 * Process detection")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if probe.amplifiers.isEmpty {
                Text("No supported amplifiers running")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(probe.amplifiers) { amplifier in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(amplifier.name)
                            .font(.headline)

                        Text(amplifier.bundleID)
                            .font(.caption)

                        Text("PID: \(amplifier.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Refresh running applications") {
                probe.refresh()
            }

            Divider()

            Text("Recent events")
                .font(.subheadline)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(
                        Array(probe.events.enumerated()),
                        id: \.offset
                    ) { item in
                        Text(item.element)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 150)

            Divider()

            Button("Quit Companion") {
                probe.stop()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear {
            probe.start()
        }
    }
}
>>>>>>> cebe7bc (Initial Commit)
