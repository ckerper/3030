import Foundation

struct Preset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var tasks: [TaskItem]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled Preset",
        tasks: [TaskItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tasks = tasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var totalDuration: TimeInterval {
        tasks.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        TimeFormatting.format(totalDuration)
    }
}
