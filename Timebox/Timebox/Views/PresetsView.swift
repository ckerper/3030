import SwiftUI

struct PresetsView: View {
    @ObservedObject var presetVM: PresetViewModel
    @ObservedObject var taskListVM: TaskListViewModel
    let onReturn: () -> Void

    @State private var showSavePreset = false
    @State private var presetName = ""
    @State private var selectedPreset: Preset?
    @State private var showLoadOptions = false
    @State private var editingPreset: Preset?
    @State private var showCreateNew = false
    @State private var showAddTaskToPreset = false
    @State private var newPresetName = ""
    @State private var newPresetTasks: [TaskItem] = []

    var body: some View {
        NavigationView {
            List {
                // Save current list as preset
                Section {
                    Button {
                        showSavePreset = true
                    } label: {
                        Label("Save Current List as Preset", systemImage: "square.and.arrow.down")
                            .foregroundColor(.primary)
                    }
                    .disabled(taskListVM.taskList.tasks.isEmpty)

                    Button {
                        newPresetName = ""
                        newPresetTasks = []
                        showCreateNew = true
                    } label: {
                        Label("Create New Preset", systemImage: "plus.circle")
                            .foregroundColor(.primary)
                    }
                }

                // Existing presets
                if presetVM.presets.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.primary.opacity(0.3))
                            Text("No Presets Yet")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.5))
                            Text("Save your current task list as a preset to reuse it later.")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.4))
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
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onReturn()
                    } label: {
                        Image(systemName: "timer")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
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
                Button("Load to Top") {
                    taskListVM.loadPresetToTop(preset)
                    onReturn()
                }
                Button("Load to Bottom") {
                    taskListVM.loadPresetToBottom(preset)
                    onReturn()
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
            .sheet(isPresented: $showCreateNew) {
                PresetBuilderView { newPreset in
                    presetVM.addPreset(newPreset)
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
                .foregroundColor(.primary.opacity(0.6))

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
                            .foregroundColor(.primary.opacity(0.5))
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

// MARK: - Preset Edit View (name + task management)

struct PresetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var preset: Preset
    let onSave: (Preset) -> Void

    @State private var showAddTask = false

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
                                .foregroundColor(.primary.opacity(0.6))
                        }
                    }
                    .onDelete { offsets in
                        preset.tasks.remove(atOffsets: offsets)
                    }
                    .onMove { source, dest in
                        preset.tasks.move(fromOffsets: source, toOffset: dest)
                    }

                    Button {
                        showAddTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }

                Section {
                    HStack {
                        Text("Total Duration")
                        Spacer()
                        Text(preset.formattedTotalDuration)
                            .foregroundColor(.primary.opacity(0.6))
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
            .sheet(isPresented: $showAddTask) {
                AddTaskView(
                    insertIndex: nil,
                    lastColor: preset.tasks.last?.colorName
                ) { tasks in
                    preset.tasks.append(contentsOf: tasks)
                }
            }
        }
    }
}

// MARK: - Preset Builder (create from scratch)

struct PresetBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tasks: [TaskItem] = []
    @State private var showAddTask = false

    let onSave: (Preset) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Preset name", text: $name)
                }

                Section("Tasks (\(tasks.count))") {
                    if tasks.isEmpty {
                        Text("No tasks yet — use Add Task to build your preset.")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.5))
                    } else {
                        ForEach(tasks) { task in
                            HStack {
                                Circle()
                                    .fill(task.color)
                                    .frame(width: 10, height: 10)
                                Text(task.title)
                                    .font(.body)
                                Spacer()
                                Text(task.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.primary.opacity(0.6))
                            }
                        }
                        .onDelete { offsets in
                            tasks.remove(atOffsets: offsets)
                        }
                        .onMove { source, dest in
                            tasks.move(fromOffsets: source, toOffset: dest)
                        }
                    }

                    Button {
                        showAddTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }

                if !tasks.isEmpty {
                    Section {
                        HStack {
                            Text("Total Duration")
                            Spacer()
                            let total = tasks.reduce(0) { $0 + $1.duration }
                            Text(TimeFormatting.format(total))
                                .foregroundColor(.primary.opacity(0.6))
                        }
                    }
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let preset = Preset(name: name.isEmpty ? "Untitled" : name, tasks: tasks)
                        onSave(preset)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(tasks.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(
                    insertIndex: nil,
                    lastColor: tasks.last?.colorName
                ) { newTasks in
                    tasks.append(contentsOf: newTasks)
                }
            }
        }
    }
}

#Preview {
    PresetsView(
        presetVM: PresetViewModel(),
        taskListVM: TaskListViewModel(),
        onReturn: {}
    )
}
