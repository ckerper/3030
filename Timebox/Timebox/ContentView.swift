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
                    gestureHints: gestureHints
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
            // ViewModels will handle this in their load() methods
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
                    taskListVM.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundColor(taskListVM.undoManager.canUndo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!taskListVM.undoManager.canUndo)
                .overlay(alignment: .topTrailing) {
                    // Undo badge
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

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 12) {
            if settings.showPieTimer {
                PieTimerView(
                    remainingTime: timerVM.remainingTime,
                    totalDuration: timerVM.totalDuration,
                    isOvertime: timerVM.isOvertime,
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

            // Timer adjustment buttons
            if timerVM.isRunning || timerVM.remainingTime > 0 || timerVM.isOvertime {
                TimerAdjustmentButtons(timerVM: timerVM, settings: settings)
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
