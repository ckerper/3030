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
                // Only show end-of-list divider if it wasn't already rendered
                // inside the ForEach (which renders when dividerIndex matches
                // a pending task's full-array index).
                if let divIdx = taskListVM.taskList.dividerIndex {
                    let alreadyRendered = taskListVM.pendingTasks.contains { task in
                        taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) == divIdx
                    }
                    if !alreadyRendered {
                        TimeDividerView {
                            taskListVM.removeDivider()
                        }
                        .listRowSeparator(.hidden)
                    }
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

                // MARK: - Completed Tasks Section
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
            .scrollBounceBehavior(.basedOnSize)
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
                // If the edited task is the active timer task, overwrite the timer
                // with the new duration so the edit fully takes effect.
                if updated.id == timerVM.activeTaskId {
                    timerVM.remainingTime = updated.duration
                    timerVM.totalDuration = updated.duration
                    timerVM.overtimeElapsed = 0
                    timerVM.isOvertime = false
                    timerVM.savedRemainingTimes.removeValue(forKey: updated.id)
                    timerVM.persistState()
                } else {
                    // Clear any saved remaining time so it uses the new planned duration
                    timerVM.savedRemainingTimes.removeValue(forKey: updated.id)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(insertIndex: addTaskInsertIndex, lastColor: taskListVM.lastTaskColor) { tasks in
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
        .sheet(isPresented: $showActionMenu) {
            if let task = actionMenuTask {
                TaskActionMenuView(
                    task: task,
                    timerVM: timerVM,
                    taskListVM: taskListVM,
                    gestureHints: gestureHints,
                    onEdit: { editingTask = task },
                    onInsertAbove: {
                        if let idx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                            addTaskInsertIndex = idx
                            showAddTask = true
                        }
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
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
                .foregroundColor(.primary.opacity(0.7))

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
        let projectedTimes = taskListVM.taskList.projectedTimes(
            activeTaskId: timerVM.activeTaskId,
            activeRemaining: timerVM.remainingTime,
            savedRemainingTimes: timerVM.savedRemainingTimes
        )

        return ForEach(Array(pending.enumerated()), id: \.element.id) { pendingIdx, task in
            let fullIdx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) ?? pendingIdx
            let times = fullIdx < projectedTimes.count ? projectedTimes[fullIdx] : nil

            // Compute display duration: live remaining for active, saved for bumped, planned for others
            let displayDuration: TimeInterval = {
                if task.id == timerVM.activeTaskId {
                    return timerVM.remainingTime
                } else if let saved = timerVM.savedRemainingTimes[task.id] {
                    return saved
                } else {
                    return task.duration
                }
            }()

            VStack(spacing: 0) {
                if taskListVM.taskList.dividerIndex == fullIdx {
                    TimeDividerView {
                        taskListVM.removeDivider()
                    }
                }

                taskRow(task: task, fullIndex: fullIdx, times: times, displayDuration: displayDuration)
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
                    taskListVM.moveToTop(taskId: task.id)
                } label: {
                    Label("Move to Top", systemImage: "arrow.up.to.line")
                }
                .tint(.blue)
            }
        }
        .onMove { source, destination in
            taskListVM.movePendingTask(from: source, to: destination)
        }
    }

    // MARK: - Completed Tasks Section

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
                .foregroundColor(.primary.opacity(0.6))
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Task Row (pending)

    private func taskRow(task: TaskItem, fullIndex: Int, times: (start: Date, end: Date)?, displayDuration: TimeInterval) -> some View {
        let isActiveTask = task.id == timerVM.activeTaskId
        return TaskRowView(
            task: task,
            index: fullIndex,
            isActive: isActiveTask && (timerVM.isRunning || timerVM.isOvertime || timerVM.remainingTime > 0),
            isCompleted: false,
            showTimes: settings.showPerTaskTimes,
            projectedStart: times?.start,
            projectedEnd: times?.end,
            displayDuration: displayDuration,
            plannedIncrement: currentIncrement,
            onAdjustDuration: { amount in
                taskListVM.adjustDuration(taskId: task.id, by: amount)
                // Also adjust the live timer if this is the active task
                if task.id == timerVM.activeTaskId {
                    timerVM.adjustTime(by: amount)
                }
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
                        .foregroundColor(.primary.opacity(0.6))
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
                            .foregroundColor(.primary.opacity(0.5))
                    }
                }
                .frame(width: 24)
            }

            Text(task.title)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.5))
                .strikethrough()
                .lineLimit(1)

            Spacer()

            Text(task.formattedDuration)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.4))

            // Menu for completed tasks
            Button {
                actionMenuTask = task
                showActionMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.4))
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

// MARK: - Task Action Menu (bottom sheet)

private struct TaskActionMenuView: View {
    let task: TaskItem
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var taskListVM: TaskListViewModel
    @ObservedObject var gestureHints: GestureHintManager
    let onEdit: () -> Void
    let onInsertAbove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            menuButton("Edit", icon: "pencil") {
                gestureHints.recordMenuAction("edit")
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onEdit() }
            }

            if !task.isCompleted {
                Divider()
                menuButton("Reset", icon: "arrow.counterclockwise") {
                    if task.id == timerVM.activeTaskId {
                        timerVM.resetCurrentTaskDuration()
                    } else {
                        timerVM.savedRemainingTimes.removeValue(forKey: task.id)
                    }
                    dismiss()
                }

                Divider()
                menuButton("Insert Divider Here", icon: "minus") {
                    if let idx = taskListVM.taskList.tasks.firstIndex(where: { $0.id == task.id }) {
                        taskListVM.setDivider(at: idx)
                    }
                    dismiss()
                }

                Divider()
                menuButton("Insert Task Above", icon: "plus") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onInsertAbove() }
                }
            }

            Divider()
            menuButton("Move to Bottom", icon: "arrow.down.to.line") {
                gestureHints.recordMenuAction("moveToBottom")
                taskListVM.moveToBottom(taskId: task.id)
                dismiss()
            }

            Spacer()
        }
        .padding(.top, 20)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                    .foregroundColor(.primary)
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
