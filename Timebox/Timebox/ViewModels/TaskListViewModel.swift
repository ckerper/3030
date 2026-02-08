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

    // MARK: - Auto-Color (#3)

    /// Returns the color of the last non-completed task in the list (for auto-color assignment).
    var lastTaskColor: String? {
        taskList.tasks.last(where: { !$0.isCompleted })?.colorName
    }

    // MARK: - Task CRUD

    func addTask(_ task: TaskItem, at index: Int? = nil) {
        saveUndoState(description: "Add task")
        // Auto-assign color if task still has the default "blue"
        var newTask = task
        if newTask.colorName == "blue" {
            newTask.colorName = TaskColor.nextColor(after: lastTaskColor)
        }
        if let index = index {
            // When inserting at a position, pick color based on the task above
            let colorAbove = index > 0 ? taskList.tasks[index - 1].colorName : lastTaskColor
            if task.colorName == "blue" {
                newTask.colorName = TaskColor.nextColor(after: colorAbove)
            }
            taskList.insertTask(newTask, at: index)
        } else {
            taskList.tasks.append(newTask)
        }
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
            taskList.tasks.append(newTask)
        }
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
        saveUndoState(description: "Complete task")
        taskList.tasks[index].isCompleted = true
    }

    /// Mark a completed task as not completed and move it back to the active list.
    func uncompleteTask(id: UUID) {
        saveUndoState(description: "Uncomplete task")
        if let index = taskList.tasks.firstIndex(where: { $0.id == id }) {
            taskList.tasks[index].isCompleted = false
        }
    }

    func resetCompletedStates() {
        for i in taskList.tasks.indices {
            taskList.tasks[i].isCompleted = false
        }
    }

    // MARK: - Computed: Separate active vs completed (#10)

    var pendingTasks: [TaskItem] {
        taskList.tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [TaskItem] {
        taskList.tasks.filter { $0.isCompleted }
    }

    // The index in the full tasks array for a given pending task position
    func fullIndex(forPendingIndex pendingIdx: Int) -> Int? {
        let pending = pendingTasks
        guard pendingIdx < pending.count else { return nil }
        let targetId = pending[pendingIdx].id
        return taskList.tasks.firstIndex(where: { $0.id == targetId })
    }

    // MARK: - Reordering

    func moveTask(from source: IndexSet, to destination: Int) {
        saveUndoState(description: "Reorder tasks")
        taskList.tasks.move(fromOffsets: source, toOffset: destination)
    }

    func movePendingTask(from source: IndexSet, to destination: Int) {
        saveUndoState(description: "Reorder tasks")
        // Map pending indices to full list indices
        let pending = pendingTasks
        var fullTasks = taskList.tasks

        // Get the items being moved
        let movedItems = source.map { pending[$0] }
        // Remove them from the full list
        for item in movedItems {
            if let idx = fullTasks.firstIndex(where: { $0.id == item.id }) {
                fullTasks.remove(at: idx)
            }
        }
        // Find insertion point in full list
        let pendingAfterRemove = fullTasks.filter { !$0.isCompleted }
        let insertFullIdx: Int
        if destination >= pendingAfterRemove.count {
            // Insert at the end of pending tasks (before completed tasks)
            if let lastPendingIdx = fullTasks.lastIndex(where: { !$0.isCompleted }) {
                insertFullIdx = lastPendingIdx + 1
            } else {
                insertFullIdx = 0
            }
        } else {
            let targetId = pendingAfterRemove[destination].id
            insertFullIdx = fullTasks.firstIndex(where: { $0.id == targetId }) ?? fullTasks.count
        }
        // Insert items
        for (offset, item) in movedItems.enumerated() {
            fullTasks.insert(item, at: insertFullIdx + offset)
        }
        taskList.tasks = fullTasks
    }

    func moveToBottom(taskId: UUID) {
        saveUndoState(description: "Move to bottom")
        // If the task is completed, uncomplete it and move to bottom of pending list
        if let index = taskList.tasks.firstIndex(where: { $0.id == taskId }),
           taskList.tasks[index].isCompleted {
            taskList.tasks[index].isCompleted = false
        }
        taskList.moveToBottom(taskId: taskId)
    }

    func moveToTop(taskId: UUID) {
        saveUndoState(description: "Move to top")
        // If the task is completed, uncomplete it
        if let index = taskList.tasks.firstIndex(where: { $0.id == taskId }),
           taskList.tasks[index].isCompleted {
            taskList.tasks[index].isCompleted = false
        }
        taskList.moveToTop(taskId: taskId)
    }

    // MARK: - Bulk Clear

    func clearAll() {
        guard !taskList.tasks.isEmpty else { return }
        saveUndoState(description: "Clear all")
        taskList.tasks.removeAll()
        taskList.dividerIndex = nil
    }

    func clearCompleted() {
        guard taskList.tasks.contains(where: { $0.isCompleted }) else { return }
        saveUndoState(description: "Clear completed")
        taskList.tasks.removeAll { $0.isCompleted }
    }

    // MARK: - Duration Adjustment

    func adjustDuration(taskId: UUID, by amount: TimeInterval) {
        saveUndoState(description: "Adjust duration")
        if let index = taskList.tasks.firstIndex(where: { $0.id == taskId }) {
            let newDuration = max(1, min(86400, taskList.tasks[index].duration + amount))
            taskList.tasks[index].duration = newDuration
        }
    }

    // MARK: - Reset Colors

    func resetTaskColors() {
        saveUndoState(description: "Reset task colors")
        for i in taskList.tasks.indices {
            taskList.tasks[i].colorName = TaskColor.paletteNames[i % TaskColor.paletteNames.count]
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

    func loadPresetToTop(_ preset: Preset) {
        saveUndoState(description: "Load preset to top")
        let newTasks = preset.tasks.map { task in
            var t = task
            t.id = UUID()
            t.isCompleted = false
            return t
        }
        taskList.tasks.insert(contentsOf: newTasks, at: 0)
    }

    func loadPresetToBottom(_ preset: Preset) {
        saveUndoState(description: "Load preset to bottom")
        let newTasks = preset.tasks.map { task in
            var t = task
            t.id = UUID()
            t.isCompleted = false
            return t
        }
        taskList.tasks.append(contentsOf: newTasks)
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

    // MARK: - Computed Properties (#5: total time uses timer remaining for active task)

    var totalListTime: TimeInterval {
        taskList.totalDuration
    }

    func liveTotalTime(timerRemaining: TimeInterval, activeIndex: Int, isTimerActive: Bool) -> TimeInterval {
        let tasks = taskList.activeTasks
        var total: TimeInterval = 0
        for (i, task) in tasks.enumerated() {
            if task.isCompleted { continue }
            if isTimerActive && i == activeIndex {
                // Use the live remaining time instead of planned duration
                total += max(0, timerRemaining)
            } else {
                total += task.duration
            }
        }
        return total
    }

    func formattedTotalTime(timerRemaining: TimeInterval, activeIndex: Int, isTimerActive: Bool) -> String {
        TimeFormatting.format(liveTotalTime(timerRemaining: timerRemaining, activeIndex: activeIndex, isTimerActive: isTimerActive))
    }

    func estimatedFinishTime(timerRemaining: TimeInterval, activeIndex: Int, isTimerActive: Bool) -> String {
        let remaining = liveTotalTime(timerRemaining: timerRemaining, activeIndex: activeIndex, isTimerActive: isTimerActive)
        return TimeFormatting.formatClockTime(Date().addingTimeInterval(remaining))
    }

    // Legacy (non-live) versions for when timer isn't relevant
    var formattedTotalTime: String {
        TimeFormatting.format(totalListTime)
    }

    var estimatedFinishTimeString: String {
        TimeFormatting.formatClockTime(taskList.estimatedFinishTime())
    }
}
