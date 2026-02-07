import SwiftUI

/// Pie timer that represents time in absolute scale:
/// A 10-minute slice always appears the same physical size regardless of total task duration.
struct PieTimerView: View {
    let remainingTime: TimeInterval
    let totalDuration: TimeInterval
    let isOvertime: Bool
    let color: Color

    // Scale: how many seconds per full circle
    // Using 60 minutes as the full circle reference
    private let fullCircleSeconds: TimeInterval = 3600

    private var sweepAngle: Double {
        guard !isOvertime else { return 0 }
        let fraction = min(remainingTime / fullCircleSeconds, 1.0)
        return fraction * 360
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color(.systemGray5))

            // Pie segment for remaining time
            PieSlice(startAngle: .degrees(-90), endAngle: .degrees(-90 + sweepAngle))
                .fill(isOvertime ? Color.red.opacity(0.7) : color.opacity(0.8))

            // Center text
            VStack(spacing: 2) {
                if isOvertime {
                    Text("OVERTIME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                Text(isOvertime
                    ? TimeFormatting.formatOvertime(totalDuration - remainingTime)
                    : TimeFormatting.format(remainingTime))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
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
        color: .blue
    )
    .frame(width: 200, height: 200)
}
