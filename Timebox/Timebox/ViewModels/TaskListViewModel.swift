import Foundation
import Combine

class TaskListViewModel: ObservableObject {
    @Published var taskList: TaskListModel {
        didSet { save() }
    }
    @Published var undoManager = TaskUndoManager()

    private let storageKey = "activeTaskList"

    init() {
        self.taskList = TaskListModel()
        self.taskList = load()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(taskList) {
            UserDefaults.standard.set(data, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
        }
    }

    private func load() -> TaskListModel {
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
           let list = try? JSONDecoder().decode(TaskListModel.self, from: data) {
            return list
        }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let list = try? JSONDecoder().decode(TaskListModel.self, from: data) {
            return list
        }
        return TaskListModel()
    }

    // MARK: - Task CRUD

    func addTask(_ task: TaskItem, at index: Int? = nil) {
        saveUndoState(description: "Add task")
        if let index = index {
            taskList.insertTask(task, at: index)
        } else {
            taskList.tasks.append(task)
        }
    }

    func addTasks(_ tasks: [TaskItem]) {
        saveUndoState(description: "Add tasks")
        taskList.tasks.append(contentsOf: tasks)
    }

    func removeTask(at index: Int) {
        saveUndoState(description: "Delete task")
        taskList.removeTask(at: index)
    }

    func removeTask(id: UUID) {
        guard let index = taskList.tasks.firstIndex(where: { $0.id == id }) else { return }
        removeTask(at: index)
    }

    func updateTask(_ task: TaskItem) {
        saveUndoState(description: "Edit task")
        if let index = taskList.tasks.firstIndex(where: { $0.id == task.id }) {
            taskList.tasks[index] = task
        }
    }

    func completeTask(at index: Int) {
        guard taskList.tasks.indices.contains(index) else { return }
        taskList.tasks[index].isCompleted = true
    }

    func resetCompletedStates() {
        for i in taskList.tasks.indices {
            taskList.tasks[i].isCompleted = false
        }
    }

    // MARK: - Reordering

    func moveTask(from source: IndexSet, to destination: Int) {
        saveUndoState(description: "Reorder tasks")
        taskList.tasks.move(fromOffsets: source, toOffset: destination)
    }

    func moveToBottom(taskId: UUID) {
        saveUndoState(description: "Move to bottom")
        taskList.moveToBottom(taskId: taskId)
    }

    func moveToTop(taskId: UUID) {
        saveUndoState(description: "Move to top")
        taskList.moveToTop(taskId: taskId)
    }

    // MARK: - Duration Adjustment

    func adjustDuration(taskId: UUID, by amount: TimeInterval) {
        saveUndoState(description: "Adjust duration")
        if let index = taskList.tasks.firstIndex(where: { $0.id == taskId }) {
            let newDuration = max(1, min(32400, taskList.tasks[index].duration + amount))
            taskList.tasks[index].duration = newDuration
        }
    }

    // MARK: - Divider

    func setDivider(at index: Int?) {
        saveUndoState(description: "Move divider")
        taskList.dividerIndex = index
    }

    func removeDivider() {
        saveUndoState(description: "Remove divider")
        taskList.dividerIndex = nil
    }

    // MARK: - Presets

    func loadPreset(_ preset: Preset, replace: Bool = true, removeDuplicates: Bool = false) {
        saveUndoState(description: "Load preset")
        if replace {
            taskList.tasks = preset.tasks
            taskList.dividerIndex = nil
        } else {
            taskList.tasks.append(contentsOf: preset.tasks)
        }
        if removeDuplicates {
            taskList.removeDuplicates()
        }
        undoManager.clear() // Reset undo stack when loading preset
    }

    func createPreset(name: String) -> Preset {
        Preset(name: name, tasks: taskList.tasks)
    }

    // MARK: - Undo/Redo

    private func saveUndoState(description: String) {
        undoManager.saveState(
            tasks: taskList.tasks,
            dividerIndex: taskList.dividerIndex,
            description: description
        )
    }

    func undo() {
        if let snapshot = undoManager.undo(
            currentTasks: taskList.tasks,
            currentDivider: taskList.dividerIndex
        ) {
            taskList.tasks = snapshot.tasks
            taskList.dividerIndex = snapshot.dividerIndex
        }
    }

    func redo() {
        if let snapshot = undoManager.redo(
            currentTasks: taskList.tasks,
            currentDivider: taskList.dividerIndex
        ) {
            taskList.tasks = snapshot.tasks
            taskList.dividerIndex = snapshot.dividerIndex
        }
    }

    // MARK: - Computed Properties

    var totalListTime: TimeInterval {
        taskList.totalDuration
    }

    var formattedTotalTime: String {
        TimeFormatting.format(totalListTime)
    }

    var estimatedFinishTime: String {
        TimeFormatting.formatClockTime(taskList.estimatedFinishTime())
    }
}
