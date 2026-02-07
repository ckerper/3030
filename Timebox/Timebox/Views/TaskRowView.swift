import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let index: Int
    let isActive: Bool
    let showDuration: Bool
    let showTimes: Bool
    let projectedStart: Date?
    let projectedEnd: Date?
    let plannedIncrement: TimeInterval

    let onAdjustDuration: (TimeInterval) -> Void
    let onEdit: () -> Void
    let onMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 3)
                .fill(task.color)
                .frame(width: 6)
                .padding(.vertical, 4)

            // Icon
            if !task.icon.isEmpty {
                taskIconView
                    .frame(width: 28)
            }

            // Title and time info
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if showDuration {
                        Text(task.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if showTimes, let start = projectedStart, let end = projectedEnd {
                        Text("\(TimeFormatting.formatClockTime(start)) – \(TimeFormatting.formatClockTime(end))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Inline duration adjustment (for non-active tasks)
            if !isActive && !task.isCompleted {
                HStack(spacing: 4) {
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

                    Text(task.formattedDuration)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minWidth: 48)
                        .multilineTextAlignment(.center)

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
                }
            }

            // Chevron/menu button
            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
            showDuration: true,
            showTimes: false,
            projectedStart: nil,
            projectedEnd: nil,
            plannedIncrement: 300,
            onAdjustDuration: { _ in },
            onEdit: {},
            onMenu: {}
        )
        TaskRowView(
            task: TaskItem(title: "Write report", duration: 3600, colorName: "green", icon: "doc.text"),
            index: 1,
            isActive: false,
            showDuration: true,
            showTimes: true,
            projectedStart: Date(),
            projectedEnd: Date().addingTimeInterval(3600),
            plannedIncrement: 300,
            onAdjustDuration: { _ in },
            onEdit: {},
            onMenu: {}
        )
    }
    .padding()
}
