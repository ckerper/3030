import Foundation

struct SmartTextParser {
    struct ParseResult {
        let title: String
        let duration: TimeInterval? // nil if no duration detected
        let ambiguousNumber: String? // the number string if it might be part of the title
    }

    /// Parse a single line of text into a task title and optional duration.
    /// A trailing number is always treated as minutes for the duration.
    /// The only ambiguous case is "at [number]" or "@ [number]" — e.g. "Call at 11"
    /// could mean an 11-minute timer or a reminder about 11 o'clock.
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
        let numberStr = String(lastWord)

        // Only flag as ambiguous if the word before the number is "at" or "@"
        let secondToLast = components.count >= 2 ? String(components[components.count - 2]).lowercased() : ""
        let isAmbiguous = (secondToLast == "at" || secondToLast == "@")

        return ParseResult(
            title: titlePart,
            duration: durationSeconds,
            ambiguousNumber: isAmbiguous ? numberStr : nil
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
