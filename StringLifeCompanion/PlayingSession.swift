import Foundation

enum SessionStatus: String, Codable {
    case active
    case completed
    case recovered
}

struct PlayingSession: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    
    var endedAt: Date?
    var status: SessionStatus
    var amplifierBundleIDs: [String]
    
    var lastObservedAt: Date
    var timingIsApproximate: Bool
    
    func duration(at date: Date) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }
}
