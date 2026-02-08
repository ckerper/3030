import SwiftUI

/// Container view for Calendar mode — shown when settings.appMode == .calendar
struct CalendarModeView: View {
    @ObservedObject var dayPlanVM: DayPlanViewModel
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var gestureHints: GestureHintManager

    @Environment(\.colorScheme) var colorScheme

    @State private var showAddTask = false
    @State private var showAddEvent = false
    @State private var showSettings = false
    @State private var editingEvent: Event?
    @State private var editingTask: TaskItem?

    // Shared increment selector state
    @State private var selectedIncrementIndex = 1
    private let incrementOptions: [TimeInterval] = [60, 300, 900]

    var currentIncrement: TimeInterval {
        incrementOptions[selectedIncrementIndex]
    }

    // Adaptive background
    private var backgroundColor: Color {
        if timerVM.isRunning,
           let _ = timerVM.isTimingEvent ? timerVM.currentEvent : nil {
            return TaskColor.adaptiveBackground(for: timerVM.currentColor, isDark: colorScheme == .dark)
        }
        if timerVM.isRunning || timerVM.isOvertime,
           let _ = timerVM.currentTask {
            return TaskColor.adaptiveBackground(for: timerVM.currentColor, isDark: colorScheme == .dark)
        }
        return Color(.systemGroupedBackground)
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: timerVM.currentColor)

            VStack(spacing: 0) {
                // Top toolbar
                calendarToolbar

                if dayPlanVM.dayPlan.tasks.isEmpty && dayPlanVM.dayPlan.events.isEmpty {
                    calendarEmptyState
                } else {
                    // Active item display (compact timer)
                    if timerVM.activeTaskId != nil || timerVM.activeEventId != nil {
                        compactTimerBar
                    }

                    // Calendar timeline
                    CalendarTimelineView(
                        dayPlanVM: dayPlanVM,
                        timerVM: timerVM,
                        settings: settings,
                        onEditEvent: { event in editingEvent = event },
                        onEditTask: { task in editingTask = task }
                    )

                    // Floating progress bar at bottom
                    FloatingProgressBar(
                        timerVM: timerVM,
                        dayPlanVM: dayPlanVM
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(insertIndex: nil, lastColor: dayPlanVM.lastTaskColor) { tasks in
                for task in tasks {
                    dayPlanVM.addTask(task)
                }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView { event in
                dayPlanVM.addEvent(event)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, taskListVM: nil)
        }
        .sheet(item: $editingEvent) { event in
            EventEditView(
                event: event,
                onSave: { updated in
                    dayPlanVM.updateEvent(updated)
                },
                onDelete: {
                    dayPlanVM.removeEvent(id: event.id)
                }
            )
        }
        .sheet(item: $editingTask) { task in
            TaskEditView(task: task) { updated in
                dayPlanVM.updateTask(updated)
            }
        }
    }

    // MARK: - Calendar Toolbar

    private var calendarToolbar: some View {
        HStack {
            // Undo/Redo
            HStack(spacing: 4) {
                Button {
                    let restoredTimer = dayPlanVM.undo()
                    if let timerState = restoredTimer {
                        timerVM.restoreTimerSnapshot(timerState)
                    } else {
                        timerVM.syncToFirstPendingCalendar()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                        .foregroundColor(dayPlanVM.undoManager.canUndo ? .primary : .primary.opacity(0.25))
                }
                .disabled(!dayPlanVM.undoManager.canUndo)

                Button {
                    let restoredTimer = dayPlanVM.redo()
                    if let timerState = restoredTimer {
                        timerVM.restoreTimerSnapshot(timerState)
                    } else {
                        timerVM.syncToFirstPendingCalendar()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18))
                        .foregroundColor(dayPlanVM.undoManager.canRedo ? .primary : .primary.opacity(0.25))
                }
                .disabled(!dayPlanVM.undoManager.canRedo)
            }

            Spacer()

            // Mode indicator
            Text("Calendar")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 16) {
                // Add task
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }

                // Add event
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }

                // Settings
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

    // MARK: - Compact Timer Bar

    private var compactTimerBar: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle()
                .fill(TaskColor.color(for: timerVM.currentColor))
                .frame(width: 12, height: 12)

            // Title
            Text(timerVM.currentTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            // Time display
            Text(timerVM.displayTime)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(timerVM.isOvertime ? .red : .primary)

            // Play/pause button
            Button {
                if timerVM.isTimingEvent {
                    timerVM.startOrPause()
                } else if dayPlanVM.pendingTasks.isEmpty {
                    // Nothing to time
                } else if timerVM.isRunning {
                    timerVM.pause()
                } else {
                    timerVM.startCalendarTask()
                }
            } label: {
                Image(systemName: timerVM.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(TaskColor.color(for: timerVM.currentColor))
            }

            // Complete button
            if timerVM.isTimingEvent {
                Button {
                    timerVM.completeCurrentEvent()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.green)
                }
            } else if timerVM.activeTaskId != nil {
                Button {
                    timerVM.completeCurrentTaskCalendar()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 26))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TaskColor.color(for: timerVM.currentColor).opacity(0.15))
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State

    private var calendarEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.primary.opacity(0.3))
            Text("Plan your day")
                .font(.title3)
                .foregroundColor(.primary.opacity(0.5))
            Text("Add tasks and fixed events to build your schedule")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.4))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    showAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Button {
                    showAddEvent = true
                } label: {
                    Label("Add Event", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
    }
}
