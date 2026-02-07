import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @State private var selectedTab: Int = 0
    @State private var emojiText: String = ""

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector: Icons vs Emoji
            Picker("Icon Source", selection: $selectedTab) {
                Text("Icons").tag(0)
                Text("Emoji").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                sfSymbolPicker
            } else {
                emojiInput
            }
        }
    }

    // MARK: - SF Symbol Picker

    private var sfSymbolPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(IconLibrary.packs) { pack in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pack.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(pack.icons, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 22))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIcon == iconName
                                                    ? Color.accentColor.opacity(0.2)
                                                    : Color(.tertiarySystemFill))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedIcon == iconName ? Color.accentColor : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .foregroundColor(selectedIcon == iconName ? .accentColor : .primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Emoji Input

    private var emojiInput: some View {
        VStack(spacing: 16) {
            Text("Type or paste an emoji")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Enter emoji", text: $emojiText)
                .font(.system(size: 48))
                .multilineTextAlignment(.center)
                .frame(height: 80)
                .onChange(of: emojiText) { _, newValue in
                    // Take only the first emoji/character
                    if let first = newValue.first {
                        selectedIcon = String(first)
                        emojiText = String(first)
                    }
                }

            if !selectedIcon.isEmpty && selectedIcon.unicodeScalars.first?.properties.isEmoji == true {
                Text("Selected: \(selectedIcon)")
                    .font(.title)
            }

            // Quick emoji suggestions
            let quickEmojis = ["📧", "💻", "📝", "🏃", "🍳", "📚", "🧹", "🎯", "💪", "🧘", "☕", "📞"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(quickEmojis, id: \.self) { emoji in
                    Button {
                        selectedIcon = emoji
                        emojiText = emoji
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedIcon == emoji
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(.tertiarySystemFill))
                            )
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }
}

#Preview {
    IconPickerView(selectedIcon: .constant("laptopcomputer"))
}
