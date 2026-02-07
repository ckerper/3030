import SwiftUI

struct ColorPaletteView: View {
    @Binding var selectedColor: String
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(TaskColor.palette, id: \.name) { item in
                Circle()
                    .fill(item.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: selectedColor == item.name ? 3 : 0)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(selectedColor == item.name ? 1 : 0)
                    )
                    .shadow(color: item.color.opacity(0.4), radius: selectedColor == item.name ? 6 : 0)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColor = item.name
                        }
                    }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ColorPaletteView(selectedColor: .constant("blue"))
        .padding()
        .background(Color(.systemGroupedBackground))
}
