import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    var taskListVM: TaskListViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // App Mode
                Section("Mode") {
                    Picker("App Mode", selection: $settings.appMode) {
                        ForEach(AppSettings.AppModeSetting.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.appMode) { _, _ in settings.save() }
                }

                // Timer
                Section("Timer") {
                    Toggle("Auto Start Next Task", isOn: $settings.autoStartNextTask)
                        .onChange(of: settings.autoStartNextTask) { _, _ in settings.save() }

                    if settings.appMode == .list {
                        Toggle("Auto-Loop", isOn: $settings.autoLoop)
                            .onChange(of: settings.autoLoop) { _, _ in settings.save() }
                    }
                }

                // Display
                Section("Display") {
                    if settings.appMode == .list {
                        Toggle("Pie Timer", isOn: $settings.showPieTimer)
                            .onChange(of: settings.showPieTimer) { _, _ in settings.save() }

                        Toggle("Per-Task Start/End Times", isOn: $settings.showPerTaskTimes)
                            .onChange(of: settings.showPerTaskTimes) { _, _ in settings.save() }

                        Toggle("Total List Time", isOn: $settings.showTotalListTime)
                            .onChange(of: settings.showTotalListTime) { _, _ in settings.save() }

                        Toggle("Estimated Finish Time", isOn: $settings.showEstimatedFinish)
                            .onChange(of: settings.showEstimatedFinish) { _, _ in settings.save() }
                    }

                    if settings.appMode == .calendar {
                        Picker("Timeline Zoom", selection: $settings.calendarZoom) {
                            ForEach(AppSettings.CalendarZoomSetting.allCases, id: \.self) { zoom in
                                Text(zoom.rawValue).tag(zoom)
                            }
                        }
                        .onChange(of: settings.calendarZoom) { _, _ in settings.save() }
                    }

                    if let vm = taskListVM, !vm.taskList.tasks.isEmpty {
                        Button("Reset Task Colors") {
                            vm.resetTaskColors()
                            dismiss()
                        }
                    }
                }

                // Appearance
                Section("Appearance") {
                    Picker("Dark Mode", selection: $settings.darkMode) {
                        ForEach(AppSettings.DarkModeSetting.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: settings.darkMode) { _, _ in settings.save() }

                    Toggle("Keep Screen On", isOn: $settings.keepScreenOn)
                        .onChange(of: settings.keepScreenOn) { _, _ in settings.save() }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.primary.opacity(0.6))
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings(), taskListVM: nil)
}
