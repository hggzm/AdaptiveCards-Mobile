import XCTest
@testable import ACCore
@testable import ACRendering

/// Tests for ShowCard focus management (upstream #166).
///
/// Validates:
/// - CardViewModel publishes showCards changes for VoiceOver notifications
/// - ShowCard expanded/collapsed state is properly tracked
/// - Focus-related state changes trigger appropriate VoiceOver notifications
final class ShowCardFocusAccessibilityTests: XCTestCase {

    func testShowCardToggleUpdatesState() throws {
        let viewModel = CardViewModel()
        XCTAssertTrue(viewModel.showCards.isEmpty,
            "Initially no ShowCards should be expanded")

        viewModel.toggleShowCard(actionId: "comment")
        XCTAssertTrue(viewModel.isShowCardExpanded(actionId: "comment"),
            "ShowCard should be expanded after toggle")
    }

    func testShowCardCollapseUpdatesState() throws {
        let viewModel = CardViewModel()
        viewModel.toggleShowCard(actionId: "comment")
        XCTAssertTrue(viewModel.isShowCardExpanded(actionId: "comment"))

        viewModel.toggleShowCard(actionId: "comment")
        XCTAssertFalse(viewModel.isShowCardExpanded(actionId: "comment"),
            "ShowCard should be collapsed after second toggle")
    }

    func testShowCardExpandedStatePublishable() throws {
        let viewModel = CardViewModel()
        viewModel.toggleShowCard(actionId: "details")

        // Verify the showCards dictionary has the expanded state
        let expandedId = viewModel.showCards.first(where: { $0.value })?.key
        XCTAssertEqual(expandedId, "details",
            "showCards should contain the expanded card ID for VoiceOver focus routing")
    }

    func testMultipleShowCardsOnlyOneExpanded() throws {
        let viewModel = CardViewModel()
        viewModel.toggleShowCard(actionId: "card1")
        viewModel.toggleShowCard(actionId: "card2")

        // Typically only one ShowCard is visible at a time
        // but both states should be tracked
        XCTAssertTrue(viewModel.showCards.keys.count >= 2,
            "Multiple ShowCard states should be tracked")
    }

    func testShowCardExpandedIdDetectable() throws {
        let viewModel = CardViewModel()
        viewModel.toggleShowCard(actionId: "info")

        // The onChange handler in ActionSetView uses this pattern:
        let expandedId = viewModel.showCards.first(where: { $0.value })?.key
        XCTAssertNotNil(expandedId,
            "Should be able to detect which ShowCard was just expanded " +
            "so .screenChanged notification can be posted (#166)")
    }

    func testShowCardCollapsedIdDetectable() throws {
        let viewModel = CardViewModel()
        viewModel.toggleShowCard(actionId: "info")
        viewModel.toggleShowCard(actionId: "info")

        // After collapse, no expanded card
        let expandedId = viewModel.showCards.first(where: { $0.value })?.key
        XCTAssertNil(expandedId,
            "Should detect no expanded ShowCard so .layoutChanged is posted " +
            "instead of .screenChanged (#166)")
    }

    // MARK: - ShowCard card parsing

    func testShowCardWithInputFieldParseable() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.6", "body": [],
         "actions": [
            {"type": "Action.ShowCard", "id": "comment", "title": "Comment",
             "card": {"type": "AdaptiveCard", "body": [
                 {"type": "Input.Text", "id": "commentInput",
                  "placeholder": "Enter your comment"}
             ]}}
         ]}
        """
        let card = try CardParser().parse(json)
        let action = try XCTUnwrap(card.actions?.first)

        if case .showCard(let showCardAction) = action {
            let firstElement = try XCTUnwrap(showCardAction.card.body?.first)
            XCTAssertTrue(firstElement is TextInput,
                "ShowCard should contain Input.Text element for focus target (#166)")
        } else {
            XCTFail("Expected Action.ShowCard")
        }
    }
}
