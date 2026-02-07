import SwiftUI

struct ContentView: View {
    @StateObject private var taskListVM = TaskListViewModel()
    @StateObject private var timerVM = TimerViewModel()
    @StateObject private var presetVM = PresetViewModel()
    @StateObject private var settings = AppSettings.load()
    @StateObject private var gestureHints = GestureHintManager()
    @StateObject private var cloudKit = CloudKitService.shared

    @Environment(\.colorScheme) var colorScheme

    @State private var showingPresets = false
    @State private var showSettings = false
    @State private var showAddTask = false

    // Shared increment selector state
    @State private var selectedIncrementIndex = 1 // 0=1m, 1=5m, 2=15m
    private let incrementOptions: [TimeInterval] = [60, 300, 900]

    var currentIncrement: TimeInterval {
        incrementOptions[selectedIncrementIndex]
    }

    // Adaptive background based on active task + color scheme
    private var backgroundColor: Color {
        if timerVM.isRunning || timerVM.isOvertime,
           let task = timerVM.currentTask {
            return TaskColor.adaptiveBackground(for: task.colorName, isDark: colorScheme == .dark)
        }
        return Color(.systemGroupedBackground)
    }

    var body: some View {
        Group {
            if showingPresets {
                PresetsView(
                    presetVM: presetVM,
                    taskListVM: taskListVM,
                    onReturn: { showingPresets = false }
                )
            } else {
                mainContent
            }
        }
        .preferredColorScheme(settings.colorScheme)
    }

    // MARK: - Main Timer Content

    private var mainContent: some View {
        ZStack {
            // Full-screen background color
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: timerVM.currentColor)

            VStack(spacing: 0) {
                // Top toolbar
                toolbar

                if taskListVM.taskList.tasks.isEmpty {
                    // Empty state
                    emptyState
                } else {
                    // Total / Finish At above timer
                    timeInfoHeader
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)

                    // Timer section with +/- spread wide
                    timerSection
                        .padding(.vertical, 8)

                    // Current task title
                    if let task = timerVM.currentTask {
                        Text(task.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
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
        }
        .onAppear {
            timerVM.configure(taskList: taskListVM, settings: settings)
            if !taskListVM.taskList.tasks.isEmpty {
                timerVM.loadCurrentTask()
            }
        }
        .onChange(of: taskListVM.taskList.tasks) { _, _ in
            timerVM.syncToFirstPending()
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidChange)) { _ in }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(insertIndex: nil, lastColor: taskListVM.lastTaskColor) { tasks in
                for task in tasks {
                    taskListVM.addTask(task)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 48))
                .foregroundColor(.primary.opacity(0.3))
            Text("Use + to add a new task")
                .font(.body)
                .foregroundColor(.primary.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Toolbar (all icons primary, no undo dot)

    private var toolbar: some View {
        HStack {
            // Undo/Redo
            HStack(spacing: 4) {
                Button {
                    taskListVM.undo()
                    timerVM.syncAfterUndo(taskListVM: taskListVM)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canUndo ? .primary : .primary.opacity(0.25))
                }
                .disabled(!taskListVM.undoManager.canUndo)

                Button {
                    taskListVM.redo()
                    timerVM.syncToFirstPending()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canRedo ? .primary : .primary.opacity(0.25))
                }
                .disabled(!taskListVM.undoManager.canRedo)
            }

            Spacer()

            if settings.autoLoop {
                Image(systemName: "repeat")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }

                Button {
                    showingPresets = true
                } label: {
                    Image(systemName: "tray.full")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Time Info Header

    private var timeInfoHeader: some View {
        HStack {
            if settings.showTotalListTime {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.7))
                    Text(taskListVM.formattedTotalTime(timerRemaining: timerVM.remainingTime, activeIndex: timerVM.currentTaskIndex, isTimerActive: timerVM.isRunning || timerVM.isOvertime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
            }

            Spacer()

            if settings.showEstimatedFinish {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Finish at")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.7))
                    Text(taskListVM.estimatedFinishTime(timerRemaining: timerVM.remainingTime, activeIndex: timerVM.currentTaskIndex, isTimerActive: timerVM.isRunning || timerVM.isOvertime))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Timer Section (+/- buttons spread wider)

    private var timerSection: some View {
        ZStack {
            if settings.showPieTimer {
                PieTimerView(
                    remainingTime: timerVM.remainingTime,
                    totalDuration: timerVM.totalDuration,
                    isOvertime: timerVM.isOvertime,
                    overtimeElapsed: timerVM.overtimeElapsed,
                    colorName: timerVM.currentColor
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

            // +/- buttons spread to screen edges
            if timerVM.isRunning || timerVM.remainingTime > 0 || timerVM.isOvertime {
                HStack {
                    Button {
                        timerVM.adjustTime(by: -currentIncrement)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.primary.opacity(0.5))
                    }

                    Spacer()

                    Button {
                        timerVM.adjustTime(by: currentIncrement)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.primary.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .offset(y: (settings.showPieTimer ? 180 : 220) * 0.38)
            }
        }
        .frame(height: settings.showPieTimer ? 210 : 250)
    }
}

#Preview {
    ContentView()
}
