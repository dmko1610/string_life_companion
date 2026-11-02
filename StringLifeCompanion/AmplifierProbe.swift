import AppKit
import Combine
import Foundation

@MainActor
final class AmplifierProbe: ObservableObject {
    struct Amplifier: Identifiable {
        let id: pid_t
        let name: String
        let bundleID: String
    }

    @Published private(set) var amplifiers: [Amplifier] = []
    @Published private(set) var events: [String] = []

    private let supportedIDs: Set<String> = [
        "com.ikmultimedia.AmpliTube5",
        "com.mercuriall.ampbox",
    ]

    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refresh()

        let center = NSWorkspace.shared.notificationCenter

        for notificationName in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ] {
            let token = center.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let app = notification.userInfo?[
                        NSWorkspace.applicationUserInfoKey
                    ] as? NSRunningApplication,
                    let bundleID = app.bundleIdentifier
                else {
                    return
                }

                let name = app.localizedName ?? bundleID
                let pid = app.processIdentifier
                let launched =
                    notification.name
                    == NSWorkspace.didLaunchApplicationNotification

                Task { @MainActor [weak self] in
                    guard let self,
                        self.supportedIDs.contains(bundleID)
                    else {
                        return
                    }

                    self.record(
                        "\(launched ? "Launched" : "Terminated"): "
                            + "\(name) - PID \(pid)"
                    )
                    self.refresh()
                }
            }

            observers.append(token)
        }

        refresh()
        record("Diagnostic monitoring started")
    }

    func refresh() {
        amplifiers = NSWorkspace.shared.runningApplications.compactMap {
            app -> Amplifier? in
            guard
                !app.isTerminated,
                let bundleID = app.bundleIdentifier,
                supportedIDs.contains(bundleID)
            else {
                return nil
            }

            return Amplifier(
                id: app.processIdentifier,
                name: app.localizedName ?? bundleID,
                bundleID: bundleID
            )
        }
        .sorted { $0.id < $1.id }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter

        for observer in observers {
            center.removeObserver(observer)
        }

        observers.removeAll()
        hasStarted = false
    }

    private func record(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        let entry = "\(time) \(message)"

        events.insert(entry, at: 0)

        if events.count > 20 {
            events.removeLast(events.count - 20)
        }

        print(entry)
    }
}
