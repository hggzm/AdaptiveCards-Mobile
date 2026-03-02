import XCTest
@testable import ACCore

/// Tests for accessibility fixes:
/// - #15: Container should not cause VoiceOver "Group" announcement
/// - #16 + #17: ShowCard actions should have correct metadata for focus
/// - #27 + #32: Required fields must carry isRequired for VoiceOver
final class ContainerFocusRequiredTests: XCTestCase {

    // MARK: - ShowCard Actions (#16, #17)

    func testShowCardActionHasIdForFocusTracking() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "TextBlock", "text": "Info"}
            ],
            "actions": [
                {"type": "Action.ShowCard", "id": "showMore", "title": "More Info",
                 "card": {"type": "AdaptiveCard", "body": [
                     {"type": "TextBlock", "text": "Details here"}
                 ]}}
            ]}
        """)

        guard let action = card.actions?.first else {
            XCTFail("Expected at least one action")
            return
        }

        if case .showCard(let showCardAction) = action {
            XCTAssertNotNil(showCardAction.id, "ShowCard action must have an ID for focus tracking")
            XCTAssertEqual(showCardAction.title, "More Info")
            XCTAssertNotNil(showCardAction.card.body, "ShowCard must have card body for focus target")
        } else {
            XCTFail("Expected Action.ShowCard")
        }
    }

    func testMultipleShowCardsHaveDistinctIds() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "TextBlock", "text": "Card"}
            ],
            "actions": [
                {"type": "Action.ShowCard", "id": "card1", "title": "Card 1",
                 "card": {"type": "AdaptiveCard", "body": [{"type": "TextBlock", "text": "One"}]}},
                {"type": "Action.ShowCard", "id": "card2", "title": "Card 2",
                 "card": {"type": "AdaptiveCard", "body": [{"type": "TextBlock", "text": "Two"}]}}
            ]}
        """)

        guard let actions = card.actions, actions.count == 2 else {
            XCTFail("Expected 2 actions")
            return
        }

        var ids = [String]()
        for action in actions {
            if case .showCard(let sc) = action {
                if let id = sc.id { ids.append(id) }
            }
        }

        XCTAssertEqual(ids.count, 2, "Both ShowCards should have IDs")
        XCTAssertNotEqual(ids[0], ids[1], "ShowCard IDs must be distinct for focus routing")
    }

    // MARK: - Required Field Accessibility (#27, #32)

    func testInputTextIsRequiredParsed() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "Input.Text", "id": "nameInput", "label": "Name",
                 "isRequired": true, "errorMessage": "Name is required"}
            ]}
        """)

        if case .inputText(let input) = card.body?[0] {
            XCTAssertTrue(input.isRequired, "isRequired must be true")
            XCTAssertEqual(input.label, "Name")
            XCTAssertEqual(input.errorMessage, "Name is required")
        } else {
            XCTFail("Expected Input.Text")
        }
    }

    func testInputNumberIsRequiredParsed() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "Input.Number", "id": "ageInput", "label": "Age",
                 "isRequired": true}
            ]}
        """)

        if case .inputNumber(let input) = card.body?[0] {
            XCTAssertTrue(input.isRequired ?? false, "isRequired must be true")
            XCTAssertEqual(input.label, "Age")
        } else {
            XCTFail("Expected Input.Number")
        }
    }

    func testInputToggleIsRequiredParsed() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "Input.Toggle", "id": "agreeToggle", "title": "I agree",
                 "label": "Agreement", "isRequired": true}
            ]}
        """)

        if case .inputToggle(let input) = card.body?[0] {
            XCTAssertTrue(input.isRequired ?? false, "isRequired must be true for toggle")
            XCTAssertEqual(input.label, "Agreement")
        } else {
            XCTFail("Expected Input.Toggle")
        }
    }

    func testInputNotRequiredByDefault() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "Input.Text", "id": "optionalInput", "label": "Notes"}
            ]}
        """)

        if case .inputText(let input) = card.body?[0] {
            XCTAssertFalse(input.isRequired, "isRequired should default to false")
        } else {
            XCTFail("Expected Input.Text")
        }
    }

    func testInputChoiceSetIsRequiredParsed() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "Input.ChoiceSet", "id": "colorChoice", "label": "Color",
                 "isRequired": true,
                 "choices": [
                     {"title": "Red", "value": "red"},
                     {"title": "Blue", "value": "blue"}
                 ]}
            ]}
        """)

        if case .inputChoiceSet(let input) = card.body?[0] {
            XCTAssertTrue(input.isRequired ?? false, "isRequired must be true for ChoiceSet")
        } else {
            XCTFail("Expected Input.ChoiceSet")
        }
    }

    // MARK: - Container Accessibility (#15)

    func testContainerWithMultipleElements() throws {
        let card = try parseCard("""
            {"type": "AdaptiveCard", "version": "1.6", "body": [
                {"type": "Container", "items": [
                    {"type": "TextBlock", "text": "Title"},
                    {"type": "TextBlock", "text": "Subtitle"}
                ]}
            ]}
        """)

        if case .container(let container) = card.body?[0] {
            XCTAssertEqual(container.items?.count, 2)
        } else {
            XCTFail("Expected Container")
        }
    }

    // MARK: - Helper

    private func parseCard(_ json: String) throws -> AdaptiveCard {
        let parser = CardParser()
        return try parser.parse(json)
    }
}
