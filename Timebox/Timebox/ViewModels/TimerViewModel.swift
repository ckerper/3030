import Foundation
import Combine
import UIKit

class TimerViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isRunning: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var overtimeElapsed: TimeInterval = 0
    @Published var isOvertime: Bool = false
    @Published var timerStartedAt: Date?
    @Published var totalDuration: TimeInterval = 0

    /// The ID of the task currently on the timer.
    @Published var activeTaskId: UUID?

    /// Calendar mode: the ID of the event currently being timed (nil when timing a task).
    @Published var activeEventId: UUID?

    /// Calendar mode: true when the timer is counting down an event instead of a task.
    @Published var isTimingEvent: Bool = false

    /// Saved remaining times for tasks that were interrupted (bumped down).
    /// Key: task ID, Value: remaining seconds when paused/bumped.
    var savedRemainingTimes: [UUID: TimeInterval] = [:]

    // MARK: - Dependencies
    private var timer: AnyCancellable?
    private var taskList: TaskListViewModel?
    private var dayPlanVM: DayPlanViewModel?
    private var settings: AppSettings?

    // MARK: - Persistence Keys
    private let kTimerActiveTaskId = "timer_activeTaskId"
    private let kTimerRemainingTime = "timer_remainingTime"
    private let kTimerTotalDuration = "timer_totalDuration"
    private let kTimerIsRunning = "timer_isRunning"
    private let kTimerIsOvertime = "timer_isOvertime"
    private let kTimerOvertimeElapsed = "timer_overtimeElapsed"
    private let kTimerLastSaveDate = "timer_lastSaveDate"
    private let kTimerSavedRemainingTimes = "timer_savedRemainingTimes"
    private let kTimerActiveEventId = "timer_activeEventId"
    private let kTimerIsTimingEvent = "timer_isTimingEvent"

    // MARK: - Derived

    /// The index of the active task in the full task list.
    var currentTaskIndex: Int {
        guard let taskList = taskList, let id = activeTaskId else { return 0 }
        return taskList.taskList.tasks.firstIndex(where: { $0.id == id }) ?? 0
    }

    /// Progress from 0 to 1 — 0 = full ring (all time remaining), 1 = empty ring (no time left)
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        if isOvertime { return 1.0 }
        return max(0, min(1, 1.0 - (remainingTime / totalDuration)))
    }

    var displayTime: String {
        if isOvertime {
            return TimeFormatting.formatOvertime(overtimeElapsed)
        }
        return TimeFormatting.format(remainingTime)
    }

    var currentTask: TaskItem? {
        if let id = activeTaskId {
            if let taskList = taskList {
                return taskList.taskList.tasks.first(where: { $0.id == id })
            }
            if let dayPlanVM = dayPlanVM {
                return dayPlanVM.dayPlan.tasks.first(where: { $0.id == id })
            }
        }
        return nil
    }

    /// Calendar mode: the current event being timed.
    var currentEvent: Event? {
        guard let dayPlanVM = dayPlanVM, let id = activeEventId else { return nil }
        return dayPlanVM.dayPlan.events.first(where: { $0.id == id })
    }

    var currentColor: String {
        if isTimingEvent, let event = currentEvent {
            return event.colorName
        }
        return currentTask?.colorName ?? "blue"
    }

    var currentTitle: String {
        if isTimingEvent, let event = currentEvent {
            return event.title
        }
        return currentTask?.title ?? ""
    }

    // MARK: - Setup

    func configure(taskList: TaskListViewModel, settings: AppSettings) {
        self.taskList = taskList
        self.settings = settings
    }

    func configureForCalendar(dayPlanVM: DayPlanViewModel, settings: AppSettings) {
        self.dayPlanVM = dayPlanVM
        self.settings = settings
    }

    // MARK: - Sync: always track the first pending task (#1)

    /// Call this whenever the task list changes (reorder, move-to-top, undo, etc.)
    /// to ensure the timer is pointing at the first pending task.
    func syncToFirstPending() {
        guard let taskList = taskList else { return }
        let firstPending = taskList.pendingTasks.first

        guard let target = firstPending else {
            // No pending tasks
            if isRunning { stop() }
            activeTaskId = nil
            return
        }

        if target.id == activeTaskId {
            // Already tracking the right task — nothing to do
            return
        }

        // The first pending task changed. Save the current timer state if active.
        if let currentId = activeTaskId, remainingTime > 0 && !isOvertime {
            savedRemainingTimes[currentId] = remainingTime
        }

        // Switch to the new first pending task
        let wasRunning = isRunning
        if isRunning { pause() }

        activeTaskId = target.id

        // Restore saved time if we had one, otherwise use the task's full duration
        if let saved = savedRemainingTimes[target.id] {
            remainingTime = saved
            totalDuration = target.duration
            overtimeElapsed = 0
            isOvertime = false
            savedRemainingTimes.removeValue(forKey: target.id)
        } else {
            remainingTime = target.duration
            totalDuration = target.duration
            overtimeElapsed = 0
            isOvertime = false
        }

        if wasRunning {
            start()
        }
    }

    // MARK: - Timer Controls

    func startOrPause() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        // In list mode, use taskList; in calendar mode, use dayPlanVM; event timing sets its own state
        if activeTaskId == nil && !isTimingEvent {
            if let taskList = taskList {
                if let first = taskList.pendingTasks.first {
                    activeTaskId = first.id
                    remainingTime = first.duration
                    totalDuration = first.duration
                } else {
                    return
                }
            } else if let dayPlanVM = dayPlanVM {
                if let first = dayPlanVM.pendingTasks.first {
                    activeTaskId = first.id
                    remainingTime = first.duration
                    totalDuration = first.duration
                } else {
                    return
                }
            } else {
                return
            }
        }

        if remainingTime <= 0 && !isOvertime {
            if let task = currentTask {
                remainingTime = task.duration
                totalDuration = task.duration
            }
        }

        isRunning = true
        timerStartedAt = Date()
        persistState()

        if settings?.keepScreenOn == true {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        persistState()
    }

    func stop() {
        pause()
        remainingTime = 0
        overtimeElapsed = 0
        isOvertime = false
        activeTaskId = nil
        timerStartedAt = nil
        // Don't clear savedRemainingTimes — they may be needed if undo/redo brings tasks back
        clearPersistedState()
    }

    // MARK: - Task Completion

    func completeCurrentTask() {
        guard let taskList = taskList, let id = activeTaskId else { return }
        guard let idx = taskList.taskList.tasks.firstIndex(where: { $0.id == id }) else { return }

        // Save remaining time so undo can restore it
        if !isOvertime && remainingTime > 0 {
            savedRemainingTimes[id] = remainingTime
        } else {
            savedRemainingTimes.removeValue(forKey: id)
        }

        // Set actual times so the task shows on calendar after completion
        taskList.taskList.tasks[idx].actualEndTime = Date()
        if taskList.taskList.tasks[idx].actualStartTime == nil {
            let elapsed = isOvertime ? (totalDuration + overtimeElapsed) : (totalDuration - remainingTime)
            taskList.taskList.tasks[idx].actualStartTime = Date().addingTimeInterval(-elapsed)
        }

        // Mark completed
        taskList.completeTask(at: idx)

        // Advance to next first pending
        advanceToNext()
        persistState()
    }

    func advanceToNext() {
        guard let taskList = taskList, let settings = settings else { return }

        let pending = taskList.pendingTasks
        if let next = pending.first {
            activeTaskId = next.id
            if let saved = savedRemainingTimes[next.id] {
                remainingTime = saved
                totalDuration = next.duration
                overtimeElapsed = 0
                isOvertime = false
                savedRemainingTimes.removeValue(forKey: next.id)
            } else {
                remainingTime = next.duration
                totalDuration = next.duration
                overtimeElapsed = 0
                isOvertime = false
            }
            if settings.autoStartNextTask {
                start()
            } else {
                pause()
            }
        } else if settings.autoLoop {
            taskList.resetCompletedStates()
            savedRemainingTimes.removeAll()
            if let first = taskList.pendingTasks.first {
                activeTaskId = first.id
                remainingTime = first.duration
                totalDuration = first.duration
                overtimeElapsed = 0
                isOvertime = false
                if settings.autoStartNextTask {
                    start()
                } else {
                    pause()
                }
            } else {
                stop()
            }
        } else {
            stop()
        }
    }

    func loadCurrentTask() {
        guard let taskList = taskList else { return }
        if let first = taskList.pendingTasks.first {
            activeTaskId = first.id
            if let saved = savedRemainingTimes[first.id] {
                remainingTime = saved
                savedRemainingTimes.removeValue(forKey: first.id)
            } else {
                remainingTime = first.duration
            }
            totalDuration = first.duration
            overtimeElapsed = 0
            isOvertime = false
        }
    }

    // MARK: - Calendar Mode: Sync & Event Interruption

    /// Sync to the first pending task in calendar mode's DayPlan.
    func syncToFirstPendingCalendar() {
        guard let dayPlanVM = dayPlanVM else { return }

        // If we're timing an event, don't switch
        if isTimingEvent { return }

        let firstPending = dayPlanVM.pendingTasks.first

        guard let target = firstPending else {
            if isRunning && !isTimingEvent { stop() }
            activeTaskId = nil
            return
        }

        if target.id == activeTaskId { return }

        if let currentId = activeTaskId, remainingTime > 0 && !isOvertime {
            savedRemainingTimes[currentId] = remainingTime
        }

        let wasRunning = isRunning
        if isRunning { pause() }

        activeTaskId = target.id
        isTimingEvent = false
        activeEventId = nil

        if let saved = savedRemainingTimes[target.id] {
            remainingTime = saved
            totalDuration = target.duration
            overtimeElapsed = 0
            isOvertime = false
            savedRemainingTimes.removeValue(forKey: target.id)
        } else {
            remainingTime = target.duration
            totalDuration = target.duration
            overtimeElapsed = 0
            isOvertime = false
        }

        if wasRunning { start() }
    }

    /// Start timing an event (calendar mode). Pauses any active task timer.
    func startEvent(_ event: Event) {
        // Save current task timer state
        if let currentId = activeTaskId, remainingTime > 0 && !isOvertime && !isTimingEvent {
            savedRemainingTimes[currentId] = remainingTime
        }

        if isRunning { pause() }

        isTimingEvent = true
        activeEventId = event.id
        activeTaskId = nil
        remainingTime = event.plannedDuration
        totalDuration = event.plannedDuration
        overtimeElapsed = 0
        isOvertime = false

        start()
    }

    /// Complete the current event and resume task timing.
    func completeCurrentEvent() {
        guard let dayPlanVM = dayPlanVM, let eventId = activeEventId else { return }

        if isRunning { pause() }

        dayPlanVM.completeEvent(id: eventId)

        isTimingEvent = false
        activeEventId = nil

        // Resume the first pending task
        syncToFirstPendingCalendar()

        if settings?.autoStartNextTask == true {
            start()
        }

        dayPlanVM.recomputeTimeline()
        persistState()
    }

    /// Check if an event should interrupt the current task timer (called from tick).
    func checkEventInterruption() {
        guard let dayPlanVM = dayPlanVM, !isTimingEvent else { return }

        if let event = dayPlanVM.eventStartingNow(tolerance: 1.0) {
            // Auto-finish any previous event
            dayPlanVM.autoFinishPreviousEvent(before: event.id)

            // Record actual start time for the current task being interrupted
            if let taskId = activeTaskId,
               let idx = dayPlanVM.dayPlan.tasks.firstIndex(where: { $0.id == taskId }) {
                if dayPlanVM.dayPlan.tasks[idx].actualStartTime == nil {
                    dayPlanVM.dayPlan.tasks[idx].actualStartTime = timerStartedAt
                }
            }

            // Start the event
            startEvent(event)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }

    /// Start timing a task from calendar mode's DayPlan (used for manual start).
    func startCalendarTask() {
        guard let dayPlanVM = dayPlanVM else { return }

        if activeTaskId == nil {
            if let first = dayPlanVM.pendingTasks.first {
                activeTaskId = first.id
                remainingTime = first.duration
                totalDuration = first.duration
            } else {
                return
            }
        }

        if remainingTime <= 0 && !isOvertime {
            if let task = currentTask {
                remainingTime = task.duration
                totalDuration = task.duration
            }
        }

        isTimingEvent = false
        activeEventId = nil

        // Record actual start time
        if let taskId = activeTaskId,
           let idx = dayPlanVM.dayPlan.tasks.firstIndex(where: { $0.id == taskId }),
           dayPlanVM.dayPlan.tasks[idx].actualStartTime == nil {
            dayPlanVM.dayPlan.tasks[idx].actualStartTime = Date()
        }

        start()
    }

    /// Complete the current task in calendar mode.
    func completeCurrentTaskCalendar() {
        guard let dayPlanVM = dayPlanVM, let id = activeTaskId else { return }

        if !isOvertime && remainingTime > 0 {
            savedRemainingTimes[id] = remainingTime
        } else {
            savedRemainingTimes.removeValue(forKey: id)
        }

        dayPlanVM.completeTask(id: id)

        // Advance to next pending in calendar mode
        let pending = dayPlanVM.pendingTasks
        if let next = pending.first {
            activeTaskId = next.id
            if let saved = savedRemainingTimes[next.id] {
                remainingTime = saved
                totalDuration = next.duration
                overtimeElapsed = 0
                isOvertime = false
                savedRemainingTimes.removeValue(forKey: next.id)
            } else {
                remainingTime = next.duration
                totalDuration = next.duration
                overtimeElapsed = 0
                isOvertime = false
            }
            if settings?.autoStartNextTask == true {
                start()
            } else {
                pause()
            }
        } else {
            stop()
        }

        dayPlanVM.recomputeTimeline()
        persistState()
    }

    // MARK: - Time Adjustment

    func adjustTime(by amount: TimeInterval) {
        if isOvertime {
            if amount > 0 {
                isOvertime = false
                remainingTime = amount
                overtimeElapsed = 0
                totalDuration += amount
            }
        } else {
            remainingTime = max(0, remainingTime + amount)
            // Symmetrically adjust planned total for both add and subtract
            totalDuration = max(1, totalDuration + amount)
        }
        persistState()
    }

    // MARK: - Reset Duration

    func resetCurrentTaskDuration() {
        guard let task = currentTask else { return }
        remainingTime = task.duration
        totalDuration = task.duration
        overtimeElapsed = 0
        isOvertime = false
        persistState()
    }

    // MARK: - Undo Sync

    /// Capture the current timer state for undo snapshots.
    func captureTimerSnapshot() -> TaskUndoManager.TimerSnapshot {
        TaskUndoManager.TimerSnapshot(
            activeTaskId: activeTaskId,
            remainingTime: remainingTime,
            totalDuration: totalDuration,
            isOvertime: isOvertime,
            overtimeElapsed: overtimeElapsed,
            isRunning: isRunning,
            savedRemainingTimes: savedRemainingTimes
        )
    }

    /// Restore timer state from an undo/redo snapshot.
    func restoreTimerSnapshot(_ snapshot: TaskUndoManager.TimerSnapshot) {
        let wasRunning = isRunning
        if isRunning { pause() }

        activeTaskId = snapshot.activeTaskId
        remainingTime = snapshot.remainingTime
        totalDuration = snapshot.totalDuration
        isOvertime = snapshot.isOvertime
        overtimeElapsed = snapshot.overtimeElapsed
        savedRemainingTimes = snapshot.savedRemainingTimes

        if snapshot.isRunning || wasRunning {
            start()
        }
        persistState()
    }

    func syncAfterUndo(taskListVM: TaskListViewModel, restoredTimerState: TaskUndoManager.TimerSnapshot? = nil) {
        if let timerState = restoredTimerState {
            restoreTimerSnapshot(timerState)
        } else {
            // No saved timer state — re-sync to whatever is now first.
            syncToFirstPending()
        }
    }

    // MARK: - State Persistence (survive app close/reopen)

    func persistState() {
        let defaults = UserDefaults.standard
        if let id = activeTaskId {
            defaults.set(id.uuidString, forKey: kTimerActiveTaskId)
        } else {
            defaults.removeObject(forKey: kTimerActiveTaskId)
        }
        if let id = activeEventId {
            defaults.set(id.uuidString, forKey: kTimerActiveEventId)
        } else {
            defaults.removeObject(forKey: kTimerActiveEventId)
        }
        defaults.set(isTimingEvent, forKey: kTimerIsTimingEvent)
        defaults.set(remainingTime, forKey: kTimerRemainingTime)
        defaults.set(totalDuration, forKey: kTimerTotalDuration)
        defaults.set(isRunning, forKey: kTimerIsRunning)
        defaults.set(isOvertime, forKey: kTimerIsOvertime)
        defaults.set(overtimeElapsed, forKey: kTimerOvertimeElapsed)
        defaults.set(Date().timeIntervalSince1970, forKey: kTimerLastSaveDate)

        // Save savedRemainingTimes as [String: Double]
        let encoded = savedRemainingTimes.reduce(into: [String: Double]()) { dict, pair in
            dict[pair.key.uuidString] = pair.value
        }
        defaults.set(encoded, forKey: kTimerSavedRemainingTimes)
    }

    func restoreState() {
        // Cancel any existing timer to avoid race conditions with a stale
        // Timer.publish that resumes firing when the app becomes active.
        timer?.cancel()
        timer = nil

        let defaults = UserDefaults.standard

        // Restore savedRemainingTimes
        if let encoded = defaults.dictionary(forKey: kTimerSavedRemainingTimes) as? [String: Double] {
            savedRemainingTimes = encoded.reduce(into: [UUID: TimeInterval]()) { dict, pair in
                if let uuid = UUID(uuidString: pair.key) {
                    dict[uuid] = pair.value
                }
            }
        }

        let savedRemaining = defaults.double(forKey: kTimerRemainingTime)
        let savedTotal = defaults.double(forKey: kTimerTotalDuration)
        let wasRunning = defaults.bool(forKey: kTimerIsRunning)
        let wasOvertime = defaults.bool(forKey: kTimerIsOvertime)
        let savedOvertime = defaults.double(forKey: kTimerOvertimeElapsed)
        let savedTimestamp = defaults.double(forKey: kTimerLastSaveDate)
        let wasTimingEvent = defaults.bool(forKey: kTimerIsTimingEvent)

        // --- Event restore path ---
        if wasTimingEvent,
           let eventIdString = defaults.string(forKey: kTimerActiveEventId),
           let savedEventId = UUID(uuidString: eventIdString),
           let dayPlanVM = dayPlanVM {

            // Check if the event still exists and is pending
            let eventExists = dayPlanVM.dayPlan.events.contains(where: { $0.id == savedEventId && !$0.isCompleted })

            if eventExists && wasRunning {
                let elapsed = Date().timeIntervalSince1970 - savedTimestamp

                if wasOvertime {
                    let totalOvertime = savedOvertime + elapsed
                    // Check if the event's planned end time has long passed — auto-complete it
                    // (e.g. a subsequent event should have stopped this one)
                    if let event = dayPlanVM.dayPlan.events.first(where: { $0.id == savedEventId }),
                       Date() >= event.plannedEndTime {
                        // Event should have ended — complete it and move on
                        dayPlanVM.completeEvent(id: savedEventId)
                        isTimingEvent = false
                        activeEventId = nil
                        syncToFirstPendingCalendar()
                        if settings?.autoStartNextTask == true { start() }
                        dayPlanVM.recomputeTimeline()
                        persistState()
                        return
                    }
                    // Still in overtime but event hasn't ended yet by schedule
                    isTimingEvent = true
                    activeEventId = savedEventId
                    activeTaskId = nil
                    totalDuration = savedTotal
                    isOvertime = true
                    overtimeElapsed = totalOvertime
                    remainingTime = 0
                    start()
                } else {
                    let newRemaining = savedRemaining - elapsed
                    if newRemaining <= 0 {
                        // Timer ran out while app was closed — check if event should be auto-completed
                        if let event = dayPlanVM.dayPlan.events.first(where: { $0.id == savedEventId }),
                           Date() >= event.plannedEndTime {
                            // Event ended while app was closed — complete it and move on
                            dayPlanVM.completeEvent(id: savedEventId)
                            isTimingEvent = false
                            activeEventId = nil
                            syncToFirstPendingCalendar()
                            if settings?.autoStartNextTask == true { start() }
                            dayPlanVM.recomputeTimeline()
                            persistState()
                            return
                        }
                        // Crossed into overtime
                        isTimingEvent = true
                        activeEventId = savedEventId
                        activeTaskId = nil
                        totalDuration = savedTotal
                        isOvertime = true
                        overtimeElapsed = abs(newRemaining)
                        remainingTime = 0
                        start()
                    } else {
                        isTimingEvent = true
                        activeEventId = savedEventId
                        activeTaskId = nil
                        totalDuration = savedTotal
                        isOvertime = false
                        remainingTime = newRemaining
                        overtimeElapsed = 0
                        start()
                    }
                }
            } else if eventExists {
                // Was paused — restore exact state
                isTimingEvent = true
                activeEventId = savedEventId
                activeTaskId = nil
                totalDuration = savedTotal
                remainingTime = savedRemaining
                isOvertime = wasOvertime
                overtimeElapsed = savedOvertime
            } else {
                // Event was completed/removed while app was closed — fall through to task restore
                isTimingEvent = false
                activeEventId = nil
                syncToFirstPendingCalendar()
                if settings?.autoStartNextTask == true { start() }
                persistState()
            }
            return
        }

        // --- Task restore path ---
        guard let idString = defaults.string(forKey: kTimerActiveTaskId),
              let savedId = UUID(uuidString: idString) else {
            return
        }

        // Verify this task still exists and is pending (check both list mode and calendar mode)
        let taskExists: Bool
        if let taskList = taskList,
           taskList.taskList.tasks.contains(where: { $0.id == savedId && !$0.isCompleted }) {
            taskExists = true
        } else if let dayPlanVM = dayPlanVM,
                  dayPlanVM.dayPlan.tasks.contains(where: { $0.id == savedId && !$0.isCompleted }) {
            taskExists = true
        } else {
            taskExists = false
        }
        guard taskExists else { return }

        activeTaskId = savedId
        totalDuration = savedTotal

        if wasRunning {
            // Calculate how much real time elapsed since we saved
            let elapsed = Date().timeIntervalSince1970 - savedTimestamp

            if wasOvertime {
                // Was already in overtime — add elapsed to overtime counter
                isOvertime = true
                overtimeElapsed = savedOvertime + elapsed
                remainingTime = 0
            } else {
                // Was counting down — subtract elapsed from remaining
                let newRemaining = savedRemaining - elapsed
                if newRemaining <= 0 {
                    // Crossed into overtime while app was closed
                    isOvertime = true
                    overtimeElapsed = abs(newRemaining)
                    remainingTime = 0
                } else {
                    isOvertime = false
                    remainingTime = newRemaining
                    overtimeElapsed = 0
                }
            }
            // Resume the timer
            start()
        } else {
            // Was paused — restore exact state
            remainingTime = savedRemaining
            isOvertime = wasOvertime
            overtimeElapsed = savedOvertime
        }
    }

    func clearPersistedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kTimerActiveTaskId)
        defaults.removeObject(forKey: kTimerActiveEventId)
        defaults.removeObject(forKey: kTimerIsTimingEvent)
        defaults.removeObject(forKey: kTimerRemainingTime)
        defaults.removeObject(forKey: kTimerTotalDuration)
        defaults.removeObject(forKey: kTimerIsRunning)
        defaults.removeObject(forKey: kTimerIsOvertime)
        defaults.removeObject(forKey: kTimerOvertimeElapsed)
        defaults.removeObject(forKey: kTimerLastSaveDate)
        defaults.removeObject(forKey: kTimerSavedRemainingTimes)
    }

    // MARK: - Private

    private func tick() {
        if isOvertime {
            overtimeElapsed += 0.1
        } else {
            remainingTime -= 0.1
            if remainingTime <= 0 {
                remainingTime = 0
                isOvertime = true
                overtimeElapsed = 0
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        }

        // Calendar mode: check if an event should interrupt the current task
        if dayPlanVM != nil && !isTimingEvent {
            checkEventInterruption()
        }
    }
}
