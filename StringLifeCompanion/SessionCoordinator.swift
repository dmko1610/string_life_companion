import Combine
import Foundation

@MainActor
final class SessionCoordinator: ObservableObject {
    @Published private(set) var activeSession: PlayingSession?
    @Published private(set) var sessions: [PlayingSession] = []
    @Published private(set) var errorMessage: String?

    private let repository: any SessionRepository
    private let now: () -> Date
    private var pendingSave: PlayingSession?

    init(
        repository: any SessionRepository,
        now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    func reloadHistory() {
        do {
            sessions = try repository.listSessions()
        } catch {
            errorMessage = "Could not load session history: \(error)"
        }
    }

    func restore(using processes: [AmplifierProcessMonitor.Amplifier]) {
        do {
            let savedActive = try repository.loadActiveSession()

            if let savedActive {
                if processes.isEmpty {
                    var recovered = savedActive
                    recovered.endedAt = savedActive.lastObservedAt
                    recovered.status = .recovered
                    recovered.timingIsApproximate = true

                    activeSession = recovered
                    persist(recovered)
                } else {
                    var resumed = savedActive
                    resumed.amplifierBundleIDs = Array(
                        Set(savedActive.amplifierBundleIDs).union(
                            processes.map(\.bundleID)
                        )
                    ).sorted()
                    resumed.lastObservedAt = now()
                    resumed.timingIsApproximate = true

                    activeSession = resumed
                    persist(resumed)
                }
            } else if !processes.isEmpty {
                startSession(for: processes)
            }

            reloadHistory()
        } catch {
            errorMessage = "Could not restore session: \(error)"
        }
    }

    func processesChanged(to processes: [AmplifierProcessMonitor.Amplifier]) {
        let timestamp = now()

        if processes.isEmpty {
            guard var session = activeSession else {
                return
            }

            session.endedAt = timestamp
            session.status = .completed
            session.lastObservedAt = timestamp

            activeSession = session
            persist(session)

            if pendingSave == nil {
                activeSession = nil
            }

            reloadHistory()
            return
        }

        guard var session = activeSession else {
            startSession(for: processes, at: timestamp)
            return
        }

        let mergedIDs = Set(session.amplifierBundleIDs).union(
            processes.map(\.bundleID)
        ).sorted()

        if mergedIDs != session.amplifierBundleIDs {
            session.amplifierBundleIDs = mergedIDs
        }

        session.lastObservedAt = timestamp
        activeSession = session
        persist(session)
    }

    func checkpoint() {
        guard var session = activeSession, session.status == .active else {
            return
        }

        session.lastObservedAt = now()
        activeSession = session
        persist(session)
    }

    func retryPendingSave() {
        guard let pendingSave else {
            errorMessage = nil
            return
        }

        do {
            try repository.save(pendingSave)
            self.pendingSave = nil
            errorMessage = nil

            if pendingSave.status != .active,
                activeSession?.id == pendingSave.id
            {
                activeSession = nil
            }

            reloadHistory()
        } catch {
            errorMessage = "Save failed again: \(error)"
        }
    }

    private func startSession(
        for processes: [AmplifierProcessMonitor.Amplifier],
        at timestamp: Date? = nil
    ) {
        let startedAt = timestamp ?? now()

        let session = PlayingSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: nil,
            status: .active,
            amplifierBundleIDs: Array(Set(processes.map(\.bundleID))).sorted(),
            lastObservedAt: startedAt,
            timingIsApproximate: false
        )

        activeSession = session
        persist(session)
    }

    private func persist(_ session: PlayingSession) {
        do {
            try repository.save(session)
            pendingSave = nil
            errorMessage = nil
            reloadHistory()
        } catch {
            pendingSave = session
            errorMessage = "Could not save session: \(error)"
        }
    }
}
