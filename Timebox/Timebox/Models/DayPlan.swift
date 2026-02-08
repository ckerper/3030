import Foundation

struct DayPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date                      // which calendar day
    var tasks: [TaskItem]               // ordered by user priority
    var events: [Event]                 // ordered by startTime
    var minimumFragmentMinutes: Int     // guardrail threshold, default 5

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        tasks: [TaskItem] = [],
        events: [Event] = [],
        minimumFragmentMinutes: Int = 5
    ) {
        self.id = id
        self.date = date
        self.tasks = tasks
        self.events = events.sorted { $0.startTime < $1.startTime }
        self.minimumFragmentMinutes = minimumFragmentMinutes
    }

    /// Whether this plan is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Whether this plan is for yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    /// Pending (non-completed) tasks in order
    var pendingTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    /// Pending (non-completed) events sorted by start time
    var pendingEvents: [Event] {
        events.filter { !$0.isCompleted }.sorted { $0.startTime < $1.startTime }
    }
}
