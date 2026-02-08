import SwiftUI

struct TimeDividerView: View {
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.orange)
                .frame(height: 2)

            Text("DIVIDER")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                )

            Rectangle()
                .fill(Color.orange)
                .frame(height: 2)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                    .frame(width: 44, height: 44) // generous hit area
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        // Capture all taps on the divider body so they don't propagate
        // to parent gestures (only the X button should trigger removal)
        .contentShape(Rectangle())
    }
}

#Preview {
    TimeDividerView(onRemove: {})
        .padding()
}
