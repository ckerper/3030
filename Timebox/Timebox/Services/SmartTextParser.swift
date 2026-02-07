import Foundation

struct SmartTextParser {
    struct ParseResult {
        let title: String
        let duration: TimeInterval? // nil if no duration detected
        let ambiguousNumber: String? // the number string if it might be part of the title
    }

    /// Parse a single line of text into a task title and optional duration.
    /// Examples:
    ///   "Clear inbox 30" -> title: "Clear inbox", duration: 1800 (30 min)
    ///   "Chapter 12" -> title: "Chapter", duration: 720 (12 min) — but ambiguous!
    ///   "Write report" -> title: "Write report", duration: nil
    static func parseLine(_ text: String) -> ParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return ParseResult(title: "", duration: nil, ambiguousNumber: nil)
        }

        // Check if the last word is a number
        let components = trimmed.split(separator: " ")
        guard components.count > 1,
              let lastWord = components.last,
              let number = Double(String(lastWord)),
              number > 0, number <= 540 // max 9 hours = 540 minutes
        else {
            return ParseResult(title: trimmed, duration: nil, ambiguousNumber: nil)
        }

        let titlePart = components.dropLast().joined(separator: " ")
        let durationSeconds = number * 60 // treat number as minutes

        // Check if the number looks like it could be part of the title
        // (single or two digit number at end of a word-like title)
        let numberStr = String(lastWord)
        let couldBePartOfTitle = numberStr.count <= 3

        return ParseResult(
            title: titlePart,
            duration: durationSeconds,
            ambiguousNumber: couldBePartOfTitle ? numberStr : nil
        )
    }

    /// Parse multi-line pasted text into multiple task parse results.
    static func parseMultiLine(_ text: String) -> [ParseResult] {
        text.split(separator: "\n")
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { parseLine($0) }
    }

    /// Determine if pasted text is likely multiple tasks or one long title.
    static func isMultiTask(_ text: String) -> (lineCount: Int, isMultiLine: Bool) {
        let lines = text.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (lineCount: lines.count, isMultiLine: lines.count > 1)
    }
}
