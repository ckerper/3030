import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var selectedColor: String
    @State private var showBulkConfirmation = false
    @State private var bulkLines: [SmartTextParser.ParseResult] = []
    @State private var showAmbiguousPrompt = false
    @State private var ambiguousResult: SmartTextParser.ParseResult?

    let insertIndex: Int?
    let onAdd: ([TaskItem]) -> Void

    init(insertIndex: Int?, lastColor: String? = nil, onAdd: @escaping ([TaskItem]) -> Void) {
        self.insertIndex = insertIndex
        self.onAdd = onAdd
        // Auto-assign next color in cycle
        _selectedColor = State(initialValue: TaskColor.nextColor(after: lastColor))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Task")
                    .font(.headline)

                Text("Type a task name. Add a number at the end to set the duration in minutes.")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("e.g. Clear inbox 30", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .lineLimit(1...6)

                if !inputText.isEmpty {
                    let preview = SmartTextParser.parseLine(inputText)
                    VStack(spacing: 4) {
                        Text("Title: \(preview.title.isEmpty ? inputText : preview.title)")
                            .font(.subheadline)
                        if let dur = preview.duration {
                            Text("Duration: \(TimeFormatting.format(dur))")
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.6))
                        } else {
                            Text("Duration: 30:00 (default)")
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                }

                // Compact horizontal color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.6))
                        .padding(.leading, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(TaskColor.palette, id: \.name) { item in
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: selectedColor == item.name ? 3 : 0)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .opacity(selectedColor == item.name ? 1 : 0)
                                    )
                                    .shadow(color: item.color.opacity(0.4), radius: selectedColor == item.name ? 4 : 0)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedColor = item.name
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        processInput()
                    }
                    .fontWeight(.semibold)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Multiple Tasks Detected", isPresented: $showBulkConfirmation) {
                Button("Create \(bulkLines.count) tasks") {
                    var currentColor = selectedColor
                    let tasks = bulkLines.map { result -> TaskItem in
                        let task = TaskItem(
                            title: result.title,
                            duration: result.duration ?? 1800,
                            colorName: currentColor
                        )
                        currentColor = TaskColor.nextColor(after: currentColor)
                        return task
                    }
                    onAdd(tasks)
                    dismiss()
                }
                Button("Create one task with long title") {
                    let task = TaskItem(
                        title: inputText.trimmingCharacters(in: .whitespacesAndNewlines),
                        colorName: selectedColor
                    )
                    onAdd([task])
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You pasted \(bulkLines.count) lines. Create one task per line, or one task with a long title?")
            }
            .alert("Duration or Title?", isPresented: $showAmbiguousPrompt) {
                if let result = ambiguousResult, let number = result.ambiguousNumber {
                    Button("Set \(number)-minute timer") {
                        let task = TaskItem(
                            title: result.title,
                            duration: result.duration ?? 1800,
                            colorName: selectedColor
                        )
                        onAdd([task])
                        dismiss()
                    }
                    Button("Keep '\(number)' in title") {
                        let task = TaskItem(
                            title: inputText.trimmingCharacters(in: .whitespaces),
                            colorName: selectedColor
                        )
                        onAdd([task])
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                if let result = ambiguousResult, let number = result.ambiguousNumber {
                    Text("Did you mean a \(number)-minute timer, or is '\(number)' part of the title?")
                }
            }
        }
    }

    private func processInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for multi-line (bulk) input
        let (_, isMultiLine) = SmartTextParser.isMultiTask(text)
        if isMultiLine {
            bulkLines = SmartTextParser.parseMultiLine(text)
            showBulkConfirmation = true
            return
        }

        // Single-line: parse for smart duration
        let result = SmartTextParser.parseLine(text)

        if let _ = result.ambiguousNumber {
            ambiguousResult = result
            showAmbiguousPrompt = true
        } else {
            let task = TaskItem(
                title: result.title.isEmpty ? text : result.title,
                duration: result.duration ?? 1800,
                colorName: selectedColor
            )
            onAdd([task])
            dismiss()
        }
    }
}

#Preview {
    AddTaskView(insertIndex: nil, lastColor: "blue") { _ in }
}
