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
    }

    func stop() {
        pause()
        remainingTime = 0
        overtimeElapsed = 0
        isOvertime = false
        activeTaskId = nil
        timerStartedAt = nil
        savedRemainingTimes.removeAll()
    }

    // MARK: - Task Completion

    func completeCurrentTask() {
        guard let taskList = taskList, let id = activeTaskId else { return }
        guard let idx = taskList.taskList.tasks.firstIndex(where: { $0.id == id }) else { return }

        // Clear any saved time for this task
        savedRemainingTimes.removeValue(forKey: id)

        // Mark completed
        taskList.completeTask(at: idx)

        // Advance to next first pending
        advanceToNext()
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
            }
        } else {
            remainingTime = max(0, remainingTime + amount)
            totalDuration = max(totalDuration, remainingTime)
        }
    }

    // MARK: - Undo Sync

    func syncAfterUndo(taskListVM: TaskListViewModel) {
        // After undo, the first pending task may have changed.
        // Just re-sync to whatever is now first.
        syncToFirstPending()
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
