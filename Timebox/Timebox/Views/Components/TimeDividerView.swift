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
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

#Preview {
    TimeDividerView(onRemove: {})
        .padding()
}
