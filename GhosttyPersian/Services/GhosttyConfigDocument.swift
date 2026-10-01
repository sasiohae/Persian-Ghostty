import Foundation

/// Represents a parsed Ghostty configuration document consisting of ordered lines.
///
/// Designed specifically for non-destructive round-trip editing where unmanaged keys,
/// comments, whitespace, and formatting are preserved verbatim.
public struct GhosttyConfigDocument: Sendable, Equatable {
    /// Ordered lines in the document.
    public var lines: [GhosttyConfigLine]

    /// The line ending delimiter used by the source document ("\n" or "\r\n").
    public var lineEnding: String

    /// Whether the original document terminated with a trailing newline.
    public var hasTrailingNewline: Bool

    public init(
        lines: [GhosttyConfigLine] = [],
        lineEnding: String = "\n",
        hasTrailingNewline: Bool = true
    ) {
        self.lines = lines
        self.lineEnding = lineEnding
        self.hasTrailingNewline = hasTrailingNewline
    }

    // MARK: - Serialization

    /// Serializes the document back to text, preserving original formatting for unmodified lines.
    public func serialize() -> String {
        guard !lines.isEmpty else {
            return hasTrailingNewline ? lineEnding : ""
        }
        let joined = lines.map(\.serializedText).joined(separator: lineEnding)
        return hasTrailingNewline ? joined + lineEnding : joined
    }

    // MARK: - Query Operations

    /// Checks if an assignment for the given key exists.
    public func contains(key: String) -> Bool {
        lines.contains { line in
            line.assignment?.key == key
        }
    }

    /// Returns all assignments matching the key in order of appearance.
    public func allAssignments(for key: String) -> [GhosttyConfigAssignment] {
        lines.compactMap { line in
            guard let assignment = line.assignment, assignment.key == key else { return nil }
            return assignment
        }
    }

    /// Returns all logical values for the key in order of appearance (e.g. for repeated keys like `font-family`).
    public func allValues(for key: String) -> [String] {
        allAssignments(for: key).map(\.value)
    }

    /// Returns the effective (last declared) assignment for the given key.
    ///
    /// In Ghostty configuration, later declarations override earlier ones.
    public func effectiveAssignment(for key: String) -> GhosttyConfigAssignment? {
        allAssignments(for: key).last
    }

    /// Returns the effective (last declared) logical value for the given key.
    public func effectiveValue(for key: String) -> String? {
        effectiveAssignment(for: key)?.value
    }

    // MARK: - Mutation Operations

    /// Sets or updates a single key-value assignment in-place.
    ///
    /// If the key already exists, updates the last occurrence in-place, preserving its indentation and separator style.
    /// If the key does not exist, appends the new assignment to the end of the document.
    public mutating func setValue(key: String, value: String, isQuoted: Bool = false) {
        if let lastIndex = lines.lastIndex(where: { $0.assignment?.key == key }) {
            if case .assignment(var assignment) = lines[lastIndex] {
                assignment.updateValue(value, isQuoted: isQuoted)
                lines[lastIndex] = .assignment(assignment)
            }
        } else {
            appendAssignment(key: key, value: value, isQuoted: isQuoted)
        }
    }

    /// Replaces all occurrences of a repeated key (such as `font-family`) with a new list of values.
    ///
    /// The new values are placed at the location of the first existing occurrence.
    /// If the key does not exist, the new assignments are appended to the document.
    public mutating func setRepeatedValues(key: String, values: [String], isQuoted: Bool = false) {
        let existingIndices = lines.indices.filter { lines[$0].assignment?.key == key }

        if existingIndices.isEmpty {
            for val in values {
                appendAssignment(key: key, value: val, isQuoted: isQuoted)
            }
            return
        }

        let firstIndex = existingIndices[0]
        let templateAssignment = lines[firstIndex].assignment

        // Remove existing lines in reverse index order
        for idx in existingIndices.reversed() {
            lines.remove(at: idx)
        }

        // Insert new values at firstIndex
        for (offset, val) in values.enumerated() {
            let assignment = GhosttyConfigAssignment(
                key: key,
                value: val,
                isQuoted: isQuoted,
                leadingWhitespace: templateAssignment?.leadingWhitespace ?? "",
                separatorWhitespace: templateAssignment?.separatorWhitespace ?? " = "
            )
            lines.insert(.assignment(assignment), at: firstIndex + offset)
        }
    }

    /// Removes all assignments matching the specified key.
    public mutating func removeKey(_ key: String) {
        lines.removeAll { line in
            line.assignment?.key == key
        }
    }

    /// Appends a new assignment to the end of the document.
    public mutating func appendAssignment(key: String, value: String, isQuoted: Bool = false) {
        let assignment = GhosttyConfigAssignment(
            key: key,
            value: value,
            isQuoted: isQuoted,
            leadingWhitespace: "",
            separatorWhitespace: " = "
        )
        lines.append(.assignment(assignment))
    }
}
