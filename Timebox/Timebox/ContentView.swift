import SwiftUI

struct ContentView: View {
    @StateObject private var taskListVM = TaskListViewModel()
    @StateObject private var timerVM = TimerViewModel()
    @StateObject private var presetVM = PresetViewModel()
    @StateObject private var dayPlanVM = DayPlanViewModel()
    @StateObject private var settings = AppSettings.load()
    @StateObject private var gestureHints = GestureHintManager()
    @StateObject private var cloudKit = CloudKitService.shared

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

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
            switch settings.appMode {
            case .list:
                listModeContent
            case .calendar:
                calendarModeContent
            }
        }
        .preferredColorScheme(settings.colorScheme)
        .onAppear {
            dayPlanVM.sharedTaskListVM = taskListVM
        }
        .onChange(of: settings.appMode) { oldMode, newMode in
            dayPlanVM.sharedTaskListVM = taskListVM
            if newMode == .calendar {
                dayPlanVM.importTasks(from: taskListVM.taskList.tasks)
            } else if newMode == .list {
                taskListVM.taskList.tasks = dayPlanVM.exportTasks()
            }
        }
    }

    // MARK: - List Mode (original UI)

    private var listModeContent: some View {
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
    }

    // MARK: - Calendar Mode

    private var calendarModeContent: some View {
        CalendarModeView(
            dayPlanVM: dayPlanVM,
            timerVM: timerVM,
            settings: settings,
            gestureHints: gestureHints
        )
        .onAppear {
            dayPlanVM.sharedTaskListVM = taskListVM
            // Sync tasks from list mode into calendar mode
            if !taskListVM.taskList.tasks.isEmpty {
                dayPlanVM.importTasks(from: taskListVM.taskList.tasks)
            }
            timerVM.configureForCalendar(dayPlanVM: dayPlanVM, settings: settings)
            dayPlanVM.timerVM = timerVM
            if !dayPlanVM.dayPlan.tasks.isEmpty {
                // Restore persisted timer state (survives app termination)
                timerVM.restoreState()
                // If no persisted state was restored, sync to first pending task
                if timerVM.activeTaskId == nil {
                    timerVM.syncToFirstPendingCalendar()
                }
            }
        }
        .onChange(of: dayPlanVM.dayPlan.tasks) { _, _ in
            timerVM.syncToFirstPendingCalendar()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                timerVM.persistState()
            case .inactive:
                if oldPhase == .active {
                    timerVM.persistState()
                }
            case .active:
                // Re-sync timer on return to foreground (account for elapsed time while suspended)
                if timerVM.activeTaskId != nil {
                    timerVM.restoreState()
                }
                dayPlanVM.recomputeTimeline()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Main Timer Content (List mode)

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
                    // Timer section with overlaid Total/Finish info
                    timerSection

                    // Current task title
                    if let task = timerVM.currentTask {
                        Text(task.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
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
            taskListVM.timerVM = timerVM
            if !taskListVM.taskList.tasks.isEmpty {
                timerVM.restoreState()
                // If no persisted state was restored, just load the first task
                if timerVM.activeTaskId == nil {
                    timerVM.loadCurrentTask()
                }
            }
        }
        .onChange(of: taskListVM.taskList.tasks) { _, _ in
            timerVM.syncToFirstPending()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                timerVM.persistState()
            case .inactive:
                // Only persist when leaving active (going to background).
                // Do NOT persist when returning from background (.background → .inactive)
                // because that overwrites the saved timestamp with "now" and erases
                // the elapsed time the timer should have counted while suspended.
                if oldPhase == .active {
                    timerVM.persistState()
                }
            case .active:
                // Re-sync on return to foreground (timer may have been counting)
                if timerVM.activeTaskId != nil {
                    timerVM.restoreState()
                }
            @unknown default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidChange)) { _ in }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, taskListVM: taskListVM)
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
                    let restoredTimer = taskListVM.undo()
                    timerVM.syncAfterUndo(taskListVM: taskListVM, restoredTimerState: restoredTimer)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canUndo ? .primary : .primary.opacity(0.25))
                }
                .disabled(!taskListVM.undoManager.canUndo)

                Button {
                    let restoredTimer = taskListVM.redo()
                    timerVM.syncAfterUndo(taskListVM: taskListVM, restoredTimerState: restoredTimer)
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

    // MARK: - Timer Section (Total/Finish overlaid, +/- buttons spread wide)

    private let dialSize: CGFloat = 220

    private var timerSection: some View {
        ZStack {
            // Timer dial/pie — both 220pt
            if settings.showPieTimer {
                PieTimerView(
                    remainingTime: timerVM.remainingTime,
                    totalDuration: timerVM.totalDuration,
                    isOvertime: timerVM.isOvertime,
                    overtimeElapsed: timerVM.overtimeElapsed,
                    colorName: timerVM.currentColor
                )
                .frame(width: dialSize, height: dialSize)
                .onTapGesture {
                    timerVM.startOrPause()
                }
            } else {
                TimerDialView(
                    timerVM: timerVM,
                    settings: settings,
                    dialSize: dialSize
                )
            }

            // +/- buttons spread to screen edges, vertically centered on dial
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
                .padding(.horizontal, 16)
            }

            // Total / Finish At overlaid at top corners of timer area
            VStack {
                HStack(alignment: .top) {
                    if settings.showTotalListTime {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total")
                                .font(.caption2)
                                .foregroundColor(.primary.opacity(0.7))
                            Text(taskListVM.formattedTotalTime(timerRemaining: timerVM.remainingTime, activeTaskId: timerVM.activeTaskId, savedRemainingTimes: timerVM.savedRemainingTimes))
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
                            Text(taskListVM.estimatedFinishTime(timerRemaining: timerVM.remainingTime, activeTaskId: timerVM.activeTaskId, savedRemainingTimes: timerVM.savedRemainingTimes))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .frame(height: dialSize + 30)
    }
}

#Preview {
    ContentView()
}
