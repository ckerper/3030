import SwiftUI

/// Pie timer that represents time in absolute scale:
/// A 10-minute slice always appears the same physical size regardless of total task duration.
/// High contrast: spent = near-white (95%), remaining = near-black (90%).
struct PieTimerView: View {
    let remainingTime: TimeInterval
    let totalDuration: TimeInterval
    let isOvertime: Bool
    let overtimeElapsed: TimeInterval
    let color: Color

    // Scale: how many seconds per full circle
    private let fullCircleSeconds: TimeInterval = 3600

    // Remaining time as a sweep angle (absolute scale)
    private var remainingSweep: Double {
        guard !isOvertime else { return 0 }
        let fraction = min(remainingTime / fullCircleSeconds, 1.0)
        return fraction * 360
    }

    // Spent time as a sweep angle (absolute scale)
    private var spentSweep: Double {
        guard !isOvertime, totalDuration > 0 else { return 0 }
        let spentSeconds = totalDuration - remainingTime
        let fraction = min(max(spentSeconds, 0) / fullCircleSeconds, 1.0)
        return fraction * 360
    }

    // High-contrast colors
    private let spentFillColor = Color.white.opacity(0.95)
    private let remainingFillColor = Color.black.opacity(0.90)

    var body: some View {
        ZStack {
            // Base circle — subtle gray so the pie is always visible
            Circle()
                .fill(Color(.systemGray4))

            // Spent time slice (near-white) — drawn first, from 12 o'clock
            if !isOvertime && spentSweep > 0 {
                PieSlice(
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + spentSweep)
                )
                .fill(spentFillColor)
            }

            // Remaining time slice (near-black) — drawn after spent
            if !isOvertime && remainingSweep > 0 {
                PieSlice(
                    startAngle: .degrees(-90 + spentSweep),
                    endAngle: .degrees(-90 + spentSweep + remainingSweep)
                )
                .fill(remainingFillColor)
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

            // Center text
            VStack(spacing: 2) {
                if isOvertime {
                    Text("OVERTIME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text(TimeFormatting.formatOvertime(overtimeElapsed))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Text(TimeFormatting.format(remainingTime))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }

                // Planned duration label
                if totalDuration > 0 {
                    Text("planned: \(TimeFormatting.format(totalDuration))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                }
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
        overtimeElapsed: 0,
        color: .blue
    )
    .frame(width: 200, height: 200)
}
