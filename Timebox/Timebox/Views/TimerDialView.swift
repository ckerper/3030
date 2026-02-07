import SwiftUI

struct TimerDialView: View {
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var settings: AppSettings

    let dialSize: CGFloat

    // High-contrast colors (#5):
    // Spent time (elapsed) = near-white: white at 95% opacity over the background
    // Remaining time = near-black: black at 90% opacity
    private var spentColor: Color {
        if timerVM.isOvertime { return Color.red }
        return Color.white.opacity(0.95)
    }

    private var remainingColor: Color {
        Color.black.opacity(0.90)
    }

    // How much of the circle is "remaining" (1.0 = full, 0.0 = empty)
    private var remainingFraction: Double {
        guard timerVM.totalDuration > 0 else { return 1.0 }
        if timerVM.isOvertime { return 0 }
        return max(0, min(1, timerVM.remainingTime / timerVM.totalDuration))
    }

    var body: some View {
        ZStack {
            // Full circle = spent time (near-white)
            Circle()
                .stroke(spentColor, style: StrokeStyle(lineWidth: 16))
                .frame(width: dialSize, height: dialSize)
                .shadow(color: spentColor.opacity(0.3), radius: 4)

            // Remaining arc on top = near-black, shrinks counterclockwise (#4)
            // trim(from: 0, to: fraction) starts at 12 o'clock and goes clockwise.
            // We want remaining to start at 12 o'clock and shrink,
            // so we draw from 0 to remainingFraction.
            Circle()
                .trim(from: 0, to: remainingFraction)
                .stroke(
                    remainingColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: dialSize, height: dialSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: remainingFraction)

            // Overtime pulsing ring
            if timerVM.isOvertime {
                Circle()
                    .stroke(Color.red.opacity(0.4), lineWidth: 22)
                    .frame(width: dialSize, height: dialSize)
                    .scaleEffect(1.05)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: timerVM.isOvertime
                    )
            }

            // Center content
            VStack(spacing: 6) {
                if let task = timerVM.currentTask {
                    taskIconView(task)
                }

                Text(timerVM.displayTime)
                    .font(.system(size: dialSize * 0.18, weight: .light, design: .monospaced))
                    .foregroundColor(timerVM.isOvertime ? .red : .primary)

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

                // Planned duration label
                if timerVM.totalDuration > 0 {
                    Text("planned: \(TimeFormatting.format(timerVM.totalDuration))")
                        .font(.system(size: dialSize * 0.05))
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
            Text(task.icon)
                .font(.system(size: dialSize * 0.12))
        } else {
            Image(systemName: task.icon)
                .font(.system(size: dialSize * 0.1))
                .foregroundColor(.primary)
        }
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
