import Combine
import Foundation

@MainActor
final class SessionCoordinator: ObservableObject {
    @Published private(set) var activeSession: PlayingSession?
    @Published private(set) var sessions: [PlayingSession] = []
    @Published private(set) var errorMessage: String?

    private let repository: any SessionRepository
    private let now: () -> Date

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
            errorMessage = nil
        } catch {
            errorMessage = "Could not load session history: \(error)"
        }
    }

    func processesChanged(to processes: [AmplifierProcessMonitor.Amplifier]) {
        let timestamp = now()

        do {
            if processes.isEmpty {
                guard var session = activeSession else {
                    return
                }

                session.endedAt = timestamp
                session.status = .completed
                session.lastObservedAt = timestamp

                try repository.save(session)
                activeSession = nil
                errorMessage = nil
                reloadHistory()
                return
            }

            let runningBundleIDs = Set(processes.map(\.bundleID))

            guard var session = activeSession else {
                let newSession = PlayingSession(
                    id: UUID(),
                    startedAt: timestamp,
                    endedAt: nil,
                    status: .active,
                    amplifierBundleIDs: runningBundleIDs.sorted(),
                    lastObservedAt: timestamp,
                    timingIsApproximate: false
                )

                try repository.save(newSession)
                activeSession = newSession
                errorMessage = nil
                reloadHistory()
                return
            }

            let previousIDs = Set(session.amplifierBundleIDs)
            let mergedIDs = previousIDs.union(runningBundleIDs).sorted()

            guard mergedIDs != session.amplifierBundleIDs else {
                return
            }

            session.amplifierBundleIDs = mergedIDs
            session.lastObservedAt = timestamp

            try repository.save(session)
            activeSession = session
            errorMessage = nil
            reloadHistory()
        } catch {
            errorMessage = "Could not save session: \(error)"
        }
    }
}
