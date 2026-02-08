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

    /// Saved remaining times for tasks that were interrupted (bumped down).
    /// Key: task ID, Value: remaining seconds when paused/bumped.
    var savedRemainingTimes: [UUID: TimeInterval] = [:]

    // MARK: - Dependencies
    private var timer: AnyCancellable?
    private var taskList: TaskListViewModel?
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
        guard let taskList = taskList, let id = activeTaskId else { return nil }
        return taskList.taskList.tasks.first(where: { $0.id == id })
    }

    var currentColor: String {
        currentTask?.colorName ?? "blue"
    }

    // MARK: - Setup

    func configure(taskList: TaskListViewModel, settings: AppSettings) {
        self.taskList = taskList
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
        guard let taskList = taskList else { return }

        // Make sure we're pointed at the first pending task
        if activeTaskId == nil {
            if let first = taskList.pendingTasks.first {
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

    func syncAfterUndo(taskListVM: TaskListViewModel) {
        // After undo, the first pending task may have changed.
        // Just re-sync to whatever is now first.
        syncToFirstPending()
    }

    // MARK: - State Persistence (survive app close/reopen)

    func persistState() {
        let defaults = UserDefaults.standard
        if let id = activeTaskId {
            defaults.set(id.uuidString, forKey: kTimerActiveTaskId)
        } else {
            defaults.removeObject(forKey: kTimerActiveTaskId)
        }
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
        let defaults = UserDefaults.standard

        // Restore savedRemainingTimes
        if let encoded = defaults.dictionary(forKey: kTimerSavedRemainingTimes) as? [String: Double] {
            savedRemainingTimes = encoded.reduce(into: [UUID: TimeInterval]()) { dict, pair in
                if let uuid = UUID(uuidString: pair.key) {
                    dict[uuid] = pair.value
                }
            }
        }

        guard let idString = defaults.string(forKey: kTimerActiveTaskId),
              let savedId = UUID(uuidString: idString) else {
            return
        }

        let savedRemaining = defaults.double(forKey: kTimerRemainingTime)
        let savedTotal = defaults.double(forKey: kTimerTotalDuration)
        let wasRunning = defaults.bool(forKey: kTimerIsRunning)
        let wasOvertime = defaults.bool(forKey: kTimerIsOvertime)
        let savedOvertime = defaults.double(forKey: kTimerOvertimeElapsed)
        let savedTimestamp = defaults.double(forKey: kTimerLastSaveDate)

        // Verify this task still exists and is pending
        guard let taskList = taskList,
              taskList.taskList.tasks.contains(where: { $0.id == savedId && !$0.isCompleted }) else {
            return
        }

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
    }
}
