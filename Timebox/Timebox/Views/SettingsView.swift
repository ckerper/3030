import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Timer
                Section("Timer") {
                    Toggle("Auto Start Next Task", isOn: $settings.autoStartNextTask)
                        .onChange(of: settings.autoStartNextTask) { _, _ in settings.save() }

                    Toggle("Auto-Loop", isOn: $settings.autoLoop)
                        .onChange(of: settings.autoLoop) { _, _ in settings.save() }
                }

                // Display
                Section("Display") {
                    Toggle("Pie Timer", isOn: $settings.showPieTimer)
                        .onChange(of: settings.showPieTimer) { _, _ in settings.save() }

                    Toggle("Per-Task Start/End Times", isOn: $settings.showPerTaskTimes)
                        .onChange(of: settings.showPerTaskTimes) { _, _ in settings.save() }

                    Toggle("Total List Time", isOn: $settings.showTotalListTime)
                        .onChange(of: settings.showTotalListTime) { _, _ in settings.save() }

                    Toggle("Estimated Finish Time", isOn: $settings.showEstimatedFinish)
                        .onChange(of: settings.showEstimatedFinish) { _, _ in settings.save() }
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
    SettingsView(settings: AppSettings())
}
