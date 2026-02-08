import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let index: Int
    let isActive: Bool
    let isCompleted: Bool
    let showTimes: Bool
    let projectedStart: Date?
    let projectedEnd: Date?
    let displayDuration: TimeInterval
    let plannedIncrement: TimeInterval

    let onAdjustDuration: (TimeInterval) -> Void
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onMenu: () -> Void

    // Static width for duration text — fits "24:00:00" in monospaced caption
    private let durationWidth: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Color indicator bar — spans full height
            RoundedRectangle(cornerRadius: 3)
                .fill(task.color)
                .frame(width: 6)

            // Two-row content area
            VStack(alignment: .leading, spacing: 4) {
                // Row 1: Icon (if any) + Title spanning full width
                HStack(spacing: 6) {
                    if !task.icon.isEmpty {
                        taskIconView
                            .frame(width: 24)
                    }

                    Text(task.title)
                        .font(.body)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundColor(isCompleted ? .primary.opacity(0.5) : .primary)
                        .strikethrough(isCompleted)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onEdit()
                }

                // Row 2: timestamp ... - [duration] + checkmark menu
                HStack(spacing: 0) {
                    if showTimes, let start = projectedStart, let end = projectedEnd {
                        Text(TimeFormatting.formatCompactTimeRange(start: start, end: end))
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 4)

                    if !isCompleted {
                        Button {
                            onAdjustDuration(-plannedIncrement)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        // Fixed-width duration — keeps -/+ buttons aligned across rows
                        Text(TimeFormatting.format(displayDuration))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(width: durationWidth, alignment: .center)

                        Button {
                            onAdjustDuration(plannedIncrement)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onComplete) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.green.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }

                    Button(action: onMenu) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.5))
                            .frame(width: 36, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive
                    ? task.color.opacity(0.15)
                    : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isActive ? task.color.opacity(0.4) : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var taskIconView: some View {
        if task.icon.unicodeScalars.first?.properties.isEmoji == true
            && task.icon.unicodeScalars.count <= 2 {
            Text(task.icon)
                .font(.system(size: 20))
        } else {
            Image(systemName: task.icon)
                .font(.system(size: 16))
                .foregroundColor(task.color)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        TaskRowView(
            task: TaskItem(title: "Clear inbox", duration: 1800, colorName: "blue", icon: "envelope"),
            index: 0,
            isActive: true,
            isCompleted: false,
            showTimes: true,
            projectedStart: Date(),
            projectedEnd: Date().addingTimeInterval(1800),
            displayDuration: 1500,
            plannedIncrement: 300,
            onAdjustDuration: { _ in },
            onEdit: {},
            onComplete: {},
            onMenu: {}
        )
        TaskRowView(
            task: TaskItem(title: "Write report", duration: 3600, colorName: "green", icon: "doc.text"),
            index: 1,
            isActive: false,
            isCompleted: false,
            showTimes: true,
            projectedStart: Date(),
            projectedEnd: Date().addingTimeInterval(3600),
            displayDuration: 3600,
            plannedIncrement: 300,
            onAdjustDuration: { _ in },
            onEdit: {},
            onComplete: {},
            onMenu: {}
        )
    }
    .padding()
}
