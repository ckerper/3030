import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskListVM: TaskListViewModel
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var gestureHints: GestureHintManager

    @State private var editingTask: TaskItem?
    @State private var showAddTask = false
    @State private var addTaskInsertIndex: Int?
    @State private var showActionMenu = false
    @State private var actionMenuTask: TaskItem?
    @State private var gestureHintText: String?
    @State private var showDividerInsert = false

    // Increment selector for planned tasks
    @State private var selectedIncrementIndex = 1 // 0=1m, 1=5m, 2=15m
    private let incrementOptions: [TimeInterval] = [60, 300, 900]
    private let incrementLabels = ["1m", "5m", "15m"]

    private var currentIncrement: TimeInterval {
        incrementOptions[selectedIncrementIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Increment selector
            if !taskListVM.taskList.tasks.isEmpty {
                incrementSelector
            }

            // Task list
            List {
                ForEach(Array(taskListVM.taskList.tasks.enumerated()), id: \.element.id) { index, task in
                    VStack(spacing: 0) {
                        // Divider before this row if applicable
                        if taskListVM.taskList.dividerIndex == index {
                            TimeDividerView {
                                taskListVM.removeDivider()
                            }
                        }

                        taskRow(task: task, index: index)
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
                    taskListVM.moveTask(from: source, to: destination)
                }

                // Divider at end if applicable
                if let divIdx = taskListVM.taskList.dividerIndex,
                   divIdx == taskListVM.taskList.tasks.count {
                    TimeDividerView {
                        taskListVM.removeDivider()
                    }
                    .listRowSeparator(.hidden)
                }

                // Footer info
                footerSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
            Button("Delete", role: .destructive) {
                gestureHints.recordMenuAction("delete")
                taskListVM.removeTask(id: task.id)
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .bottom) {
            // Gesture hint toast
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

    // MARK: - Task Row

    private func taskRow(task: TaskItem, index: Int) -> some View {
        let projectedTimes = taskListVM.taskList.projectedTimes()
        let times = index < projectedTimes.count ? projectedTimes[index] : nil

        return TaskRowView(
            task: task,
            index: index,
            isActive: index == timerVM.currentTaskIndex && timerVM.isRunning,
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
            onMenu: {
                actionMenuTask = task
                showActionMenu = true
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-tap to edit
            editingTask = task
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            if settings.showTotalListTime {
                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taskListVM.formattedTotalTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }

            if settings.showEstimatedFinish {
                HStack {
                    Text("Finish at")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taskListVM.estimatedFinishTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            if settings.autoLoop {
                HStack {
                    Image(systemName: "repeat")
                        .font(.caption)
                    Text("List will repeat")
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
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
        gestureHints: GestureHintManager()
    )
}
