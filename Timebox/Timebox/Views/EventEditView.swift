import SwiftUI

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State var event: Event
    @State private var selectedDay: Int = 0 // 0 = today, 1 = tomorrow
    var onSave: (Event) -> Void
    var onDelete: (() -> Void)?

    /// Combine the selected day offset with the time-of-day from event.startTime
    private var effectiveStartTime: Date {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let targetDay = cal.date(byAdding: .day, value: selectedDay, to: todayStart) else {
            return event.startTime
        }
        let hour = cal.component(.hour, from: event.startTime)
        let minute = cal.component(.minute, from: event.startTime)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay) ?? event.startTime
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Title") {
                    TextField("Event title", text: $event.title)
                }

                Section("Start Time") {
                    Picker("Day", selection: $selectedDay) {
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Starts at",
                        selection: $event.startTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Duration") {
                    HStack {
                        Text("Hours")
                        Picker("Hours", selection: Binding(
                            get: { Int(event.plannedDuration) / 3600 },
                            set: { h in
                                let m = (Int(event.plannedDuration) % 3600) / 60
                                event.plannedDuration = max(60, TimeInterval(h * 3600 + m * 60))
                            }
                        )) {
                            ForEach(0..<13, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()

                        Text("Min")
                        Picker("Minutes", selection: Binding(
                            get: { (Int(event.plannedDuration) % 3600) / 60 },
                            set: { m in
                                let h = Int(event.plannedDuration) / 3600
                                event.plannedDuration = max(60, TimeInterval(h * 3600 + m * 60))
                            }
                        )) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                    }

                    Text("Duration: \(event.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Color") {
                    ColorPaletteView(selectedColor: $event.colorName)
                }

                if let onDelete = onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Event")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Initialize day picker based on the event's current date
                let cal = Calendar.current
                if cal.isDateInTomorrow(event.startTime) {
                    selectedDay = 1
                } else {
                    selectedDay = 0
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if event.title.isEmpty { event.title = "Event" }
                        event.startTime = effectiveStartTime
                        onSave(event)
                        dismiss()
                    }
                }
            }
        }
    }
}
