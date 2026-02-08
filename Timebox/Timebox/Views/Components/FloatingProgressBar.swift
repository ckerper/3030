import SwiftUI

/// A floating progress bar shown at the bottom of the calendar view
/// showing total day progress and time remaining.
struct FloatingProgressBar: View {
    @ObservedObject var timerVM: TimerViewModel
    @ObservedObject var dayPlanVM: DayPlanViewModel

    @Environment(\.colorScheme) var colorScheme

    private var completedTaskCount: Int {
        dayPlanVM.dayPlan.tasks.filter { $0.isCompleted }.count
    }

    private var totalTaskCount: Int {
        dayPlanVM.dayPlan.tasks.count
    }

    private var completedEventCount: Int {
        dayPlanVM.dayPlan.events.filter { $0.isCompleted }.count
    }

    private var totalEventCount: Int {
        dayPlanVM.dayPlan.events.count
    }

    private var totalRemainingTime: TimeInterval {
        dayPlanVM.dayPlan.pendingTasks.reduce(0) { $0 + $1.duration }
    }

    private var progressFraction: Double {
        let total = dayPlanVM.dayPlan.tasks.count
        guard total > 0 else { return 0 }
        let done = dayPlanVM.dayPlan.tasks.filter { $0.isCompleted }.count
        return Double(done) / Double(total)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.easeInOut(duration: 0.3), value: progressFraction)
                }
            }
            .frame(height: 6)

            HStack {
                // Current activity indicator
                if timerVM.isRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(TaskColor.color(for: timerVM.currentColor))
                            .frame(width: 8, height: 8)
                        Text(timerVM.currentTitle)
                            .font(.caption2)
                            .lineLimit(1)
                        Text(timerVM.displayTime)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                } else {
                    Text("\(completedTaskCount)/\(totalTaskCount) tasks done")
                        .font(.caption2)
                }

                Spacer()

                // Time remaining
                Text("Remaining: \(TimeFormatting.format(totalRemainingTime))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
        )
    }
}
