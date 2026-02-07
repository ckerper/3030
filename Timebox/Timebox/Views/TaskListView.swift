import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskListVM: TaskListViewModel
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var gestureHints: GestureHintManager

    // Shared increment from ContentView
    @Binding var selectedIncrementIndex: Int
    let incrementOptions: [TimeInterval]

    @State private var editingTask: TaskItem?
    @State private var showAddTask = false
    @State private var addTaskInsertIndex: Int?
    @State private var showActionMenu = false
    @State private var actionMenuTask: TaskItem?
    @State private var gestureHintText: String?
    @State private var showCompletedSection = false
    @State private var showClearAllConfirm = false
    @State private var showClearCompletedConfirm = false

    private let incrementLabels = ["1m", "5m", "15m"]

    private var currentIncrement: TimeInterval {
        guard selectedIncrementIndex < incrementOptions.count else { return 300 }
        return incrementOptions[selectedIncrementIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Increment selector
            if !taskListVM.taskList.tasks.isEmpty {
                incrementSelector
            }

            // Task list
            List {
                // MARK: - Pending Tasks Section
                pendingTasksSection

                // MARK: - Divider at end if applicable
                if let divIdx = taskListVM.taskList.dividerIndex,
                   divIdx == taskListVM.pendingTasks.count {
                    TimeDividerView {
                        taskListVM.removeDivider()
                    }
                    .listRowSeparator(.hidden)
                }

                // Auto-loop indicator
                if settings.autoLoop {
                    HStack {
                        Image(systemName: "repeat")
                            .font(.caption)
                        Text("List will repeat")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                }

                // MARK: - Completed Tasks Section (#10)
                if !taskListVM.completedTasks.isEmpty {
                    completedTasksSection
                }

                // MARK: - Clear Buttons
                if !taskListVM.taskList.tasks.isEmpty {
                    clearButtonsSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .confirmationDialog("Clear All Tasks?", isPresented: $showClearAllConfirm) {
            Button("Clear All", role: .destructive) {
                taskListVM.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(taskListVM.taskList.tasks.count) tasks. You can undo this.")
        }
        .confirmationDialog("Clear Completed Tasks?", isPresented: $showClearCompletedConfirm) {
            Button("Clear \(taskListVM.completedTasks.count) Completed", role: .destructive) {
                taskListVM.clearCompleted()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(taskListVM.completedTasks.count) completed tasks. You can undo this.")
        }
        .sheet(item: $editingTask) { task in
            TaskEditView(task: task) { updated in
                taskListVM.updateTask(updated)
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(insertIndex: addTaskInsertIndex) { tasks in
                for (i, task) in tasks.enumerated() {
                    if let insertIdx = addTaskInsertIndex {
                        taskListVM.addTask(task, at: insertIdx + i)
                    } else {
                        taskListVM.addTask(task)
                    }
                }
                addTaskInsertIndex = nil
            }
        }
        .confirmationDialog(
            actionMenuTask?.title ?? "Task",
            isPresented: $showActionMenu,
            presenting: actionMenuTask
        ) { task in
            Button("Edit") {
                gestureHints.recordMenuAction("edit")
                editingTask = task
            }
            Button("Move to Top") {
                gestureHints.recordMenuAction("moveToTop")
                taskListVM.moveToTop(taskId: task.id)
            }
            Button("Move to Bottom") {
                gestureHints.recordMenuAction("moveToBottom")
                taskListVM.moveToBottom(taskId: task.id)
            }
            if !task.isCompleted {
                Button("Complete") {
                    if task.id == timerVM.activeTaskId {
                        timerVM.completeCurrentTask()
                    } else if let idx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                        taskListVM.completeTask(at: idx)
                    }
                }
                Button("Insert Divider Here") {
                    if let idx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                        taskListVM.setDivider(at: idx)
                    }
                }
                Button("Insert Task Above") {
                    if let idx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                        addTaskInsertIndex = idx
                        showAddTask = true
                    }
                }
            }
            Button("Delete", role: .destructive) {
                gestureHints.recordMenuAction("delete")
                taskListVM.removeTask(id: task.id)
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .bottom) {
            if let hint = gestureHintText {
                Text(hint)
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground))
                            .shadow(radius: 4)
                    )
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { gestureHintText = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Increment Selector

    private var incrementSelector: some View {
        HStack {
            Text("Adjust by:")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Increment", selection: $selectedIncrementIndex) {
                ForEach(0..<incrementLabels.count, id: \.self) { i in
                    Text(incrementLabels[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Pending Tasks

    private var pendingTasksSection: some View {
        let pending = taskListVM.pendingTasks
        let projectedTimes = taskListVM.taskList.projectedTimes()

        return ForEach(Array(pending.enumerated()), id: \.element.id) { pendingIdx, task in
            let fullIdx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) ?? pendingIdx
            let times = fullIdx < projectedTimes.count ? projectedTimes[fullIdx] : nil

            VStack(spacing: 0) {
                if taskListVM.taskList.dividerIndex == fullIdx {
                    TimeDividerView {
                        taskListVM.removeDivider()
                    }
                }

                taskRow(task: task, fullIndex: fullIdx, times: times)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    taskListVM.removeTask(id: task.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    taskListVM.moveToBottom(taskId: task.id)
                } label: {
                    Label("Move to Bottom", systemImage: "arrow.down.to.line")
                }
                .tint(.orange)
            }
        }
        .onMove { source, destination in
            taskListVM.movePendingTask(from: source, to: destination)
        }
    }

    // MARK: - Completed Tasks Section (#10)

    private var completedTasksSection: some View {
        Section {
            if showCompletedSection {
                ForEach(taskListVM.completedTasks) { task in
                    completedRow(task: task)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                taskListVM.removeTask(id: task.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                taskListVM.moveToTop(taskId: task.id)
                            } label: {
                                Label("Restore to Top", systemImage: "arrow.up.to.line")
                            }
                            .tint(.blue)
                        }
                }
            }
        } header: {
            Button {
                withAnimation {
                    showCompletedSection.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showCompletedSection ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("Completed (\(taskListVM.completedTasks.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Task Row (pending)

    private func taskRow(task: TaskItem, fullIndex: Int, times: (start: Date, end: Date)?) -> some View {
        let isActiveTask = task.id == timerVM.activeTaskId
        return TaskRowView(
            task: task,
            index: fullIndex,
            isActive: isActiveTask && (timerVM.isRunning || timerVM.isOvertime || timerVM.remainingTime > 0),
            isCompleted: false,
            showDuration: settings.showTaskDuration,
            showTimes: settings.showPerTaskTimes,
            projectedStart: times?.start,
            projectedEnd: times?.end,
            plannedIncrement: currentIncrement,
            onAdjustDuration: { amount in
                taskListVM.adjustDuration(taskId: task.id, by: amount)
            },
            onEdit: {
                editingTask = task
            },
            onComplete: {
                if isActiveTask {
                    timerVM.completeCurrentTask()
                } else {
                    taskListVM.completeTask(at: fullIndex)
                }
            },
            onMenu: {
                actionMenuTask = task
                showActionMenu = true
            }
        )
    }

    // MARK: - Clear Buttons

    private var clearButtonsSection: some View {
        HStack(spacing: 12) {
            if !taskListVM.completedTasks.isEmpty {
                Button {
                    showClearCompletedConfirm = true
                } label: {
                    Label("Clear Completed", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                showClearAllConfirm = true
            } label: {
                Label("Clear All", systemImage: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    // MARK: - Completed Row

    private func completedRow(task: TaskItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(task.color.opacity(0.4))
                .frame(width: 6)
                .padding(.vertical, 4)

            if !task.icon.isEmpty {
                Group {
                    if task.icon.unicodeScalars.first?.properties.isEmoji == true
                        && task.icon.unicodeScalars.count <= 2 {
                        Text(task.icon)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: task.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 24)
            }

            Text(task.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .strikethrough()
                .lineLimit(1)

            Spacer()

            Text(task.formattedDuration)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))

            // Menu for completed tasks (#12)
            Button {
                actionMenuTask = task
                showActionMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .opacity(0.8)
    }
}

#Preview {
    let taskListVM = TaskListViewModel()
    let timerVM = TimerViewModel()
    let settings = AppSettings()

    TaskListView(
        taskListVM: taskListVM,
        timerVM: timerVM,
        settings: settings,
        gestureHints: GestureHintManager(),
        selectedIncrementIndex: .constant(1),
        incrementOptions: [60, 300, 900]
    )
}
