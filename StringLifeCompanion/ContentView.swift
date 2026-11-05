import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: SessionCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("String Life Companion")
                .font(.headline)

            Text("Tracking amplifier uptime")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            currentSession

            Divider()

            HStack {
                Text("Recent sessions")
                    .font(.subheadline)

                Spacer()

                Button("Refresh") {
                    coordinator.reloadHistory()
                }
                .buttonStyle(.borderless)
            }

            if coordinator.sessions.isEmpty {
                Text("No saved sessions yet")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(coordinator.sessions.prefix(10)) { session in
                            sessionRow(session)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 190)
            }

            if let error = coordinator.errorMessage {
                Divider()

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)

                Button("Retry save") {
                    coordinator.retryPendingSave()
                }
                .disabled(!hasPendingSave)
            }

            Divider()

            Button("Quit Companion") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 380)
    }

    @ViewBuilder
    private var currentSession: some View {
        if let session = coordinator.activeSession,
            session.status == .active
        {
            VStack(alignment: .leading, spacing: 6) {
                Text("Session active")
                    .font(.headline)

                Text(amplifierNames(for: session))
                    .font(.subheadline)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatDuration(session.duration(at: context.date)))
                        .font(.system(.title2, design: .rounded))
                        .monospacedDigit()
                }

                Text(
                    "Started \(session.startedAt.formatted(date: .abbreviated, time: .shortened))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if session.timingIsApproximate {
                    Text("Timing is estimated after recovery.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        } else {
            Text("Waiting for Amplitube 5 or Ampbox")
                .foregroundStyle(.secondary)
        }
    }

    private func sessionRow(_ session: PlayingSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(
                    session.startedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.subheadline)

                Spacer()

                if session.status == .active {
                    Text("Active")
                        .foregroundStyle(.green)
                } else {
                    Text(formatDuration(session.duration(at: Date())))
                        .monospacedDigit()
                }
            }

            Text(amplifierNames(for: session))
                .font(.caption)
                .foregroundStyle(.secondary)

            if session.status == .recovered || session.timingIsApproximate {
                Text("Recovered; timing is estimated")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amplifierNames(for session: PlayingSession) -> String {
        let names = session.amplifierBundleIDs.map { bundleID in
            switch bundleID {
            case "com.ikmultimedia.AmpliTube5":
                return "AmpliTube 5"
            case "com.mercuriall.ampbox":
                return "Ampbox"
            default:
                return bundleID
            }
        }

        return names.isEmpty
            ? "Unknown amplifier" : names.joined(separator: ", ")
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%02d:%02d:%02d",
            hours,
            minutes,
            seconds
        )
    }

    private var hasPendingSave: Bool {
        coordinator.errorMessage != nil
    }
}
