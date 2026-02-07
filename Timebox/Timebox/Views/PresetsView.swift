import SwiftUI

struct PresetsView: View {
    @ObservedObject var presetVM: PresetViewModel
    @ObservedObject var taskListVM: TaskListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSavePreset = false
    @State private var presetName = ""
    @State private var selectedPreset: Preset?
    @State private var showLoadOptions = false
    @State private var showEditPreset = false
    @State private var editingPreset: Preset?

    var body: some View {
        NavigationView {
            List {
                // Save current list as preset
                Section {
                    Button {
                        showSavePreset = true
                    } label: {
                        Label("Save Current List as Preset", systemImage: "square.and.arrow.down")
                    }
                    .disabled(taskListVM.taskList.tasks.isEmpty)
                }

                // Existing presets
                if presetVM.presets.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Presets Yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Save your current task list as a preset to reuse it later.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    Section("Your Presets") {
                        ForEach(presetVM.presets) { preset in
                            presetRow(preset)
                        }
                        .onDelete { offsets in
                            presetVM.deletePresets(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Save Preset", isPresented: $showSavePreset) {
                TextField("Preset name", text: $presetName)
                Button("Save") {
                    guard !presetName.isEmpty else { return }
                    presetVM.saveCurrentList(
                        name: presetName,
                        tasks: taskListVM.taskList.tasks
                    )
                    presetName = ""
                }
                Button("Cancel", role: .cancel) {
                    presetName = ""
                }
            } message: {
                Text("Enter a name for this preset.")
            }
            .confirmationDialog(
                "Load Preset",
                isPresented: $showLoadOptions,
                presenting: selectedPreset
            ) { preset in
                Button("Replace Current List") {
                    taskListVM.loadPreset(preset, replace: true)
                    dismiss()
                }
                Button("Append to Current List") {
                    taskListVM.loadPreset(preset, replace: false)
                    dismiss()
                }
                Button("Append (Remove Duplicates)") {
                    taskListVM.loadPreset(preset, replace: false, removeDuplicates: true)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: { preset in
                Text("How would you like to load \"\(preset.name)\"?")
            }
            .sheet(item: $editingPreset) { preset in
                PresetEditView(preset: preset) { updated in
                    presetVM.updatePreset(updated)
                }
            }
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        Button {
            selectedPreset = preset
            showLoadOptions = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label("\(preset.tasks.count) tasks", systemImage: "list.bullet")
                    Label(preset.formattedTotalDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Color dots preview
                HStack(spacing: 4) {
                    ForEach(preset.tasks.prefix(8)) { task in
                        Circle()
                            .fill(task.color)
                            .frame(width: 8, height: 8)
                    }
                    if preset.tasks.count > 8 {
                        Text("+\(preset.tasks.count - 8)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                presetVM.deletePreset(id: preset.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                editingPreset = preset
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

// MARK: - Preset Edit View

struct PresetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var preset: Preset
    let onSave: (Preset) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Preset name", text: $preset.name)
                }

                Section("Tasks (\(preset.tasks.count))") {
                    ForEach(preset.tasks) { task in
                        HStack {
                            Circle()
                                .fill(task.color)
                                .frame(width: 10, height: 10)
                            Text(task.title)
                                .font(.body)
                            Spacer()
                            Text(task.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        preset.tasks.remove(atOffsets: offsets)
                    }
                    .onMove { source, dest in
                        preset.tasks.move(fromOffsets: source, toOffset: dest)
                    }
                }

                Section {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text(preset.formattedTotalDuration)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(preset)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

#Preview {
    PresetsView(
        presetVM: PresetViewModel(),
        taskListVM: TaskListViewModel()
    )
}
