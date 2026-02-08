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

    private let durationOptions: [Double] = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationView {
            Form {
                Section("Event Title") {
                    TextField("e.g. Team standup", text: $title)
                }

                Section("Start Time") {
                    DatePicker(
                        "Starts at",
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
                            Text(TimeFormatting.formatClockTime(startTime))
                                .font(.headline)
                            Text("to")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(TimeFormatting.formatClockTime(startTime.addingTimeInterval(durationMinutes * 60)))
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
                            startTime: startTime,
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
