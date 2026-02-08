import Foundation

/// Computed timeline entries — produced by the scheduling engine, never persisted.
enum TimelineSlot: Identifiable {
    case taskFragment(
        taskId: UUID,
        startTime: Date,
        endTime: Date,
        fragmentIndex: Int,    // 0 = "start Task A", 1+ = "continue Task A"
        duration: TimeInterval
    )
    case event(
        eventId: UUID,
        startTime: Date,
        endTime: Date
    )
    case freeTime(
        startTime: Date,
        endTime: Date
    )

    var id: String {
        switch self {
        case .taskFragment(let taskId, let start, _, let frag, _):
            return "task-\(taskId.uuidString)-\(frag)-\(start.timeIntervalSince1970)"
        case .event(let eventId, let start, _):
            return "event-\(eventId.uuidString)-\(start.timeIntervalSince1970)"
        case .freeTime(let start, let end):
            return "free-\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)"
        }
    }

    var startTime: Date {
        switch self {
        case .taskFragment(_, let start, _, _, _): return start
        case .event(_, let start, _): return start
        case .freeTime(let start, _): return start
        }
    }

    var endTime: Date {
        switch self {
        case .taskFragment(_, _, let end, _, _): return end
        case .event(_, _, let end): return end
        case .freeTime(_, let end): return end
        }
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
