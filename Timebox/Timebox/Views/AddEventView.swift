import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss

    var onAdd: (Event) -> Void

    @State private var title: String = ""
    @State private var startTime: Date = {
        // Default to next 15-minute mark
        let now = Date()
        let cal = Calendar.current
        let minutes = cal.component(.minute, from: now)
        let roundUp = (15 - (minutes % 15)) % 15
        return cal.date(byAdding: .minute, value: roundUp == 0 ? 15 : roundUp, to: now) ?? now
    }()
    @State private var durationMinutes: Double = 30
    @State private var selectedColor: String = "slate"
    @State private var selectedDay: Int = 0 // -1 = yesterday, 0 = today, 1 = tomorrow

    private let durationOptions: [Double] = [15, 30, 45, 60, 90, 120]

    /// Combine the selected day offset with the time-of-day from startTime
    private var effectiveStartTime: Date {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let targetDay = cal.date(byAdding: .day, value: selectedDay, to: todayStart) else {
            return startTime
        }
        let hour = cal.component(.hour, from: startTime)
        let minute = cal.component(.minute, from: startTime)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay) ?? startTime
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Event Title") {
                    TextField("e.g. Team standup", text: $title)
                }

                Section("Start Time") {
                    Picker("Day", selection: $selectedDay) {
                        Text("Yesterday").tag(-1)
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Time",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Duration") {
                    // Quick select buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(durationOptions, id: \.self) { mins in
                                Button {
                                    durationMinutes = mins
                                } label: {
                                    Text(formatDuration(mins))
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(durationMinutes == mins ? Color.accentColor : Color(.systemGray5))
                                        )
                                        .foregroundColor(durationMinutes == mins ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Precise hour/minute pickers
                    HStack {
                        Text("Hours")
                        Picker("Hours", selection: Binding(
                            get: { Int(durationMinutes) / 60 },
                            set: { h in
                                let m = Int(durationMinutes) % 60
                                durationMinutes = max(5, Double(h * 60 + m))
                            }
                        )) {
                            ForEach(0..<13, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()

                        Text("Min")
                        Picker("Minutes", selection: Binding(
                            get: { (Int(durationMinutes) % 60 / 5) * 5 },
                            set: { m in
                                let h = Int(durationMinutes) / 60
                                durationMinutes = max(5, Double(h * 60 + m))
                            }
                        )) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                    }

                    Text("Duration: \(formatDuration(durationMinutes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(TaskColor.palette, id: \.name) { item in
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == item.name ? 3 : 0)
                                    )
                                    .overlay(
                                        selectedColor == item.name ?
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        : nil
                                    )
                                    .onTapGesture {
                                        selectedColor = item.name
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            if selectedDay != 0 {
                                Text(selectedDay == -1 ? "Yesterday" : "Tomorrow")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(TimeFormatting.formatClockTime(effectiveStartTime))
                                .font(.headline)
                            Text("to")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(TimeFormatting.formatClockTime(effectiveStartTime.addingTimeInterval(durationMinutes * 60)))
                                .font(.headline)
                        }
                        Spacer()
                    }
                } header: {
                    Text("Summary")
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let event = Event(
                            title: title.isEmpty ? "Event" : title,
                            startTime: effectiveStartTime,
                            plannedDuration: durationMinutes * 60,
                            colorName: selectedColor
                        )
                        onAdd(event)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        if minutes >= 60 {
            let h = Int(minutes) / 60
            let m = Int(minutes) % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(Int(minutes))m"
    }
}
