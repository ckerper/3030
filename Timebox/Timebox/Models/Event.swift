import Foundation
import SwiftUI

struct Event: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var startTime: Date                 // pinned clock time
    var plannedDuration: TimeInterval   // expected length in seconds
    var colorName: String
    var isCompleted: Bool
    var actualEndTime: Date?            // when user tapped "done" (may differ from planned)

    init(
        id: UUID = UUID(),
        title: String = "New Event",
        startTime: Date = Date(),
        plannedDuration: TimeInterval = 1800, // 30 minutes default
        colorName: String = "slate",
        isCompleted: Bool = false,
        actualEndTime: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.plannedDuration = min(max(plannedDuration, 60), 86400) // clamp 1m to 24h
        self.colorName = colorName
        self.isCompleted = isCompleted
        self.actualEndTime = actualEndTime
    }

    var color: Color {
        TaskColor.color(for: colorName)
    }

    /// Planned end time
    var plannedEndTime: Date {
        startTime.addingTimeInterval(plannedDuration)
    }

    /// Effective end time: actual if completed, otherwise planned
    var effectiveEndTime: Date {
        actualEndTime ?? plannedEndTime
    }

    var formattedStartTime: String {
        TimeFormatting.formatClockTime(startTime)
    }

    var formattedDuration: String {
        TimeFormatting.format(plannedDuration)
    }

    var formattedTimeRange: String {
        TimeFormatting.formatCompactTimeRange(start: startTime, end: plannedEndTime)
    }
}
