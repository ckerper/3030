import SwiftUI

struct TimerDialView: View {
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings

    let dialSize: CGFloat

    private var strokeColor: Color {
        if timerVM.isOvertime {
            return .red
        }
        return TaskColor.color(for: timerVM.currentColor)
    }

    private var trackColor: Color {
        Color(.systemGray4)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(trackColor.opacity(0.3), style: StrokeStyle(lineWidth: 12))
                .frame(width: dialSize, height: dialSize)

            // Progress arc
            Circle()
                .trim(from: 0, to: timerVM.isOvertime ? 1.0 : timerVM.progress)
                .stroke(
                    strokeColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: dialSize, height: dialSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: timerVM.progress)

            // Overtime pulsing ring
            if timerVM.isOvertime {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 20)
                    .frame(width: dialSize, height: dialSize)
                    .scaleEffect(timerVM.isOvertime ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: timerVM.isOvertime
                    )
            }

            // Center content
            VStack(spacing: 6) {
                // Task icon
                if let task = timerVM.currentTask {
                    taskIconView(task)
                }

                // Time display
                Text(timerVM.displayTime)
                    .font(.system(size: dialSize * 0.18, weight: .light, design: .monospaced))
                    .foregroundColor(timerVM.isOvertime ? .red : .primary)

                // Status label
                if timerVM.isOvertime {
                    Text("OVERTIME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .transition(.opacity)
                } else if !timerVM.isRunning && timerVM.remainingTime > 0 {
                    Text("PAUSED")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                } else if !timerVM.isRunning {
                    Text("TAP TO START")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            timerVM.startOrPause()
        }
    }

    @ViewBuilder
    private func taskIconView(_ task: TaskItem) -> some View {
        if task.icon.isEmpty {
            EmptyView()
        } else if task.icon.unicodeScalars.first?.properties.isEmoji == true
                    && task.icon.unicodeScalars.count <= 2 {
            // Emoji
            Text(task.icon)
                .font(.system(size: dialSize * 0.12))
        } else {
            // SF Symbol
            Image(systemName: task.icon)
                .font(.system(size: dialSize * 0.1))
                .foregroundColor(strokeColor)
        }
    }
}

// MARK: - Timer Adjustment Buttons

struct TimerAdjustmentButtons: View {
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 40) {
            Button {
                timerVM.adjustTime(by: -settings.timerAdjustIncrement)
            } label: {
                Label(
                    "Subtract \(formatIncrement(settings.timerAdjustIncrement))",
                    systemImage: "minus.circle.fill"
                )
                .font(.title2)
                .labelStyle(.iconOnly)
                .foregroundColor(.secondary)
            }

            Button {
                timerVM.adjustTime(by: settings.timerAdjustIncrement)
            } label: {
                Label(
                    "Add \(formatIncrement(settings.timerAdjustIncrement))",
                    systemImage: "plus.circle.fill"
                )
                .font(.title2)
                .labelStyle(.iconOnly)
                .foregroundColor(.secondary)
            }
        }
    }

    private func formatIncrement(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(Int(seconds))s"
    }
}

#Preview {
    TimerDialView(
        timerVM: {
            let vm = TimerViewModel()
            vm.remainingTime = 1500
            vm.totalDuration = 1800
            return vm
        }(),
        settings: AppSettings(),
        dialSize: 260
    )
}
