import SwiftUI

/// Scrollable vertical timeline showing the day's schedule with hour gutters.
struct CalendarTimelineView: View {
    @ObservedObject var dayPlanVM: DayPlanViewModel
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings

    @Environment(\.colorScheme) var colorScheme

    var onEditEvent: (Event) -> Void
    var onEditTask: (TaskItem) -> Void

    private var pointsPerHour: CGFloat {
        settings.calendarZoom.pointsPerHour
    }

    /// Total hours displayed: midnight yesterday through end of day tomorrow = 72 hours
    private let totalHours: Int = 72

    /// The start of the timeline: midnight yesterday
    private var dayStartDate: Date {
        let cal = Calendar.current
        let todayMidnight = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -1, to: todayMidnight) ?? todayMidnight
    }

    /// Total height of the timeline content in points
    private var totalHeight: CGFloat {
        CGFloat(totalHours) * pointsPerHour
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Invisible spacer to establish the full scrollable content height.
                    // Without this, .offset() views don't contribute to layout size
                    // and the ScrollView clips/bounces incorrectly.
                    Color.clear
                        .frame(height: totalHeight)

                    // Hour grid lines and labels
                    hourGrid

                    // Timeline slots
                    ForEach(dayPlanVM.timelineSlots) { slot in
                        slotView(for: slot)
                    }

                    // Current time indicator
                    currentTimeIndicator
                }
                .padding(.leading, 52)
                .padding(.trailing, 8)
            }
            .onAppear {
                // Scroll to current time, positioned 1/3 from the top of the visible area
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("currentTime", anchor: UnitPoint(x: 0.5, y: 0.33))
                }
            }
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        ForEach(0..<totalHours, id: \.self) { hourOffset in
            let hourOfDay = hourOffset % 24
            let y = CGFloat(hourOffset) * pointsPerHour

            ZStack(alignment: .topLeading) {
                // Midnight separator (stronger line + day label)
                if hourOfDay == 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(height: 1)
                        .offset(x: -52, y: y)

                    Text(dayLabel(for: hourOffset))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary.opacity(0.5))
                        .offset(x: 0, y: y + 2)
                } else {
                    // Regular hour line
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 0.5)
                        .offset(x: -52, y: y)
                }

                // Hour label
                Text(formatHour(hourOfDay))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
                    .offset(x: -52, y: y - 7)
            }
        }
    }

    // MARK: - Slot Views

    @ViewBuilder
    private func slotView(for slot: TimelineSlot) -> some View {
        let y = yPosition(for: slot.startTime)
        let height = max(pointsPerHour / 6, CGFloat(slot.duration / 3600) * pointsPerHour)

        switch slot {
        case .taskFragment(let taskId, _, _, let fragmentIndex, _):
            if let task = dayPlanVM.task(for: taskId) {
                taskSlotView(task: task, fragmentIndex: fragmentIndex, height: height)
                    .offset(y: y)
            }

        case .event(let eventId, _, _):
            if let event = dayPlanVM.event(for: eventId) {
                eventSlotView(event: event, height: height)
                    .offset(y: y)
            }

        case .freeTime(_, _):
            freeTimeSlotView(height: height)
                .offset(y: y)
        }
    }

    private func taskSlotView(task: TaskItem, fragmentIndex: Int, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(task.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if !task.icon.isEmpty {
                        if task.icon.count <= 2 && task.icon.unicodeScalars.allSatisfy({ $0.value > 127 }) {
                            Text(task.icon).font(.caption)
                        } else {
                            Image(systemName: task.icon).font(.caption2)
                        }
                    }
                    Text(fragmentIndex > 0 ? "\(task.title) (cont.)" : task.title)
                        .font(.caption)
                        .fontWeight(timerVM.activeTaskId == task.id ? .semibold : .regular)
                        .lineLimit(1)
                }

                if height > 30 {
                    Text(task.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Spacer()

            // Complete button
            if !task.isCompleted && timerVM.activeTaskId == task.id {
                Button {
                    timerVM.completeCurrentTaskCalendar()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.body)
                        .foregroundColor(task.color)
                }
                .padding(.trailing, 8)
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(task.color.opacity(task.isCompleted ? 0.15 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    timerVM.activeTaskId == task.id ? task.color : Color.clear,
                    lineWidth: timerVM.activeTaskId == task.id ? 2 : 0
                )
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .onTapGesture {
            onEditTask(task)
        }
    }

    private func eventSlotView(event: Event, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Color bar (dashed for events)
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(event.color)
                    Text(event.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                if height > 30 {
                    Text(event.formattedTimeRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Spacer()

            // Complete button for active event
            if !event.isCompleted && timerVM.activeEventId == event.id {
                Button {
                    timerVM.completeCurrentEvent()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(event.color)
                }
                .padding(.trailing, 8)
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(event.color.opacity(event.isCompleted ? 0.1 : 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(event.color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
        )
        .opacity(event.isCompleted ? 0.5 : 1.0)
        .onTapGesture {
            onEditEvent(event)
        }
    }

    private func freeTimeSlotView(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: height)
    }

    // MARK: - Current Time Indicator

    private var currentTimeIndicator: some View {
        let y = yPosition(for: Date())
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: -4)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .offset(y: y - 4)
        .id("currentTime")
    }

    // MARK: - Helpers

    private func yPosition(for date: Date) -> CGFloat {
        let interval = date.timeIntervalSince(dayStartDate)
        let hours = interval / 3600
        return CGFloat(hours) * pointsPerHour
    }

    private func formatHour(_ hourOfDay: Int) -> String {
        let h = hourOfDay % 12 == 0 ? 12 : hourOfDay % 12
        let period = hourOfDay < 12 ? "am" : "pm"
        return "\(h)\(period)"
    }

    /// Returns day label for midnight separators
    private func dayLabel(for hourOffset: Int) -> String {
        switch hourOffset {
        case 0: return "Yesterday"
        case 24: return "Today"
        case 48: return "Tomorrow"
        default: return ""
        }
    }
}
