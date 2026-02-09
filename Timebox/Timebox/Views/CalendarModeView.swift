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

    // Static background — active task color is shown only in the compact timer bar
    private var backgroundColor: Color {
        Color(.systemGroupedBackground)
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

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
            TaskEditView(task: task, onSave: { updated in
                dayPlanVM.updateTask(updated)
                // Sync timer if this is the currently active task
                if timerVM.activeTaskId == updated.id {
                    let durationDelta = updated.duration - task.duration
                    if durationDelta != 0 {
                        timerVM.adjustTime(by: durationDelta)
                        dayPlanVM.recomputeTimeline()
                    }
                }
            }, onDelete: {
                dayPlanVM.removeTask(id: task.id)
            })
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

    /// Adjust time in calendar mode: updates both the timer AND the stored task/event duration
    private func adjustCalendarTime(by amount: TimeInterval) {
        if timerVM.isTimingEvent, let eventId = timerVM.activeEventId {
            // Adjust event duration
            if var event = dayPlanVM.event(for: eventId) {
                event.plannedDuration = max(60, event.plannedDuration + amount)
                dayPlanVM.updateEvent(event)
            }
            timerVM.adjustTime(by: amount)
        } else if let taskId = timerVM.activeTaskId {
            // Adjust task duration (updates stored duration + recomputes timeline)
            dayPlanVM.adjustDuration(taskId: taskId, by: amount)
            timerVM.adjustTime(by: amount)
        }
    }

    // MARK: - Compact Timer Bar

    private var compactTimerBar: some View {
        let activeColor = TaskColor.color(for: timerVM.currentColor)
        let isActive = timerVM.isRunning || timerVM.isOvertime

        return HStack(spacing: 8) {
            // Color dot
            Circle()
                .fill(activeColor)
                .frame(width: 10, height: 10)

            // Title
            Text(timerVM.currentTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(isActive ? activeColor : .primary)

            Spacer()

            // Minus button
            Button {
                adjustCalendarTime(by: -currentIncrement)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary.opacity(0.5))
            }

            // Time display
            Text(timerVM.displayTime)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(timerVM.isOvertime ? .red : isActive ? activeColor : .primary)

            // Plus button
            Button {
                adjustCalendarTime(by: currentIncrement)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary.opacity(0.5))
            }

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
                    .font(.system(size: 28))
                    .foregroundColor(activeColor)
            }

            // Complete button
            if timerVM.isTimingEvent {
                Button {
                    timerVM.completeCurrentEvent()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            } else if timerVM.activeTaskId != nil {
                Button {
                    timerVM.completeCurrentTaskCalendar()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(activeColor.opacity(isActive ? 0.25 : 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(activeColor.opacity(isActive ? 0.5 : 0), lineWidth: 1)
                )
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
