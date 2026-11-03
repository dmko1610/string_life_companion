import Foundation

@MainActor
protocol SessionRepository {
    func loadActiveSession() throws -> PlayingSession?
    func save(_ session: PlayingSession) throws
    func listSessions() throws -> [PlayingSession]
}

@MainActor
final class InMemorySessionRepository: SessionRepository {
    private var sessions: [UUID: PlayingSession] = [:]

    func loadActiveSession() throws -> PlayingSession? {
        sessions.values.first { $0.status == .active }
    }

    func save(_ session: PlayingSession) throws {
        sessions[session.id] = session
    }

    func listSessions() throws -> [PlayingSession] {
        sessions.values.sorted {
            $0.startedAt > $1.startedAt
        }
    }
}
