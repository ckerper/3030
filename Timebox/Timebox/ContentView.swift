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

                // Total / Finish At above timer
                timeInfoHeader
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                // Timer section with +/- in ring corners (#2)
                timerSection
                    .padding(.vertical, 8)

                // Current task title
                if let task = timerVM.currentTask {
                    Text(task.title)
                        .font(.title3)
                        .fontWeight(.semibold)
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
        .preferredColorScheme(settings.colorScheme)
        .onAppear {
            timerVM.configure(taskList: taskListVM, settings: settings)
            if !taskListVM.taskList.tasks.isEmpty {
                timerVM.loadCurrentTask()
            }
        }
        .onChange(of: taskListVM.taskList.tasks) { _, _ in
            // Whenever the task list changes, sync timer to first pending (#1)
            timerVM.syncToFirstPending()
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidChange)) { _ in }
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
            }
        }
    }

    // MARK: - Toolbar

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
                    timerVM.syncToFirstPending()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canRedo ? .primary : .secondary.opacity(0.4))
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

    // MARK: - Time Info Header

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

    // MARK: - Timer Section (#2: +/- buttons overlaid on ring corners)

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

            // +/- buttons at bottom-left and bottom-right of the timer (#2)
            if timerVM.isRunning || timerVM.remainingTime > 0 || timerVM.isOvertime {
                let size: CGFloat = settings.showPieTimer ? 180 : 220
                HStack {
                    Button {
                        timerVM.adjustTime(by: -currentIncrement)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        timerVM.adjustTime(by: currentIncrement)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: size + 20)
                .offset(y: size * 0.38)
            }
        }
        .frame(height: settings.showPieTimer ? 210 : 250)
    }
}

#Preview {
    ContentView()
}
