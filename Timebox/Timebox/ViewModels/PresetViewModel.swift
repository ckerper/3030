import Foundation

class PresetViewModel: ObservableObject {
    @Published var presets: [Preset] = []
    @Published private(set) var undoStack: [[Preset]] = []
    @Published private(set) var redoStack: [[Preset]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private let storageKey = "presets"

    init() {
        self.presets = load()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
        }
    }

    private func load() -> [Preset] {
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
           let presets = try? JSONDecoder().decode([Preset].self, from: data) {
            return presets
        }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let presets = try? JSONDecoder().decode([Preset].self, from: data) {
            return presets
        }
        return []
    }

    // MARK: - Undo/Redo

    private func pushUndo() {
        undoStack.append(presets)
        redoStack.removeAll()
    }

    func performUndo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(presets)
        presets = previous
        save()
    }

    func performRedo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(presets)
        presets = next
        save()
    }

    // MARK: - CRUD

    func addPreset(_ preset: Preset) {
        presets.append(preset)
        save()
    }

    func saveCurrentList(name: String, tasks: [TaskItem]) {
        let preset = Preset(name: name, tasks: tasks)
        presets.append(preset)
        save()
    }

    func updatePreset(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            presets[index].updatedAt = Date()
            save()
        }
    }

    func deletePreset(id: UUID) {
        pushUndo()
        presets.removeAll { $0.id == id }
        save()
    }

    func deletePresets(at offsets: IndexSet) {
        pushUndo()
        presets.remove(atOffsets: offsets)
        save()
    }

    func movePresets(from source: IndexSet, to destination: Int) {
        pushUndo()
        presets.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
