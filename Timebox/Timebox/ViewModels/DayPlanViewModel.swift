import Foundation
import Combine

class DayPlanViewModel: ObservableObject {
    @Published var dayPlan: DayPlan {
        didSet { save() }
    }
    @Published var timelineSlots: [TimelineSlot] = []
    @Published var undoManager = TaskUndoManager()

    private let storageKey = "activeDayPlan"
    private let yesterdayStorageKey = "yesterdayDayPlan"
    private var timelineUpdateTimer: AnyCancellable?

    weak var timerVM: TimerViewModel?

    init() {
        self.dayPlan = DayPlan()
        self.dayPlan = load()
        recomputeTimeline()
        startTimelineUpdates()
    }

    // MARK: - Timeline

    func recomputeTimeline() {
        timelineSlots = SchedulingEngine.computeFullTimeline(plan: dayPlan, dayStart: Date())
    }

    private func startTimelineUpdates() {
        // Recompute timeline every 30 seconds to keep current-time position accurate
        timelineUpdateTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recomputeTimeline()
            }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(dayPlan) {
            UserDefaults.standard.set(data, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
        }
    }

    private func load() -> DayPlan {
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
           let plan = try? JSONDecoder().decode(DayPlan.self, from: data) {
            return migrateIfNeeded(plan)
        }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let plan = try? JSONDecoder().decode(DayPlan.self, from: data) {
            return migrateIfNeeded(plan)
        }
        return DayPlan()
    }

    /// If the stored plan is from a previous day, archive it as yesterday and create a new plan.
    private func migrateIfNeeded(_ plan: DayPlan) -> DayPlan {
        if Calendar.current.isDateInToday(plan.date) {
            return plan
        }
        // Archive as yesterday (only keep one day of history)
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: yesterdayStorageKey)
        }
        return DayPlan()
    }

    // MARK: - Task Management (mirrors TaskListViewModel for calendar mode)

    var pendingTasks: [TaskItem] {
        dayPlan.tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [TaskItem] {
        dayPlan.tasks.filter { $0.isCompleted }
    }

    var lastTaskColor: String? {
        dayPlan.tasks.last(where: { !$0.isCompleted })?.colorName
    }

    func addTask(_ task: TaskItem) {
        saveUndoState(description: "Add task")
        var newTask = task
        if newTask.colorName == "blue" {
            newTask.colorName = TaskColor.nextColor(after: lastTaskColor)
        }
        dayPlan.tasks.append(newTask)
        recomputeTimeline()
    }

    func addTasks(_ tasks: [TaskItem]) {
        saveUndoState(description: "Add tasks")
        var colorRef = lastTaskColor
        for task in tasks {
            var newTask = task
            if newTask.colorName == "blue" {
                newTask.colorName = TaskColor.nextColor(after: colorRef)
            }
            colorRef = newTask.colorName
            dayPlan.tasks.append(newTask)
        }
        recomputeTimeline()
    }

    func removeTask(id: UUID) {
        guard let index = dayPlan.tasks.firstIndex(where: { $0.id == id }) else { return }
        saveUndoState(description: "Delete task")
        dayPlan.tasks.remove(at: index)
        recomputeTimeline()
    }

    func updateTask(_ task: TaskItem) {
        saveUndoState(description: "Edit task")
        if let index = dayPlan.tasks.firstIndex(where: { $0.id == task.id }) {
            dayPlan.tasks[index] = task
        }
        recomputeTimeline()
    }

    func completeTask(id: UUID) {
        guard let index = dayPlan.tasks.firstIndex(where: { $0.id == id }) else { return }
        saveUndoState(description: "Complete task")
        dayPlan.tasks[index].isCompleted = true
        dayPlan.tasks[index].actualEndTime = Date()
        recomputeTimeline()
    }

    func uncompleteTask(id: UUID) {
        saveUndoState(description: "Uncomplete task")
        if let index = dayPlan.tasks.firstIndex(where: { $0.id == id }) {
            dayPlan.tasks[index].isCompleted = false
            dayPlan.tasks[index].actualEndTime = nil
        }
        recomputeTimeline()
    }

    func moveTask(from source: IndexSet, to destination: Int) {
        saveUndoState(description: "Reorder tasks")
        dayPlan.tasks.move(fromOffsets: source, toOffset: destination)
        recomputeTimeline()
    }

    func movePendingTask(from source: IndexSet, to destination: Int) {
        saveUndoState(description: "Reorder tasks")
        let pending = pendingTasks
        var fullTasks = dayPlan.tasks
        let movedItems = source.map { pending[$0] }
        for item in movedItems {
            if let idx = fullTasks.firstIndex(where: { $0.id == item.id }) {
                fullTasks.remove(at: idx)
            }
        }
        let pendingAfterRemove = fullTasks.filter { !$0.isCompleted }
        let insertFullIdx: Int
        if destination >= pendingAfterRemove.count {
            if let lastPendingIdx = fullTasks.lastIndex(where: { !$0.isCompleted }) {
                insertFullIdx = lastPendingIdx + 1
            } else {
                insertFullIdx = 0
            }
        } else {
            let targetId = pendingAfterRemove[destination].id
            insertFullIdx = fullTasks.firstIndex(where: { $0.id == targetId }) ?? fullTasks.count
        }
        for (offset, item) in movedItems.enumerated() {
            fullTasks.insert(item, at: insertFullIdx + offset)
        }
        dayPlan.tasks = fullTasks
        recomputeTimeline()
    }

    func clearAllTasks() {
        guard !dayPlan.tasks.isEmpty else { return }
        saveUndoState(description: "Clear all tasks")
        dayPlan.tasks.removeAll()
        recomputeTimeline()
    }

    func clearCompletedTasks() {
        guard dayPlan.tasks.contains(where: { $0.isCompleted }) else { return }
        saveUndoState(description: "Clear completed tasks")
        dayPlan.tasks.removeAll { $0.isCompleted }
        recomputeTimeline()
    }

    func adjustDuration(taskId: UUID, by amount: TimeInterval) {
        saveUndoState(description: "Adjust duration")
        if let index = dayPlan.tasks.firstIndex(where: { $0.id == taskId }) {
            let newDuration = max(1, min(86400, dayPlan.tasks[index].duration + amount))
            dayPlan.tasks[index].duration = newDuration
        }
        recomputeTimeline()
    }

    // MARK: - Event Management

    func addEvent(_ event: Event) {
        saveUndoState(description: "Add event")
        dayPlan.events.append(event)
        dayPlan.events.sort { $0.startTime < $1.startTime }
        recomputeTimeline()
    }

    func updateEvent(_ event: Event) {
        saveUndoState(description: "Edit event")
        if let index = dayPlan.events.firstIndex(where: { $0.id == event.id }) {
            dayPlan.events[index] = event
            dayPlan.events.sort { $0.startTime < $1.startTime }
        }
        recomputeTimeline()
    }

    func removeEvent(id: UUID) {
        guard let index = dayPlan.events.firstIndex(where: { $0.id == id }) else { return }
        saveUndoState(description: "Delete event")
        dayPlan.events.remove(at: index)
        recomputeTimeline()
    }

    func completeEvent(id: UUID) {
        guard let index = dayPlan.events.firstIndex(where: { $0.id == id }) else { return }
        saveUndoState(description: "Complete event")
        dayPlan.events[index].isCompleted = true
        dayPlan.events[index].actualEndTime = Date()
        recomputeTimeline()
    }

    func clearAllEvents() {
        guard !dayPlan.events.isEmpty else { return }
        saveUndoState(description: "Clear all events")
        dayPlan.events.removeAll()
        recomputeTimeline()
    }

    /// Find the event object by ID
    func event(for id: UUID) -> Event? {
        dayPlan.events.first { $0.id == id }
    }

    /// Find the task object by ID
    func task(for id: UUID) -> TaskItem? {
        dayPlan.tasks.first { $0.id == id }
    }

    // MARK: - Event Interruption Check

    /// Returns the next upcoming event that should interrupt the current task timer.
    func nextUpcomingEvent(after date: Date = Date()) -> Event? {
        dayPlan.pendingEvents.first { $0.startTime > date }
    }

    /// Returns any event whose start time has arrived (for auto-interruption).
    func eventStartingNow(tolerance: TimeInterval = 1.0) -> Event? {
        let now = Date()
        return dayPlan.pendingEvents.first { event in
            abs(event.startTime.timeIntervalSince(now)) <= tolerance
        }
    }

    /// Auto-finish a previous event when a new event starts.
    func autoFinishPreviousEvent(before eventId: UUID) {
        // Find events that are active (not completed) and start before this one
        let targetEvent = dayPlan.events.first { $0.id == eventId }
        guard let target = targetEvent else { return }

        for i in dayPlan.events.indices {
            if !dayPlan.events[i].isCompleted && dayPlan.events[i].id != eventId
                && dayPlan.events[i].startTime < target.startTime {
                dayPlan.events[i].isCompleted = true
                dayPlan.events[i].actualEndTime = target.startTime
            }
        }
        recomputeTimeline()
    }

    // MARK: - Sync tasks from TaskListViewModel (for mode switching)

    func importTasks(from taskList: [TaskItem]) {
        dayPlan.tasks = taskList
        recomputeTimeline()
    }

    func exportTasks() -> [TaskItem] {
        dayPlan.tasks
    }

    // MARK: - Undo/Redo

    private func saveUndoState(description: String) {
        undoManager.saveState(
            tasks: dayPlan.tasks,
            dividerIndex: nil,
            description: description,
            timerState: timerVM?.captureTimerSnapshot()
        )
    }

    func undo() -> TaskUndoManager.TimerSnapshot? {
        let currentTimerState = timerVM?.captureTimerSnapshot()
        if let snapshot = undoManager.undo(
            currentTasks: dayPlan.tasks,
            currentDivider: nil,
            currentTimerState: currentTimerState
        ) {
            dayPlan.tasks = snapshot.tasks
            recomputeTimeline()
            return snapshot.timerState
        }
        return nil
    }

    func redo() -> TaskUndoManager.TimerSnapshot? {
        let currentTimerState = timerVM?.captureTimerSnapshot()
        if let snapshot = undoManager.redo(
            currentTasks: dayPlan.tasks,
            currentDivider: nil,
            currentTimerState: currentTimerState
        ) {
            dayPlan.tasks = snapshot.tasks
            recomputeTimeline()
            return snapshot.timerState
        }
        return nil
    }
}
