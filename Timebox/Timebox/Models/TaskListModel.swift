import Foundation

struct TaskListModel: Codable, Equatable {
    var tasks: [TaskItem]
    var dividerIndex: Int? // index where the time divider sits (tasks above are "active")

    init(tasks: [TaskItem] = [], dividerIndex: Int? = nil) {
        self.tasks = tasks
        self.dividerIndex = dividerIndex
    }

    // Tasks above the divider (or all tasks if no divider)
    var activeTasks: [TaskItem] {
        guard let idx = dividerIndex else { return tasks }
        return Array(tasks.prefix(idx))
    }

    // Total duration of tasks above the divider
    var totalDuration: TimeInterval {
        activeTasks.filter { !$0.isCompleted }.reduce(0) { $0 + $1.duration }
    }

    // Estimated finish time from now
    func estimatedFinishTime(from start: Date = Date()) -> Date {
        start.addingTimeInterval(totalDuration)
    }

    // Projected start/end times for each task
    func projectedTimes(from start: Date = Date()) -> [(start: Date, end: Date)] {
        var current = start
        return tasks.map { task in
            let taskStart = current
            let taskEnd = current.addingTimeInterval(task.duration)
            current = taskEnd
            return (start: taskStart, end: taskEnd)
        }
    }

    mutating func moveToBottom(taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let task = tasks.remove(at: index)
        tasks.append(task)
        // Adjust divider if needed
        if let div = dividerIndex, index < div {
            dividerIndex = div - 1
        }
    }

    mutating func moveToTop(taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let task = tasks.remove(at: index)
        tasks.insert(task, at: 0)
        // Adjust divider if needed
        if let div = dividerIndex, index >= div {
            dividerIndex = div + 1
        }
    }

    mutating func insertTask(_ task: TaskItem, at index: Int) {
        let safeIndex = min(max(index, 0), tasks.count)
        tasks.insert(task, at: safeIndex)
        if let div = dividerIndex, safeIndex <= div {
            dividerIndex = div + 1
        }
    }

    mutating func removeTask(at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks.remove(at: index)
        if let div = dividerIndex {
            if index < div {
                dividerIndex = div - 1
            } else if index == div {
                dividerIndex = nil
            }
        }
    }

    mutating func removeDuplicates() {
        var seen = Set<String>()
        tasks = tasks.filter { task in
            let key = task.title.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}
