import SwiftUI

struct PresetsView: View {
    @ObservedObject var presetVM: PresetViewModel
    @ObservedObject var taskListVM: TaskListViewModel
    let onReturn: () -> Void

    @State private var showSavePreset = false
    @State private var presetName = ""
    @State private var editingPreset: Preset?
    @State private var showCreateNew = false

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
                        .onMove { source, destination in
                            presetVM.movePresets(from: source, to: destination)
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

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        Button {
                            presetVM.performUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16))
                                .foregroundColor(presetVM.canUndo ? .primary : .primary.opacity(0.25))
                        }
                        .disabled(!presetVM.canUndo)

                        Button {
                            presetVM.performRedo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 16))
                                .foregroundColor(presetVM.canRedo ? .primary : .primary.opacity(0.25))
                        }
                        .disabled(!presetVM.canRedo)
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
            .sheet(item: $editingPreset) { preset in
                PresetEditView(preset: preset, onSave: { updated in
                    presetVM.updatePreset(updated)
                }, onDelete: {
                    presetVM.deletePreset(id: preset.id)
                })
            }
            .sheet(isPresented: $showCreateNew) {
                PresetBuilderView { newPreset in
                    presetVM.addPreset(newPreset)
                }
            }
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        HStack {
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
            .contentShape(Rectangle())
            .onTapGesture {
                editingPreset = preset
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    taskListVM.loadPresetToTop(preset)
                    onReturn()
                } label: {
                    Text("Top")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button {
                    taskListVM.loadPresetToBottom(preset)
                    onReturn()
                } label: {
                    Text("Bottom")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preset Edit View (with inline editing and undo/redo)

struct PresetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var preset: Preset
    let onSave: (Preset) -> Void
    var onDelete: (() -> Void)?

    @State private var showAddTask = false
    @State private var editingTask: TaskItem?

    // Local undo/redo for task list within this editor
    @State private var undoStack: [[TaskItem]] = []
    @State private var redoStack: [[TaskItem]] = []

    private var canUndo: Bool { !undoStack.isEmpty }
    private var canRedo: Bool { !redoStack.isEmpty }

    private func pushUndo() {
        undoStack.append(preset.tasks)
        redoStack.removeAll()
    }

    private func performUndo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(preset.tasks)
        preset.tasks = previous
    }

    private func performRedo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(preset.tasks)
        preset.tasks = next
    }

    private func autoColorTasks() {
        pushUndo()
        for i in preset.tasks.indices {
            preset.tasks[i].colorName = TaskColor.paletteNames[i % TaskColor.paletteNames.count]
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Preset name", text: $preset.name)
                }

                Section("Tasks (\(preset.tasks.count))") {
                    ForEach(preset.tasks) { task in
                        Button {
                            editingTask = task
                        } label: {
                            HStack {
                                Circle()
                                    .fill(task.color)
                                    .frame(width: 10, height: 10)
                                Text(task.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(task.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.primary.opacity(0.6))
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.primary.opacity(0.3))
                            }
                        }
                    }
                    .onDelete { offsets in
                        pushUndo()
                        preset.tasks.remove(atOffsets: offsets)
                    }
                    .onMove { source, dest in
                        pushUndo()
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

                if !preset.tasks.isEmpty {
                    Section {
                        Button {
                            autoColorTasks()
                        } label: {
                            Label("Auto Color", systemImage: "paintpalette")
                        }
                    }
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            Label("Delete Preset", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        Button {
                            performUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16))
                                .foregroundColor(canUndo ? .primary : .primary.opacity(0.25))
                        }
                        .disabled(!canUndo)

                        Button {
                            performRedo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 16))
                                .foregroundColor(canRedo ? .primary : .primary.opacity(0.25))
                        }
                        .disabled(!canRedo)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(preset)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(
                    insertIndex: nil,
                    lastColor: preset.tasks.last?.colorName
                ) { tasks in
                    pushUndo()
                    preset.tasks.append(contentsOf: tasks)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(task: task) { updated in
                    pushUndo()
                    if let idx = preset.tasks.firstIndex(where: { $0.id == updated.id }) {
                        preset.tasks[idx] = updated
                    }
                }
            }
        }
    }
}

// MARK: - Preset Builder (create from scratch, with undo/redo)

struct PresetBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tasks: [TaskItem] = []
    @State private var showAddTask = false
    @State private var editingTask: TaskItem?

    // Local undo/redo
    @State private var undoStack: [[TaskItem]] = []
    @State private var redoStack: [[TaskItem]] = []

    private var canUndo: Bool { !undoStack.isEmpty }
    private var canRedo: Bool { !redoStack.isEmpty }

    private func pushUndo() {
        undoStack.append(tasks)
        redoStack.removeAll()
    }

    private func performUndo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(tasks)
        tasks = previous
    }

    private func performRedo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(tasks)
        tasks = next
    }

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
                            Button {
                                editingTask = task
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(task.color)
                                        .frame(width: 10, height: 10)
                                    Text(task.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(task.formattedDuration)
                                        .font(.caption)
                                        .foregroundColor(.primary.opacity(0.6))
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.primary.opacity(0.3))
                                }
                            }
                        }
                        .onDelete { offsets in
                            pushUndo()
                            tasks.remove(atOffsets: offsets)
                        }
                        .onMove { source, dest in
                            pushUndo()
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

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        Button {
                            performUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16))
                                .foregroundColor(canUndo ? .primary : .primary.opacity(0.25))
                        }
                        .disabled(!canUndo)

                        Button {
                            performRedo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 16))
                                .foregroundColor(canRedo ? .primary : .primary.opacity(0.25))
                        }
                        .disabled(!canRedo)
                    }
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
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(
                    insertIndex: nil,
                    lastColor: tasks.last?.colorName
                ) { newTasks in
                    pushUndo()
                    tasks.append(contentsOf: newTasks)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditView(task: task) { updated in
                    pushUndo()
                    if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
                        tasks[idx] = updated
                    }
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
