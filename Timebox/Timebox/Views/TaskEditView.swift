import SwiftUI

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var task: TaskItem
    let onSave: (TaskItem) -> Void

    @State private var titleText: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var seconds: Int = 0

    init(task: TaskItem, onSave: @escaping (TaskItem) -> Void) {
        self._task = State(initialValue: task)
        self.onSave = onSave

        let totalSeconds = Int(task.duration)
        self._hours = State(initialValue: totalSeconds / 3600)
        self._minutes = State(initialValue: (totalSeconds % 3600) / 60)
        self._seconds = State(initialValue: totalSeconds % 60)
        self._titleText = State(initialValue: task.title)
    }

    private var computedDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        NavigationView {
            Form {
                // Title
                Section("Title") {
                    TextField("Task name", text: $titleText)
                        .font(.body)
                }

                // Duration picker
                Section("Duration") {
                    HStack {
                        VStack {
                            Text("Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Hours", selection: $hours) {
                                ForEach(0..<10) { h in
                                    Text("\(h)").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 120)
                            .clipped()
                        }

                        VStack {
                            Text("Min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Minutes", selection: $minutes) {
                                ForEach(0..<60) { m in
                                    Text("\(m)").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 120)
                            .clipped()
                        }

                        VStack {
                            Text("Sec")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Seconds", selection: $seconds) {
                                ForEach(0..<60) { s in
                                    Text("\(s)").tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 120)
                            .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Text("Duration: \(TimeFormatting.format(computedDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Color
                Section("Color") {
                    ColorPaletteView(selectedColor: $task.colorName)
                }

                // Icon
                Section("Icon") {
                    IconPickerView(selectedIcon: $task.icon)
                        .frame(height: 300)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = task
                        updated.title = titleText.isEmpty ? "Untitled" : titleText
                        updated.duration = max(1, min(32400, computedDuration))
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    TaskEditView(
        task: TaskItem(title: "Clear inbox", duration: 1800, colorName: "blue", icon: "envelope")
    ) { _ in }
}
