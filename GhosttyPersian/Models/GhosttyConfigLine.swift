import Foundation

/// Represents a single line within a Ghostty configuration file.
public enum GhosttyConfigLine: Sendable, Equatable {
    /// A comment line starting with '#' (with optional leading whitespace).
    case comment(text: String, leadingWhitespace: String, rawText: String)

    /// An empty or whitespace-only line.
    case blank(rawText: String)

    /// A valid key-value assignment (e.g. `key = value`).
    case assignment(GhosttyConfigAssignment)

    /// A line that could not be parsed as a comment, blank, or assignment.
    case unrecognized(rawText: String)

    /// Returns the text of the line, preserving original format if unmodified.
    public var serializedText: String {
        switch self {
        case .comment(_, _, let rawText):
            return rawText
        case .blank(let rawText):
            return rawText
        case .assignment(let assignment):
            return assignment.serializedText
        case .unrecognized(let rawText):
            return rawText
        }
    }

    /// Convenience accessor for assignment data if this line is an assignment.
    public var assignment: GhosttyConfigAssignment? {
        get {
            if case .assignment(let a) = self { return a }
            return nil
        }
        set {
            if let newValue = newValue {
                self = .assignment(newValue)
            }
        }
    }
}

/// Detailed representation of a `key = value` assignment in Ghostty configuration.
public struct GhosttyConfigAssignment: Sendable, Equatable {
    /// The trimmed configuration key (e.g., "font-size", "theme").
    public var key: String

    /// The unquoted logical value (e.g., "14", "Vazirmatn").
    public var value: String

    /// Whether the value is enclosed in double quotes.
    public var isQuoted: Bool

    /// Whitespace preceding the key.
    public var leadingWhitespace: String

    /// Delimiter and whitespace between key and value (default " = ").
    public var separatorWhitespace: String

    /// Raw original line text if unmodified from source.
    public var rawText: String?

    public init(
        key: String,
        value: String,
        isQuoted: Bool = false,
        leadingWhitespace: String = "",
        separatorWhitespace: String = " = ",
        rawText: String? = nil
    ) {
        self.key = key
        self.value = value
        self.isQuoted = isQuoted
        self.leadingWhitespace = leadingWhitespace
        self.separatorWhitespace = separatorWhitespace
        self.rawText = rawText
    }

    /// Updates the logical value, invalidating the cached raw text to trigger re-serialization.
    public mutating func updateValue(_ newValue: String, isQuoted: Bool? = nil) {
        self.value = newValue
        if let isQuoted = isQuoted {
            self.isQuoted = isQuoted
        }
        self.rawText = nil
    }

    /// Serializes the assignment back into text.
    public var serializedText: String {
        if let rawText = rawText {
            return rawText
        }
        let formattedValue = isQuoted ? "\"\(value)\"" : value
        return "\(leadingWhitespace)\(key)\(separatorWhitespace)\(formattedValue)"
    }

    public static func == (lhs: GhosttyConfigAssignment, rhs: GhosttyConfigAssignment) -> Bool {
        lhs.key == rhs.key &&
        lhs.value == rhs.value &&
        lhs.isQuoted == rhs.isQuoted &&
        lhs.leadingWhitespace == rhs.leadingWhitespace &&
        lhs.separatorWhitespace == rhs.separatorWhitespace
    }
}
