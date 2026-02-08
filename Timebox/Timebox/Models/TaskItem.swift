import Foundation
import SwiftUI

struct TaskItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var duration: TimeInterval // in seconds
    var colorName: String // key into TaskColor palette
    var icon: String // SF Symbol name or emoji
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String = "New Task",
        duration: TimeInterval = 1800, // 30 minutes default
        colorName: String = "blue",
        icon: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.duration = min(max(duration, 1), 86400) // clamp 1s to 24h
        self.colorName = colorName
        self.icon = icon
        self.isCompleted = isCompleted
    }

    var color: Color {
        TaskColor.color(for: colorName)
    }

    var formattedDuration: String {
        TimeFormatting.format(duration)
    }
}

// MARK: - Task Color Palette

struct TaskColor {
    static let palette: [(name: String, color: Color)] = [
        ("green", Color(red: 0.18, green: 0.80, blue: 0.44)),
        ("teal", Color(red: 0.09, green: 0.71, blue: 0.65)),
        ("blue", Color(red: 0.20, green: 0.60, blue: 0.86)),
        ("indigo", Color(red: 0.36, green: 0.42, blue: 0.75)),
        ("purple", Color(red: 0.61, green: 0.35, blue: 0.71)),
        ("pink", Color(red: 0.91, green: 0.38, blue: 0.57)),
        ("red", Color(red: 0.91, green: 0.30, blue: 0.24)),
        ("orange", Color(red: 0.95, green: 0.61, blue: 0.07)),
        ("yellow", Color(red: 0.95, green: 0.77, blue: 0.06)),
        ("brown", Color(red: 0.62, green: 0.47, blue: 0.36)),
        ("gray", Color(red: 0.58, green: 0.65, blue: 0.65)),
        ("slate", Color(red: 0.38, green: 0.49, blue: 0.55)),
    ]

    static func color(for name: String) -> Color {
        palette.first(where: { $0.name == name })?.color ?? Color.blue
    }

    static func softBackground(for name: String) -> Color {
        color(for: name).opacity(0.85)
    }

    static let paletteNames: [String] = palette.map(\.name)

    // RGB components for computing tints and shades
    private static let rgbValues: [String: (r: Double, g: Double, b: Double)] = [
        "red": (0.91, 0.30, 0.24),
        "orange": (0.95, 0.61, 0.07),
        "yellow": (0.95, 0.77, 0.06),
        "green": (0.18, 0.80, 0.44),
        "teal": (0.09, 0.71, 0.65),
        "blue": (0.20, 0.60, 0.86),
        "indigo": (0.36, 0.42, 0.75),
        "purple": (0.61, 0.35, 0.71),
        "pink": (0.91, 0.38, 0.57),
        "brown": (0.62, 0.47, 0.36),
        "gray": (0.58, 0.65, 0.65),
        "slate": (0.38, 0.49, 0.55),
    ]

    /// Very pale tint of the color (for spent/background portions of timers)
    static func lightTint(for name: String, isDark: Bool = false) -> Color {
        guard let rgb = rgbValues[name] else { return isDark ? Color(white: 0.3) : .white }
        if isDark {
            // Dark mode: dimmed tint so it's not a bright circle against dark background
            return Color(red: rgb.r * 0.45, green: rgb.g * 0.45, blue: rgb.b * 0.45)
        }
        // Lerp 85% toward white
        return Color(
            red: rgb.r + 0.85 * (1.0 - rgb.r),
            green: rgb.g + 0.85 * (1.0 - rgb.g),
            blue: rgb.b + 0.85 * (1.0 - rgb.b)
        )
    }

    /// Very deep shade of the color (for remaining portions of timers)
    static func darkShade(for name: String, isDark: Bool = false) -> Color {
        guard let rgb = rgbValues[name] else { return .black }
        if isDark {
            // Dark mode: even deeper to visibly contrast against the dark background
            return Color(red: rgb.r * 0.20, green: rgb.g * 0.20, blue: rgb.b * 0.20)
        }
        // Keep 40% of original color intensity (enough hue to not look pure black)
        return Color(red: rgb.r * 0.40, green: rgb.g * 0.40, blue: rgb.b * 0.40)
    }

    /// Adaptive full-screen background: light tint in light mode, dark shade in dark mode
    static func adaptiveBackground(for name: String, isDark: Bool) -> Color {
        guard let rgb = rgbValues[name] else {
            return isDark ? Color(white: 0.15) : Color(white: 0.95)
        }
        if isDark {
            return Color(red: rgb.r * 0.30, green: rgb.g * 0.30, blue: rgb.b * 0.30)
        } else {
            return Color(
                red: rgb.r + 0.65 * (1.0 - rgb.r),
                green: rgb.g + 0.65 * (1.0 - rgb.g),
                blue: rgb.b + 0.65 * (1.0 - rgb.b)
            )
        }
    }

    /// Pick the next color that differs from the given previous color.
    /// Cycles through the palette in order, skipping the previous color.
    static func nextColor(after previousColorName: String?) -> String {
        guard let prev = previousColorName,
              let prevIndex = paletteNames.firstIndex(of: prev)
        else {
            return "green"
        }
        let nextIndex = (prevIndex + 1) % paletteNames.count
        return paletteNames[nextIndex]
    }
}

// MARK: - Time Formatting

struct TimeFormatting {
    static func format(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(abs(seconds))
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    static func formatOvertime(_ seconds: TimeInterval) -> String {
        return "+" + format(seconds)
    }

    static func formatClockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }

    /// Compact range: "2:05 – 2:15pm" (skip am/pm on start if same period)
    static func formatCompactTimeRange(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let startIsPM = cal.component(.hour, from: start) >= 12
        let endIsPM = cal.component(.hour, from: end) >= 12
        let samePeriod = startIsPM == endIsPM

        let startFmt = DateFormatter()
        startFmt.dateFormat = samePeriod ? "h:mm" : "h:mma"
        startFmt.amSymbol = "am"
        startFmt.pmSymbol = "pm"

        let endFmt = DateFormatter()
        endFmt.dateFormat = "h:mma"
        endFmt.amSymbol = "am"
        endFmt.pmSymbol = "pm"

        return "\(startFmt.string(from: start)) – \(endFmt.string(from: end))"
    }
}

// MARK: - Curated Icon Library

struct IconLibrary {
    struct IconPack: Identifiable {
        let id = UUID()
        let name: String
        let icons: [String] // SF Symbol names
    }

    static let packs: [IconPack] = [
        IconPack(name: "Productivity", icons: [
            "laptopcomputer", "desktopcomputer", "keyboard", "envelope",
            "doc.text", "folder", "pencil", "highlighter",
            "calendar", "clock", "bell", "megaphone",
            "chart.bar", "list.bullet", "checkmark.circle", "target",
        ]),
        IconPack(name: "Fitness", icons: [
            "figure.run", "figure.walk", "figure.cooldown",
            "dumbbell", "sportscourt", "bicycle",
            "heart", "bolt.heart", "flame",
            "drop", "leaf", "sun.max",
        ]),
        IconPack(name: "Household", icons: [
            "house", "bed.double", "bathtub", "shower",
            "fork.knife", "cup.and.saucer", "cart",
            "washer", "refrigerator", "stove",
            "pawprint", "leaf", "trash",
        ]),
        IconPack(name: "Social", icons: [
            "person.2", "phone", "message", "video",
            "party.popper", "gift", "hand.wave",
            "face.smiling", "music.note", "gamecontroller",
            "book", "theatermasks", "paintbrush",
        ]),
        IconPack(name: "Travel", icons: [
            "car", "bus", "tram", "airplane",
            "map", "location", "globe",
            "suitcase", "backpack", "camera",
        ]),
    ]
}
