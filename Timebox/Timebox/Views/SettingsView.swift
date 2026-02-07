import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    // For custom increment input
    @State private var customIncrementMinutes: String = ""

    var body: some View {
        NavigationView {
            Form {
                // Timer
                Section("Timer") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active task adjustment increment")
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            ForEach([60.0, 300.0, 600.0], id: \.self) { value in
                                incrementButton(value: value)
                            }
                            // Custom input
                            HStack(spacing: 4) {
                                TextField("Custom", text: $customIncrementMinutes)
                                    .keyboardType(.numberPad)
                                    .frame(width: 50)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                Text("min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .onChange(of: customIncrementMinutes) { _, newValue in
                                if let mins = Double(newValue), mins > 0 {
                                    settings.timerAdjustIncrement = mins * 60
                                    settings.save()
                                }
                            }
                        }
                    }

                    Toggle("Auto Start Next Task", isOn: $settings.autoStartNextTask)
                        .onChange(of: settings.autoStartNextTask) { _, _ in settings.save() }

                    Toggle("Auto-Loop", isOn: $settings.autoLoop)
                        .onChange(of: settings.autoLoop) { _, _ in settings.save() }
                }

                // Display
                Section("Display") {
                    Toggle("Pie Timer", isOn: $settings.showPieTimer)
                        .onChange(of: settings.showPieTimer) { _, _ in settings.save() }

                    Toggle("Task Duration", isOn: $settings.showTaskDuration)
                        .onChange(of: settings.showTaskDuration) { _, _ in settings.save() }

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
                            .foregroundColor(.secondary)
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
            .onAppear {
                let mins = Int(settings.timerAdjustIncrement / 60)
                if ![1, 5, 10].contains(mins) {
                    customIncrementMinutes = "\(mins)"
                }
            }
        }
    }

    private func incrementButton(value: TimeInterval) -> some View {
        let mins = Int(value / 60)
        let isSelected = settings.timerAdjustIncrement == value
        return Button {
            settings.timerAdjustIncrement = value
            customIncrementMinutes = ""
            settings.save()
        } label: {
            Text("±\(mins)m")
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}
