import AppKit
import Combine
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var startupError: String?

    @Published private(set) var monitor: AmplifierProcessMonitor?
    @Published private(set) var coordinator: SessionCoordinator?

    private var repository: SQLiteSessionRepository?
    private var checkpointTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {

            let repository = try SQLiteSessionRepository()
            self.repository = repository

            let coordinator = SessionCoordinator(repository: repository)
            self.coordinator = coordinator

            let monitor = AmplifierProcessMonitor()
            self.monitor = monitor

            monitor.start()

            coordinator.restore(using: monitor.amplifiers)

            monitor.onProcessesChanged = { [weak coordinator] processes in
                coordinator?.processesChanged(to: processes)
            }

            startupError = nil

            checkpointTimer = Timer.scheduledTimer(
                withTimeInterval: 30,
                repeats: true
            ) { [weak coordinator] _ in
                Task { @MainActor in coordinator?.checkpoint() }
            }

        } catch {
            startupError = error.localizedDescription
            NSLog("String Life Companion could not start: %@", "\(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        checkpointTimer?.invalidate()
        checkpointTimer = nil

        coordinator?.checkpoint()
        monitor?.stop()
    }
}
