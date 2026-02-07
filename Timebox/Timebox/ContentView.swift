import SwiftUI

struct ContentView: View {
    @StateObject private var taskListVM = TaskListViewModel()
    @StateObject private var timerVM = TimerViewModel()
    @StateObject private var presetVM = PresetViewModel()
    @StateObject private var settings = AppSettings.load()
    @StateObject private var gestureHints = GestureHintManager()
    @StateObject private var cloudKit = CloudKitService.shared

    @State private var showPresets = false
    @State private var showSettings = false
    @State private var showAddTask = false

    // Shared increment selector state
    @State private var selectedIncrementIndex = 1 // 0=1m, 1=5m, 2=15m
    private let incrementOptions: [TimeInterval] = [60, 300, 900]

    var currentIncrement: TimeInterval {
        incrementOptions[selectedIncrementIndex]
    }

    // Background color based on active task
    private var backgroundColor: Color {
        if timerVM.isRunning || timerVM.isOvertime,
           let task = timerVM.currentTask {
            return TaskColor.softBackground(for: task.colorName)
        }
        return Color(.systemGroupedBackground)
    }

    var body: some View {
        ZStack {
            // Full-screen background color
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: timerVM.currentColor)

            VStack(spacing: 0) {
                // Top toolbar
                toolbar

                // Total / Finish At above timer (#13)
                timeInfoHeader
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                // Timer section
                timerSection
                    .padding(.vertical, 12)

                // Complete button (when timer running)
                if timerVM.isRunning || timerVM.isOvertime {
                    completeButton
                        .padding(.bottom, 8)
                }

                // Task list
                TaskListView(
                    taskListVM: taskListVM,
                    timerVM: timerVM,
                    settings: settings,
                    gestureHints: gestureHints,
                    selectedIncrementIndex: $selectedIncrementIndex,
                    incrementOptions: incrementOptions
                )
            }
        }
        .preferredColorScheme(settings.colorScheme)
        .onAppear {
            timerVM.configure(taskList: taskListVM, settings: settings)
            if !taskListVM.taskList.tasks.isEmpty {
                timerVM.loadCurrentTask()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidChange)) { _ in
            // Reload data when iCloud sync occurs
        }
        .sheet(isPresented: $showPresets) {
            PresetsView(presetVM: presetVM, taskListVM: taskListVM)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(insertIndex: nil) { tasks in
                for task in tasks {
                    taskListVM.addTask(task)
                }
                if timerVM.currentTask == nil {
                    timerVM.loadCurrentTask()
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            // Undo/Redo
            HStack(spacing: 4) {
                Button {
                    let previousIndex = timerVM.currentTaskIndex
                    taskListVM.undo()
                    // #9: If undo restored a previously-completed task, jump timer back
                    timerVM.syncAfterUndo(taskListVM: taskListVM, previousIndex: previousIndex)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canUndo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!taskListVM.undoManager.canUndo)
                .overlay(alignment: .topTrailing) {
                    if taskListVM.undoManager.undoCount > 0 {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: -2)
                    }
                }

                Button {
                    taskListVM.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canRedo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!taskListVM.undoManager.canRedo)
            }

            Spacer()

            // Auto-loop indicator
            if settings.autoLoop {
                Image(systemName: "repeat")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }

            Spacer()

            // Actions
            HStack(spacing: 16) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                }

                Button {
                    showPresets = true
                } label: {
                    Image(systemName: "tray.full")
                        .font(.system(size: 18))
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Time Info Header (#13 — above timer)

    private var timeInfoHeader: some View {
        HStack {
            if settings.showTotalListTime {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(taskListVM.formattedTotalTime(timerRemaining: timerVM.remainingTime, activeIndex: timerVM.currentTaskIndex, isTimerActive: timerVM.isRunning || timerVM.isOvertime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            Spacer()

            if settings.showEstimatedFinish {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Finish at")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(taskListVM.estimatedFinishTime(timerRemaining: timerVM.remainingTime, activeIndex: timerVM.currentTaskIndex, isTimerActive: timerVM.isRunning || timerVM.isOvertime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 12) {
            if settings.showPieTimer {
                PieTimerView(
                    remainingTime: timerVM.remainingTime,
                    totalDuration: timerVM.totalDuration,
                    isOvertime: timerVM.isOvertime,
                    overtimeElapsed: timerVM.overtimeElapsed,
                    color: TaskColor.color(for: timerVM.currentColor)
                )
                .frame(width: 180, height: 180)
                .onTapGesture {
                    timerVM.startOrPause()
                }
            } else {
                TimerDialView(
                    timerVM: timerVM,
                    settings: settings,
                    dialSize: 220
                )
            }

            // Timer adjustment buttons — use shared increment
            if timerVM.isRunning || timerVM.remainingTime > 0 || timerVM.isOvertime {
                TimerAdjustmentButtons(timerVM: timerVM, increment: currentIncrement)
            }

            // Current task title
            if let task = timerVM.currentTask {
                Text(task.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            timerVM.completeCurrentTask()
        } label: {
            Label("Complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.green)
                )
        }
    }
}

#Preview {
    ContentView()
}
