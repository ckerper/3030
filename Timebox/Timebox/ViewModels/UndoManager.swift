import Foundation

class TaskUndoManager: ObservableObject {
    struct Snapshot: Equatable {
        let tasks: [TaskItem]
        let dividerIndex: Int?
        let description: String
    }

    @Published private(set) var undoStack: [Snapshot] = []
    @Published private(set) var redoStack: [Snapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var undoCount: Int { undoStack.count }

    func saveState(tasks: [TaskItem], dividerIndex: Int?, description: String) {
        let snapshot = Snapshot(tasks: tasks, dividerIndex: dividerIndex, description: description)
        undoStack.append(snapshot)
        redoStack.removeAll() // new action clears redo stack
    }

    func undo(currentTasks: [TaskItem], currentDivider: Int?) -> Snapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        // Save current state to redo stack
        let current = Snapshot(tasks: currentTasks, dividerIndex: currentDivider, description: "redo")
        redoStack.append(current)
        return previous
    }

    func redo(currentTasks: [TaskItem], currentDivider: Int?) -> Snapshot? {
        guard let next = redoStack.popLast() else { return nil }
        // Save current state to undo stack
        let current = Snapshot(tasks: currentTasks, dividerIndex: currentDivider, description: "undo")
        undoStack.append(current)
        return next
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
