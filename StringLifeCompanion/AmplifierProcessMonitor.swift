import AppKit
import Combine
import Foundation

@MainActor
final class AmplifierProcessMonitor: ObservableObject {
    struct Amplifier: Identifiable, Equatable {
        let id: pid_t
        let name: String
        let bundleID: String
        let launchDate: Date?
    }

    @Published private(set) var amplifiers: [Amplifier] = []
    @Published private(set) var events: [String] = []

    var onProcessesChanged: (([Amplifier]) -> Void)?

    private let supportedIDs: Set<String> = [
        "com.ikmultimedia.AmpliTube5",
        "com.mercuriall.ampbox",
    ]

    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refresh(notify: false)

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

                let amplifier = Amplifier(
                    id: app.processIdentifier,
                    name: app.localizedName ?? bundleID,
                    bundleID: bundleID,
                    launchDate: app.launchDate
                )

                let launched =
                    notification.name
                    == NSWorkspace.didLaunchApplicationNotification

                Task { @MainActor [weak self] in
                    guard let self,
                        self.hasStarted,
                        self.supportedIDs.contains(bundleID)
                    else {
                        return
                    }

                    self.record(
                        "\(launched ? "Launched" : "Terminated"): "
                            + "\(amplifier.name) - PID \(amplifier.id)"
                    )

                    self.handleProcessEvent(amplifier, launched: launched)
                }
            }

            observers.append(token)
        }

        let wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.hasStarted else {
                    return
                }

                self.record("Mac woke up - refreshing applications")
                self.refresh()
            }
        }

        observers.append(wakeObserver)

        refresh(notify: false)
        onProcessesChanged?(amplifiers)

        record("Process monitoring started")
    }

    func refresh(notify: Bool = true) {
        let running = NSWorkspace.shared.runningApplications.compactMap {
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
                bundleID: bundleID,
                launchDate: app.launchDate
            )
        }

        updateAmplifiers(running, notify: notify)
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter

        for observer in observers {
            center.removeObserver(observer)
        }

        observers.removeAll()
        hasStarted = false
    }

    private func updateAmplifiers(_ updated: [Amplifier], notify: Bool = true) {
        let sorted = updated.sorted { $0.id < $1.id }

        guard sorted != amplifiers else {
            return
        }

        amplifiers = sorted

        if notify {
            onProcessesChanged?(sorted)
        }
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

    private func handleProcessEvent(_ amplifier: Amplifier, launched: Bool) {
        guard hasStarted else {
            return
        }

        var updated = amplifiers

        if launched {
            updated.removeAll { $0.id == amplifier.id }
            updated.append(amplifier)
        } else {
            updated.removeAll {
                $0.id == amplifier.id
                    && $0.bundleID == amplifier.bundleID
                    && $0.launchDate == amplifier.launchDate
            }
        }

        updateAmplifiers(updated)
    }
}
