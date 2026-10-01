import XCTest
@testable import GhosttyPersian

final class ConfigurationEdgeCasesTests: XCTestCase {
    private let parser = GhosttyConfigParser()

    // MARK: - 1. Complex Quoted Values

    func testComplexQuotedValuesWithEscapedQuotes() {
        let input = """
        command = "bash -c \\"echo hello\\""
        title = "Ghostty \\"Persian\\" Edition"
        """
        let doc = parser.parse(input)

        XCTAssertEqual(doc.effectiveValue(for: "command"), "bash -c \\\"echo hello\\\"")
        XCTAssertEqual(doc.effectiveValue(for: "title"), "Ghostty \\\"Persian\\\" Edition")
        XCTAssertEqual(doc.serialize(), input)
    }

    func testQuotedValuesWithSymbols() {
        let input = """
        keybind = "ctrl+#=toggle_quick_terminal"
        custom-banner = "Project #1 = Complete; Status: Active!"
        font-feature = "+ss01, +cv02, #calt"
        greeting = "سلام دنیا! 🚀 Ghostty Persian = عالی"
        """
        let doc = parser.parse(input)

        XCTAssertEqual(doc.effectiveValue(for: "keybind"), "ctrl+#=toggle_quick_terminal")
        XCTAssertEqual(doc.effectiveValue(for: "custom-banner"), "Project #1 = Complete; Status: Active!")
        XCTAssertEqual(doc.effectiveValue(for: "font-feature"), "+ss01, +cv02, #calt")
        XCTAssertEqual(doc.effectiveValue(for: "greeting"), "سلام دنیا! 🚀 Ghostty Persian = عالی")
        XCTAssertEqual(doc.serialize(), input)
    }

    // MARK: - 2. Mixed Line Endings

    func testMixedLineEndingsPreservation() {
        // Document with mixed CRLF (\r\n) and LF (\n)
        let mixedInput = "font-size = 14\r\n# Intermediate Comment\ntheme = \"Dracula\"\r\nwindow-padding-x = 12\n"
        let doc = parser.parse(mixedInput)

        XCTAssertEqual(doc.lines.count, 4)
        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "14")
        XCTAssertEqual(doc.effectiveValue(for: "theme"), "Dracula")
        XCTAssertEqual(doc.effectiveValue(for: "window-padding-x"), "12")

        // Serializes cleanly without corrupted newlines
        let serialized = doc.serialize()
        XCTAssertFalse(serialized.contains("\r\r"))
        XCTAssertTrue(serialized.contains("font-size = 14"))
        XCTAssertTrue(serialized.contains("theme = \"Dracula\""))
    }

    func testPureCRLFPreservation() {
        let crlfInput = "font-size = 16\r\nfont-family = \"Vazirmatn\"\r\n"
        let doc = parser.parse(crlfInput)

        XCTAssertEqual(doc.lineEnding, "\r\n")
        XCTAssertEqual(doc.lines.count, 2)
        XCTAssertEqual(doc.serialize(), crlfInput)
    }

    // MARK: - 3. Repeated Keys Interleaved with Comments and Empty Lines

    func testRepeatedKeysWithInterleavedCommentsAndBlanks() {
        let input = """
        # Primary coding font
        font-family = "JetBrains Mono"

        # Persian and Arabic fallback font
        font-family = "Vazirmatn"

        # Symbols and icons
        font-family = "Symbols Nerd Font"

        font-size = 14
        """
        var doc = parser.parse(input)

        XCTAssertEqual(doc.allValues(for: "font-family"), [
            "JetBrains Mono",
            "Vazirmatn",
            "Symbols Nerd Font"
        ])
        XCTAssertEqual(doc.effectiveValue(for: "font-family"), "Symbols Nerd Font")

        // Replace repeated values
        doc.setRepeatedValues(key: "font-family", values: ["Menlo", "Sahel"], isQuoted: true)

        XCTAssertEqual(doc.allValues(for: "font-family"), ["Menlo", "Sahel"])
        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "14")

        let serialized = doc.serialize()
        XCTAssertTrue(serialized.contains("# Primary coding font"))
        XCTAssertTrue(serialized.contains("# Persian and Arabic fallback font"))
        XCTAssertTrue(serialized.contains("font-family = \"Menlo\""))
        XCTAssertTrue(serialized.contains("font-family = \"Sahel\""))
        XCTAssertTrue(serialized.contains("font-size = 14"))
    }

    // MARK: - 4. Malformed and Corner-Case Lines

    func testMultipleEqualsOnSingleLine() {
        let input = "keybind = super+ctrl+alt=split:right\n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 1)
        guard case .assignment(let assignment) = doc.lines[0] else {
            return XCTFail("Expected assignment line")
        }
        XCTAssertEqual(assignment.key, "keybind")
        XCTAssertEqual(assignment.value, "super+ctrl+alt=split:right")
        XCTAssertEqual(doc.serialize(), input)
    }

    func testEmptyValuesAndWhitespaceOnly() {
        let input = """
        empty-key =
        whitespace-key =
        quoted-empty = ""
        """
        let doc = parser.parse(input)

        XCTAssertEqual(doc.effectiveValue(for: "empty-key"), "")
        XCTAssertEqual(doc.effectiveValue(for: "whitespace-key"), "")
        XCTAssertEqual(doc.effectiveValue(for: "quoted-empty"), "")
        XCTAssertEqual(doc.serialize(), input)
    }

    func testUnrecognizedAndCorruptedLines() {
        let input = """
        === Section Header ===
         = missing-key
        ??? non-standard syntax
        # valid comment
        font-size = 12
        """
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 5)
        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "12")

        // Round-trip preserves the corrupted lines verbatim
        XCTAssertEqual(doc.serialize(), input)
    }

    func testUnclosedQuotes() {
        let input = "font-family = \"Unclosed Font Name\n"
        let doc = parser.parse(input)

        guard case .assignment(let assignment) = doc.lines[0] else {
            return XCTFail("Expected assignment")
        }
        XCTAssertEqual(assignment.key, "font-family")
        XCTAssertFalse(assignment.isQuoted)
        XCTAssertEqual(assignment.value, "\"Unclosed Font Name")
        XCTAssertEqual(doc.serialize(), input)
    }

    // MARK: - 5. Unusually Large Configuration Inputs

    func testLargeConfigurationInputPerformanceAndPreservation() {
        var lines: [String] = []
        for i in 1...2500 {
            if i % 10 == 0 {
                lines.append("# Comment line block \(i)")
            } else if i % 5 == 0 {
                lines.append("")
            } else if i % 3 == 0 {
                lines.append("font-family = \"Font_\(i)\"")
            } else {
                lines.append("setting-\(i) = value_\(i)")
            }
        }
        let largeInput = lines.joined(separator: "\n") + "\n"

        let startTime = CFAbsoluteTimeGetCurrent()
        let doc = parser.parse(largeInput)
        let parseTime = CFAbsoluteTimeGetCurrent() - startTime

        // Should parse 2500 lines in well under 0.5s
        XCTAssertLessThan(parseTime, 0.5)
        XCTAssertEqual(doc.lines.count, 2500)

        let serialized = doc.serialize()
        XCTAssertEqual(serialized, largeInput)
    }

    // MARK: - 6. Safe Key Manipulation & Removal

    func testKeyRemovalAcrossMultipleOccurrences() {
        let input = """
        # Duplicate key removal test
        palette = 0=#000000
        palette = 1=#111111
        font-size = 14
        palette = 2=#222222
        """
        var doc = parser.parse(input)
        XCTAssertEqual(doc.allValues(for: "palette").count, 3)

        doc.removeKey("palette")
        XCTAssertEqual(doc.allValues(for: "palette").count, 0)
        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "14")

        let serialized = doc.serialize()
        XCTAssertFalse(serialized.contains("palette"))
        XCTAssertTrue(serialized.contains("font-size = 14"))
        XCTAssertTrue(serialized.contains("# Duplicate key removal test"))
    }
}
