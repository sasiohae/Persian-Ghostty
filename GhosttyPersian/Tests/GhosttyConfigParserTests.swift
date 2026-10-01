import XCTest
@testable import GhosttyPersian

final class GhosttyConfigParserTests: XCTestCase {
    private let parser = GhosttyConfigParser()

    // 1. Basic key/value parsing
    func testBasicKeyValueParsing() {
        let input = "font-size = 14\n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 1)
        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "14")

        guard case .assignment(let assignment) = doc.lines[0] else {
            return XCTFail("Expected assignment line")
        }
        XCTAssertEqual(assignment.key, "font-size")
        XCTAssertEqual(assignment.value, "14")
        XCTAssertFalse(assignment.isQuoted)
        XCTAssertEqual(assignment.separatorWhitespace, " = ")
    }

    // 2. Comments
    func testCommentsParsing() {
        let input = "# This is a comment\n  # Indented comment\n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 2)
        guard case .comment(let text1, let lead1, _) = doc.lines[0] else {
            return XCTFail("Expected comment on line 1")
        }
        XCTAssertEqual(text1, " This is a comment")
        XCTAssertEqual(lead1, "")

        guard case .comment(let text2, let lead2, _) = doc.lines[1] else {
            return XCTFail("Expected comment on line 2")
        }
        XCTAssertEqual(text2, " Indented comment")
        XCTAssertEqual(lead2, "  ")
    }

    // 3. Blank lines
    func testBlankLines() {
        let input = "\n   \n\n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 3)
        for line in doc.lines {
            guard case .blank = line else {
                return XCTFail("Expected blank line")
            }
        }
        XCTAssertEqual(doc.serialize(), input)
    }

    // 4. Leading and trailing whitespace
    func testLeadingAndTrailingWhitespace() {
        let input = "   font-size = 14   \n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "14")
        guard case .assignment(let assignment) = doc.lines[0] else {
            return XCTFail("Expected assignment line")
        }
        XCTAssertEqual(assignment.leadingWhitespace, "   ")
        XCTAssertEqual(assignment.key, "font-size")
        XCTAssertEqual(doc.serialize(), input)
    }

    // 5. Quoted values
    func testQuotedValues() {
        let input = "font-family = \"Vazirmatn\"\n"
        let doc = parser.parse(input)

        guard case .assignment(let assignment) = doc.lines[0] else {
            return XCTFail("Expected assignment")
        }
        XCTAssertEqual(assignment.key, "font-family")
        XCTAssertEqual(assignment.value, "Vazirmatn")
        XCTAssertTrue(assignment.isQuoted)
        XCTAssertEqual(doc.serialize(), input)
    }

    // 6. Repeated keys
    func testRepeatedKeys() {
        let input = """
        font-family = "JetBrains Mono"
        font-family = "Vazirmatn"
        font-family = "Symbols Nerd Font"

        """
        let doc = parser.parse(input)

        XCTAssertEqual(doc.allValues(for: "font-family"), [
            "JetBrains Mono",
            "Vazirmatn",
            "Symbols Nerd Font"
        ])
        XCTAssertEqual(doc.effectiveValue(for: "font-family"), "Symbols Nerd Font")
        XCTAssertEqual(doc.serialize(), input)
    }

    // 7. Unknown keys
    func testUnknownKeys() {
        let input = "some-future-unknown-option = custom_value_123\n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 1)
        XCTAssertEqual(doc.effectiveValue(for: "some-future-unknown-option"), "custom_value_123")
        XCTAssertEqual(doc.serialize(), input)
    }

    // 8. Unrecognized lines
    func testUnrecognizedLines() {
        let input = "this is not an assignment or a comment\n"
        let doc = parser.parse(input)

        XCTAssertEqual(doc.lines.count, 1)
        guard case .unrecognized(let raw) = doc.lines[0] else {
            return XCTFail("Expected unrecognized line")
        }
        XCTAssertEqual(raw, "this is not an assignment or a comment")
        XCTAssertEqual(doc.serialize(), input)
    }

    // 9. Comments between configuration entries
    func testCommentsBetweenConfigurationEntries() {
        let input = """
        # Window size
        window-width = 120
        # Vertical height
        window-height = 40

        """
        let doc = parser.parse(input)
        XCTAssertEqual(doc.lines.count, 4)
        XCTAssertEqual(doc.effectiveValue(for: "window-width"), "120")
        XCTAssertEqual(doc.effectiveValue(for: "window-height"), "40")
        XCTAssertEqual(doc.serialize(), input)
    }

    // Additional syntax checks: Values with '=' and '#'
    func testValuesContainingEqualsAndHashSigns() {
        let input = """
        palette = 0=#1d2021
        keybind = ctrl+d=new_split:right
        background = #282c34

        """
        let doc = parser.parse(input)

        XCTAssertEqual(doc.effectiveValue(for: "palette"), "0=#1d2021")
        XCTAssertEqual(doc.effectiveValue(for: "keybind"), "ctrl+d=new_split:right")
        XCTAssertEqual(doc.effectiveValue(for: "background"), "#282c34")
        XCTAssertEqual(doc.serialize(), input)
    }

    // 10. Realistic round-trip preservation
    func testRealisticRoundTripPreservation() {
        let sampleConfig = """
        # ==============================================================================
        # Ghostty Terminal Configuration File
        # Generated by developer setup
        # ==============================================================================

        # --- Typography & Fonts ---
        font-family = "JetBrains Mono"
        font-family = "Vazirmatn"
        font-size = 14.5
        font-thicken = true
        adjust-cell-height = 15%

        # --- Appearance & Window ---
        theme = "Catppuccin Mocha"
        background-opacity = 0.94
        background-blur = true
        macos-titlebar-style = transparent

        # Custom Keybindings
        keybind = super+shift+,=reload_config
        keybind = super+d=new_split:right

        # Palette definition
        palette = 0=#1e1e2e
        palette = 1=#f38ba8

        """
        let doc = parser.parse(sampleConfig)
        let serialized = doc.serialize()
        XCTAssertEqual(serialized, sampleConfig)
    }

    // Safe mutation: Updating an existing key in-place
    func testInPlaceValueModification() {
        let input = """
        # Header
        font-size = 14
        theme = "Dark"

        """
        var doc = parser.parse(input)
        doc.setValue(key: "font-size", value: "16")

        let expected = """
        # Header
        font-size = 16
        theme = "Dark"

        """
        XCTAssertEqual(doc.serialize(), expected)
    }

    // Safe mutation: Repeated key replacement
    func testRepeatedKeyReplacement() {
        let input = """
        # Fonts
        font-family = "Courier"
        font-size = 14

        """
        var doc = parser.parse(input)
        doc.setRepeatedValues(key: "font-family", values: ["JetBrains Mono", "Vazirmatn"], isQuoted: true)

        let expected = """
        # Fonts
        font-family = "JetBrains Mono"
        font-family = "Vazirmatn"
        font-size = 14

        """
        XCTAssertEqual(doc.serialize(), expected)
    }

    // Safe mutation: Removing a key
    func testRemoveKey() {
        let input = """
        font-size = 14
        font-family = "Vazirmatn"
        cursor-style = bar

        """
        var doc = parser.parse(input)
        doc.removeKey("cursor-style")

        let expected = """
        font-size = 14
        font-family = "Vazirmatn"

        """
        XCTAssertEqual(doc.serialize(), expected)
    }
}
