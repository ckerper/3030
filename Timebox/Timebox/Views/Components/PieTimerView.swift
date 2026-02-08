import SwiftUI

/// Pie timer: absolute scale (1 hour = full circle).
/// Shows only a single dark wedge for remaining time on a light-tint background.
/// The wedge recedes counterclockwise back to 12:00 as time counts down.
struct PieTimerView: View {
    let remainingTime: TimeInterval
    let totalDuration: TimeInterval
    let isOvertime: Bool
    let overtimeElapsed: TimeInterval
    let colorName: String

    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    // Scale: how many seconds per full circle
    private let fullCircleSeconds: TimeInterval = 3600

    // Remaining time as a sweep angle (absolute scale)
    private var remainingSweep: Double {
        guard !isOvertime else { return 0 }
        let fraction = min(remainingTime / fullCircleSeconds, 1.0)
        return fraction * 360
    }

    var body: some View {
        ZStack {
            // Background circle — light tint of the task color
            Circle()
                .fill(TaskColor.lightTint(for: colorName, isDark: isDark))

            // Remaining time wedge — dark shade, from 12 o'clock clockwise
            if !isOvertime && remainingSweep > 0 {
                PieSlice(
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + remainingSweep)
                )
                .fill(TaskColor.darkShade(for: colorName, isDark: isDark))
            }

            // Overtime: full red ring pulse
            if isOvertime {
                Circle()
                    .fill(Color.red.opacity(0.15))
                Circle()
                    .strokeBorder(Color.red.opacity(0.7), lineWidth: 8)
                    .scaleEffect(1.02)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isOvertime
                    )
            }

            // Center text in a colored bubble for legibility
            VStack(spacing: 2) {
                if isOvertime {
                    Text("OVERTIME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    // Overtime count stays primary for legibility
                    Text(TimeFormatting.formatOvertime(overtimeElapsed))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Text(TimeFormatting.format(remainingTime))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Planned duration label
                if totalDuration > 0 {
                    Text("planned: \(TimeFormatting.format(totalDuration))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(TaskColor.color(for: colorName).opacity(0.8))
            )
        }
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    PieTimerView(
        remainingTime: 600,
        totalDuration: 1800,
        isOvertime: false,
        overtimeElapsed: 0,
        colorName: "blue"
    )
    .frame(width: 200, height: 200)
}
