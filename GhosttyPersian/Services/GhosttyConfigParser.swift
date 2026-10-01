import Foundation

/// Non-destructive parser for Ghostty configuration files.
public struct GhosttyConfigParser: Sendable {
    public init() {}

    /// Parses configuration text into a structured, round-trip preserving `GhosttyConfigDocument`.
    public func parse(_ content: String) -> GhosttyConfigDocument {
        let lineEnding = content.contains("\r\n") ? "\r\n" : "\n"
        let hasTrailingNewline = content.hasSuffix("\r\n") || content.hasSuffix("\n") || content.hasSuffix("\r")

        let normalized: String
        if hasTrailingNewline {
            normalized = String(content.dropLast(1))
        } else {
            normalized = content
        }

        let rawLines: [String]
        if normalized.isEmpty && !hasTrailingNewline {
            rawLines = []
        } else {
            rawLines = normalized
                .components(separatedBy: "\n")
                .map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        }

        let parsedLines = rawLines.map { parseLine($0) }

        return GhosttyConfigDocument(
            lines: parsedLines,
            lineEnding: lineEnding,
            hasTrailingNewline: hasTrailingNewline
        )
    }

    /// Parses an individual line into a `GhosttyConfigLine`.
    public func parseLine(_ line: String) -> GhosttyConfigLine {
        // 1. Blank line (empty or whitespace only)
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            return .blank(rawText: line)
        }

        // 2. Comment line (starts with # after optional leading whitespace)
        let leadingWhitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let contentAfterWhitespace = String(line.dropFirst(leadingWhitespace.count))

        if contentAfterWhitespace.hasPrefix("#") {
            let commentText = String(contentAfterWhitespace.dropFirst())
            return .comment(text: commentText, leadingWhitespace: leadingWhitespace, rawText: line)
        }

        // 3. Assignment line (contains '=' where key is non-empty)
        if let equalsIndex = line.firstIndex(of: "=") {
            let keyPart = line[..<equalsIndex]
            let valuePart = line[line.index(after: equalsIndex)...]

            let keyLeadingWhitespace = String(keyPart.prefix(while: { $0 == " " || $0 == "\t" }))
            let trimmedKey = keyPart.trimmingCharacters(in: .whitespaces)

            if !trimmedKey.isEmpty {
                let trailingKeyWhitespace = String(keyPart.dropFirst(keyLeadingWhitespace.count + trimmedKey.count))
                let leadingValWhitespace = String(valuePart.prefix(while: { $0 == " " || $0 == "\t" }))
                let trimmedVal = valuePart.trimmingCharacters(in: .whitespaces)

                let isQuoted = trimmedVal.count >= 2 && trimmedVal.hasPrefix("\"") && trimmedVal.hasSuffix("\"")
                let logicalValue = isQuoted ? String(trimmedVal.dropFirst().dropLast()) : trimmedVal

                let separatorWhitespace = "\(trailingKeyWhitespace)=\(leadingValWhitespace)"

                let assignment = GhosttyConfigAssignment(
                    key: trimmedKey,
                    value: logicalValue,
                    isQuoted: isQuoted,
                    leadingWhitespace: keyLeadingWhitespace,
                    separatorWhitespace: separatorWhitespace,
                    rawText: line
                )
                return .assignment(assignment)
            }
        }

        // 4. Unrecognized line
        return .unrecognized(rawText: line)
    }
}
