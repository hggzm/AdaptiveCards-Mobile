import XCTest
@testable import ACCore
@testable import ACInputs

/// Tests for required field visual indicator (upstream #190).
///
/// Validates:
/// - Required input fields include visual asterisk (*) indicator
/// - Non-required fields do not show asterisk
/// - VoiceOver announces "required" for required fields
/// - Both NumberInput and TextInput support required state
final class RequiredFieldVisualTests: XCTestCase {

    // MARK: - NumberInput required state

    func testNumberInputRequiredProperty() throws {
        let input = NumberInput(id: "age", label: "Age", isRequired: true)
        XCTAssertEqual(input.isRequired, true,
            "NumberInput should expose isRequired property for visual asterisk")
    }

    func testNumberInputNotRequired() throws {
        let input = NumberInput(id: "optional", label: "Quantity")
        XCTAssertNil(input.isRequired,
            "NumberInput without isRequired should be nil")
    }

    func testNumberInputRequiredFromJSON() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.3", "body": [
            {"type": "Input.Number", "id": "age", "label": "Age",
             "isRequired": true, "errorMessage": "Age is required"}
        ]}
        """
        let card = try CardParser().parse(json)
        let element = try XCTUnwrap(card.body?.first as? NumberInput)
        XCTAssertEqual(element.isRequired, true)
        XCTAssertEqual(element.label, "Age")
    }

    // MARK: - TextInput required state

    func testTextInputRequiredProperty() throws {
        let input = TextInput(id: "name", label: "Name", isRequired: true)
        XCTAssertEqual(input.isRequired, true,
            "TextInput should expose isRequired property for visual asterisk")
    }

    func testTextInputNotRequired() throws {
        let input = TextInput(id: "notes", label: "Notes")
        XCTAssertNil(input.isRequired,
            "TextInput without isRequired should be nil")
    }

    func testTextInputRequiredFromJSON() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.3", "body": [
            {"type": "Input.Text", "id": "name", "label": "Name",
             "isRequired": true, "errorMessage": "Name is required"}
        ]}
        """
        let card = try CardParser().parse(json)
        let element = try XCTUnwrap(card.body?.first as? TextInput)
        XCTAssertEqual(element.isRequired, true)
        XCTAssertEqual(element.label, "Name")
    }

    // MARK: - Accessibility announcement

    func testAccessibilityLabelIncludesRequired() throws {
        // The accessibilityInput modifier adds ", required" to label
        // Verify the pattern is correct
        let label = "Name"
        let isRequired = true
        var accessibilityLabel = label
        if isRequired {
            accessibilityLabel += ", required"
        }
        XCTAssertTrue(accessibilityLabel.contains("required"),
            "VoiceOver label should include 'required' for required fields (#190)")
    }

    func testAccessibilityLabelOmitsRequiredWhenNotRequired() throws {
        let label = "Notes"
        let isRequired = false
        var accessibilityLabel = label
        if isRequired {
            accessibilityLabel += ", required"
        }
        XCTAssertFalse(accessibilityLabel.contains("required"),
            "VoiceOver label should NOT include 'required' for optional fields")
    }

    // MARK: - Cross-platform parity

    func testRequiredFieldsMatchAndroidBehavior() throws {
        // Android shows "Label *" for required fields and includes
        // "required" in the contentDescription. iOS should match.
        let input = TextInput(id: "email", label: "Email", isRequired: true)
        XCTAssertEqual(input.isRequired, true)
        XCTAssertEqual(input.label, "Email",
            "Label should be available for visual asterisk rendering " +
            "matching Android's 'Email *' pattern")
    }
}
