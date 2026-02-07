import Foundation
import Combine
import UIKit

class TimerViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isRunning: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var overtimeElapsed: TimeInterval = 0
    @Published var isOvertime: Bool = false
    @Published var currentTaskIndex: Int = 0
    @Published var timerStartedAt: Date?

    // MARK: - Dependencies
    private var timer: AnyCancellable?
    private var taskList: TaskListViewModel?
    private var settings: AppSettings?

    // Total duration of the current task (for progress calculation)
    @Published var totalDuration: TimeInterval = 0

    // Progress from 0 to 1 (for dial)
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        if isOvertime { return 0 }
        return max(0, min(1, 1.0 - (remainingTime / totalDuration)))
    }

    // Formatted display string
    var displayTime: String {
        if isOvertime {
            return TimeFormatting.formatOvertime(overtimeElapsed)
        }
        return TimeFormatting.format(remainingTime)
    }

    // MARK: - Setup

    func configure(taskList: TaskListViewModel, settings: AppSettings) {
        self.taskList = taskList
        self.settings = settings
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
        let tasks = taskList.taskList.tasks
        guard currentTaskIndex < tasks.count else { return }

        if remainingTime <= 0 && !isOvertime {
            // Starting fresh on this task
            let task = tasks[currentTaskIndex]
            remainingTime = task.duration
            totalDuration = task.duration
        }

        isRunning = true
        timerStartedAt = Date()

        // Keep screen on if setting enabled
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
        currentTaskIndex = 0
        timerStartedAt = nil
    }

    // MARK: - Task Navigation

    func completeCurrentTask() {
        guard let taskList = taskList else { return }

        // Mark current task as completed
        if currentTaskIndex < taskList.taskList.tasks.count {
            taskList.completeTask(at: currentTaskIndex)
        }

        advanceToNext()
    }

    func advanceToNext() {
        guard let taskList = taskList, let settings = settings else { return }

        // Find the next non-completed task after current
        let tasks = taskList.taskList.tasks
        var nextIndex: Int? = nil
        for i in (currentTaskIndex + 1)..<tasks.count {
            if !tasks[i].isCompleted {
                nextIndex = i
                break
            }
        }

        if let next = nextIndex {
            currentTaskIndex = next
            loadCurrentTask()
            if settings.autoStartNextTask {
                start()
            } else {
                pause()
            }
        } else if settings.autoLoop {
            // Loop: reset all and go back to first
            currentTaskIndex = 0
            taskList.resetCompletedStates()
            loadCurrentTask()
            if settings.autoStartNextTask {
                start()
            } else {
                pause()
            }
        } else {
            // List complete
            stop()
        }
    }

    func loadTask(at index: Int) {
        guard let taskList = taskList else { return }
        let tasks = taskList.taskList.tasks
        guard index < tasks.count else { return }

        pause()
        currentTaskIndex = index
        loadCurrentTask()
    }

    func loadCurrentTask() {
        guard let taskList = taskList else { return }
        let tasks = taskList.taskList.tasks
        guard currentTaskIndex < tasks.count else { return }

        let task = tasks[currentTaskIndex]
        remainingTime = task.duration
        totalDuration = task.duration
        overtimeElapsed = 0
        isOvertime = false
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

    // MARK: - Current Task Info

    var currentTask: TaskItem? {
        guard let taskList = taskList else { return nil }
        let tasks = taskList.taskList.tasks
        guard currentTaskIndex < tasks.count else { return nil }
        return tasks[currentTaskIndex]
    }

    var currentColor: String {
        currentTask?.colorName ?? "blue"
    }

    // MARK: - Undo Sync (#9)

    /// Called after undo to detect if the previously-active task was uncompleted,
    /// and if so, jump the timer back to it.
    func syncAfterUndo(taskListVM: TaskListViewModel, previousIndex: Int) {
        let tasks = taskListVM.taskList.tasks
        // If the task at previousIndex exists and is no longer completed,
        // it means undo restored it — jump back to it
        if previousIndex < tasks.count && !tasks[previousIndex].isCompleted {
            // Check if we had advanced past it
            if currentTaskIndex > previousIndex || (currentTaskIndex != previousIndex) {
                pause()
                currentTaskIndex = previousIndex
                loadCurrentTask()
            }
        }
        // Also handle the case where the current task index is now out of bounds
        if currentTaskIndex >= tasks.count && !tasks.isEmpty {
            currentTaskIndex = tasks.count - 1
            loadCurrentTask()
        }
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
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        }
    }
}
