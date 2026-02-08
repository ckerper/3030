import Foundation
import SwiftUI

class AppSettings: ObservableObject, Codable {
    // Timer adjustment increment for active task (in seconds)
    @Published var timerAdjustIncrement: TimeInterval = 300 // 5 minutes

    // Planned task adjustment increment (in seconds)
    @Published var plannedTaskIncrement: TimeInterval = 300 // 5 minutes

    // Display toggles
    @Published var showPieTimer: Bool = false
    @Published var autoStartNextTask: Bool = false
    @Published var autoLoop: Bool = false
    @Published var showPerTaskTimes: Bool = true
    @Published var showTotalListTime: Bool = true
    @Published var showEstimatedFinish: Bool = true
    @Published var keepScreenOn: Bool = false

    // App Mode
    @Published var appMode: AppModeSetting = .list

    // Calendar mode settings
    @Published var calendarZoom: CalendarZoomSetting = .oneHour

    enum AppModeSetting: String, Codable, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    enum CalendarZoomSetting: String, Codable, CaseIterable {
        case thirtyMin = "30 min"
        case oneHour = "1 hour"
        case twoHours = "2 hours"

        /// Points per hour at this zoom level
        var pointsPerHour: CGFloat {
            switch self {
            case .thirtyMin: return 240
            case .oneHour: return 120
            case .twoHours: return 60
            }
        }
    }

    // Appearance
    @Published var darkMode: DarkModeSetting = .system

    enum DarkModeSetting: String, Codable, CaseIterable {
        case on = "On"
        case off = "Off"
        case system = "System"
    }

    // Codable conformance for @Published properties
    enum CodingKeys: String, CodingKey {
        case timerAdjustIncrement
        case plannedTaskIncrement
        case showPieTimer
        case autoStartNextTask
        case autoLoop
        case showPerTaskTimes
        case showTotalListTime
        case showEstimatedFinish
        case keepScreenOn
        case appMode
        case calendarZoom
        case darkMode
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timerAdjustIncrement = try container.decodeIfPresent(TimeInterval.self, forKey: .timerAdjustIncrement) ?? 300
        plannedTaskIncrement = try container.decodeIfPresent(TimeInterval.self, forKey: .plannedTaskIncrement) ?? 300
        showPieTimer = try container.decodeIfPresent(Bool.self, forKey: .showPieTimer) ?? false
        autoStartNextTask = try container.decodeIfPresent(Bool.self, forKey: .autoStartNextTask) ?? false
        autoLoop = try container.decodeIfPresent(Bool.self, forKey: .autoLoop) ?? false
        showPerTaskTimes = try container.decodeIfPresent(Bool.self, forKey: .showPerTaskTimes) ?? true
        showTotalListTime = try container.decodeIfPresent(Bool.self, forKey: .showTotalListTime) ?? true
        showEstimatedFinish = try container.decodeIfPresent(Bool.self, forKey: .showEstimatedFinish) ?? true
        keepScreenOn = try container.decodeIfPresent(Bool.self, forKey: .keepScreenOn) ?? false
        appMode = try container.decodeIfPresent(AppModeSetting.self, forKey: .appMode) ?? .list
        calendarZoom = try container.decodeIfPresent(CalendarZoomSetting.self, forKey: .calendarZoom) ?? .oneHour
        darkMode = try container.decodeIfPresent(DarkModeSetting.self, forKey: .darkMode) ?? .system
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timerAdjustIncrement, forKey: .timerAdjustIncrement)
        try container.encode(plannedTaskIncrement, forKey: .plannedTaskIncrement)
        try container.encode(showPieTimer, forKey: .showPieTimer)
        try container.encode(autoStartNextTask, forKey: .autoStartNextTask)
        try container.encode(autoLoop, forKey: .autoLoop)
        try container.encode(showPerTaskTimes, forKey: .showPerTaskTimes)
        try container.encode(showTotalListTime, forKey: .showTotalListTime)
        try container.encode(showEstimatedFinish, forKey: .showEstimatedFinish)
        try container.encode(keepScreenOn, forKey: .keepScreenOn)
        try container.encode(appMode, forKey: .appMode)
        try container.encode(calendarZoom, forKey: .calendarZoom)
        try container.encode(darkMode, forKey: .darkMode)
    }

    var colorScheme: ColorScheme? {
        switch darkMode {
        case .on: return .dark
        case .off: return .light
        case .system: return nil
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "appSettings")
            NSUbiquitousKeyValueStore.default.set(data, forKey: "appSettings")
        }
    }

    static func load() -> AppSettings {
        // Try iCloud first, then local
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: "appSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }
        if let data = UserDefaults.standard.data(forKey: "appSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }
        return AppSettings()
    }
}
