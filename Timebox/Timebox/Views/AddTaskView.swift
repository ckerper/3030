import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var showBulkConfirmation = false
    @State private var bulkLines: [SmartTextParser.ParseResult] = []
    @State private var showAmbiguousPrompt = false
    @State private var ambiguousResult: SmartTextParser.ParseResult?

    let insertIndex: Int?
    let onAdd: ([TaskItem]) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Task")
                    .font(.headline)

                Text("Type a task name. Add a number at the end to set the duration in minutes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
                        } else {
                            Text("Duration: 30:00 (default)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

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
                    let tasks = bulkLines.map { result in
                        TaskItem(
                            title: result.title,
                            duration: result.duration ?? 1800
                        )
                    }
                    onAdd(tasks)
                    dismiss()
                }
                Button("Create one task with long title") {
                    let task = TaskItem(title: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
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
                            duration: result.duration ?? 1800
                        )
                        onAdd([task])
                        dismiss()
                    }
                    Button("Keep '\(number)' in title") {
                        let task = TaskItem(title: inputText.trimmingCharacters(in: .whitespaces))
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
        let (lineCount, isMultiLine) = SmartTextParser.isMultiTask(text)
        if isMultiLine {
            bulkLines = SmartTextParser.parseMultiLine(text)
            showBulkConfirmation = true
            return
        }

        // Single-line: parse for smart duration
        let result = SmartTextParser.parseLine(text)

        if let _ = result.ambiguousNumber {
            // Ambiguous: could be part of title
            ambiguousResult = result
            showAmbiguousPrompt = true
        } else {
            // Clear case
            let task = TaskItem(
                title: result.title.isEmpty ? text : result.title,
                duration: result.duration ?? 1800
            )
            onAdd([task])
            dismiss()
        }
    }
}

#Preview {
    AddTaskView(insertIndex: nil) { _ in }
}
