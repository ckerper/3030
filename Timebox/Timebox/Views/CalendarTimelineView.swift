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
                    Color.clear
                        .frame(height: totalHeight)

                    // Scroll anchor at current time position.
                    // Uses VStack + Spacer so the anchor's LAYOUT frame is at
                    // the right y position (unlike .offset() which is visual-only
                    // and doesn't affect where scrollTo targets).
                    VStack(spacing: 0) {
                        Color.clear.frame(height: max(0, yPosition(for: Date())))
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id("currentTimeAnchor")
                        Spacer(minLength: 0)
                    }
                    .frame(height: totalHeight)

                    // Hour grid lines and labels
                    hourGrid

                    // Timeline slots
                    ForEach(dayPlanVM.timelineSlots) { slot in
                        slotView(for: slot)
                    }

                    // Current time indicator (visual only, red dot + line)
                    currentTimeIndicator
                }
                .padding(.leading, 52)
                .padding(.trailing, 8)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    proxy.scrollTo("currentTimeAnchor", anchor: UnitPoint(x: 0.5, y: 0.33))
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
        let height = max(2, CGFloat(slot.duration / 3600) * pointsPerHour)

        switch slot {
        case .taskFragment(let taskId, let startTime, let endTime, let fragmentIndex, let slotDuration):
            if let task = dayPlanVM.task(for: taskId) {
                let isFragment = fragmentIndex > 0 || abs(slotDuration - task.duration) > 1
                taskSlotView(
                    task: task,
                    isFragment: isFragment,
                    height: height,
                    slotStart: startTime,
                    slotEnd: endTime
                )
                .offset(y: y)
            }

        case .event(let eventId, let startTime, let endTime):
            if let event = dayPlanVM.event(for: eventId) {
                eventSlotView(event: event, height: height, slotStart: startTime, slotEnd: endTime)
                    .offset(y: y)
            }

        case .freeTime(_, _):
            EmptyView()
        }
    }

    private func taskSlotView(task: TaskItem, isFragment: Bool, height: CGFloat, slotStart: Date, slotEnd: Date) -> some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(task.color.opacity(task.isCompleted ? 0.15 : 0.25))
            // Active task border
            if timerVM.activeTaskId == task.id {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(task.color, lineWidth: 1.5)
            }
            // Color bar (full height)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(task.color)
                .frame(width: 3)
            // Content pinned to top via VStack + Spacer
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Color.clear.frame(width: 3) // spacer for color bar

                    if !task.icon.isEmpty {
                        if task.icon.count <= 2 && task.icon.unicodeScalars.allSatisfy({ $0.value > 127 }) {
                            Text(task.icon).font(.system(size: 10))
                        } else {
                            Image(systemName: task.icon).font(.system(size: 9))
                        }
                    }

                    Text("\(task.title) \(formatCompactDuration(task.duration))\(isFragment ? "*" : "") (\(TimeFormatting.formatTightTimeRange(start: slotStart, end: slotEnd)))")
                        .font(.system(size: 11))
                        .fontWeight(timerVM.activeTaskId == task.id ? .semibold : .regular)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if !task.isCompleted && timerVM.activeTaskId == task.id {
                        Button {
                            timerVM.completeCurrentTaskCalendar()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(task.color)
                        }
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .clipped()
        .onTapGesture {
            onEditTask(task)
        }
    }

    private func eventSlotView(event: Event, height: CGFloat, slotStart: Date, slotEnd: Date) -> some View {
        ZStack(alignment: .topLeading) {
            // Background + dashed border
            RoundedRectangle(cornerRadius: 4)
                .fill(event.color.opacity(event.isCompleted ? 0.1 : 0.2))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(event.color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            // Color bar (full height)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color)
                .frame(width: 3)
            // Content pinned to top via VStack + Spacer
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Color.clear.frame(width: 3) // spacer for color bar

                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundColor(event.color)

                    Text("\(event.title) \(formatCompactDuration(event.plannedDuration)) (\(TimeFormatting.formatTightTimeRange(start: slotStart, end: slotEnd)))")
                        .font(.system(size: 11))
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if !event.isCompleted && timerVM.activeEventId == event.id {
                        Button {
                            timerVM.completeCurrentEvent()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(event.color)
                        }
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .opacity(event.isCompleted ? 0.5 : 1.0)
        .clipped()
        .onTapGesture {
            onEditEvent(event)
        }
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
    }

    // MARK: - Helpers

    private func yPosition(for date: Date) -> CGFloat {
        let interval = date.timeIntervalSince(dayStartDate)
        let hours = interval / 3600
        return CGFloat(hours) * pointsPerHour
    }

    /// Compact duration: "1h 15m", "20m", "1m 30s" (only non-zero units)
    private func formatCompactDuration(_ seconds: TimeInterval) -> String {
        let total = Int(abs(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if s > 0 || parts.isEmpty { parts.append("\(s)s") }
        return parts.joined(separator: " ")
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
