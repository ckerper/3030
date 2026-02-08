import Foundation

class TaskUndoManager: ObservableObject {
    struct TimerSnapshot: Equatable, Codable {
        var activeTaskId: UUID?
        var remainingTime: TimeInterval
        var totalDuration: TimeInterval
        var isOvertime: Bool
        var overtimeElapsed: TimeInterval
        var isRunning: Bool
        var savedRemainingTimes: [UUID: TimeInterval]
    }

    struct Snapshot: Equatable {
        let tasks: [TaskItem]
        let dividerIndex: Int?
        let description: String
        var timerState: TimerSnapshot?
    }

    @Published private(set) var undoStack: [Snapshot] = []
    @Published private(set) var redoStack: [Snapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var undoCount: Int { undoStack.count }

    func saveState(tasks: [TaskItem], dividerIndex: Int?, description: String, timerState: TimerSnapshot? = nil) {
        let snapshot = Snapshot(tasks: tasks, dividerIndex: dividerIndex, description: description, timerState: timerState)
        undoStack.append(snapshot)
        redoStack.removeAll() // new action clears redo stack
    }

    func undo(currentTasks: [TaskItem], currentDivider: Int?, currentTimerState: TimerSnapshot? = nil) -> Snapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        // Save current state to redo stack (including timer state)
        let current = Snapshot(tasks: currentTasks, dividerIndex: currentDivider, description: "redo", timerState: currentTimerState)
        redoStack.append(current)
        return previous
    }

    func redo(currentTasks: [TaskItem], currentDivider: Int?, currentTimerState: TimerSnapshot? = nil) -> Snapshot? {
        guard let next = redoStack.popLast() else { return nil }
        // Save current state to undo stack (including timer state)
        let current = Snapshot(tasks: currentTasks, dividerIndex: currentDivider, description: "undo", timerState: currentTimerState)
        undoStack.append(current)
        return next
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
