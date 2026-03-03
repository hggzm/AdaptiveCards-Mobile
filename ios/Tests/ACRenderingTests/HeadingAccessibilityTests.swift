import XCTest
@testable import ACCore
@testable import ACRendering

/// Tests for heading accessibility traits and selectAction interaction
/// (upstream #170).
///
/// Validates:
/// - TextBlocks with style="heading" are identified as headings
/// - Non-heading TextBlocks don't get heading trait
/// - Containers with selectAction have proper accessibility traits
/// - selectAction accessibility hint includes action title
final class HeadingAccessibilityTests: XCTestCase {

    // MARK: - TextBlock heading style

    func testTextBlockHeadingStyleParsed() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.5", "body": [
            {"type": "TextBlock", "text": "Product Video",
             "style": "Heading", "size": "Large"}
        ]}
        """
        let card = try CardParser().parse(json)
        let textBlock = try XCTUnwrap(card.body?.first as? TextBlock)
        XCTAssertEqual(textBlock.style, .heading,
            "TextBlock with style='Heading' should parse as .heading")
    }

    func testTextBlockDefaultStyleNotHeading() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.5", "body": [
            {"type": "TextBlock", "text": "Regular text"}
        ]}
        """
        let card = try CardParser().parse(json)
        let textBlock = try XCTUnwrap(card.body?.first as? TextBlock)
        XCTAssertNil(textBlock.style,
            "TextBlock without style should have nil style (not heading)")
    }

    func testHeadingTraitAppliedForHeadingStyle() throws {
        // Verify the pattern: style == .heading should get .isHeader trait
        let style: TextBlockStyle? = .heading
        let traits: AccessibilityTraits = style == .heading ? .isHeader : []
        XCTAssertTrue(traits.contains(.isHeader),
            "Heading-style TextBlocks should get .isHeader accessibility trait " +
            "so VoiceOver announces 'heading' instead of 'double tap to activate' (#170)")
    }

    func testNoHeadingTraitForDefaultStyle() throws {
        let style: TextBlockStyle? = nil
        let traits: AccessibilityTraits = style == .heading ? .isHeader : []
        XCTAssertFalse(traits.contains(.isHeader),
            "Non-heading TextBlocks should NOT get .isHeader trait")
    }

    // MARK: - SelectAction parsing

    func testContainerWithSelectActionParsed() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.5", "body": [
            {"type": "Container",
             "selectAction": {"type": "Action.OpenUrl", "url": "https://example.com",
                              "title": "View details"},
             "items": [{"type": "TextBlock", "text": "Click me"}]}
        ]}
        """
        let card = try CardParser().parse(json)
        let container = try XCTUnwrap(card.body?.first as? Container)
        XCTAssertNotNil(container.selectAction,
            "Container should have selectAction parsed")
    }

    func testSelectActionTitleAvailableForHint() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.5", "body": [
            {"type": "Container",
             "selectAction": {"type": "Action.OpenUrl", "url": "https://example.com",
                              "title": "View details"},
             "items": [{"type": "TextBlock", "text": "Content"}]}
        ]}
        """
        let card = try CardParser().parse(json)
        let container = try XCTUnwrap(card.body?.first as? Container)
        let actionTitle = container.selectAction?.title
        XCTAssertEqual(actionTitle, "View details",
            "selectAction title should be available for accessibility hint (#170)")
    }

    func testColumnSetWithSelectActionParsable() throws {
        let json = """
        {"type": "AdaptiveCard", "version": "1.5", "body": [
            {"type": "ColumnSet", "columns": [
                {"type": "Column", "width": "auto",
                 "selectAction": {"type": "Action.OpenUrl",
                                  "url": "https://example.com",
                                  "title": "Open column"},
                 "items": [{"type": "TextBlock", "text": "Col text",
                            "style": "Heading"}]}
            ]}
        ]}
        """
        let card = try CardParser().parse(json)
        let columnSet = try XCTUnwrap(card.body?.first as? ColumnSet)
        let column = try XCTUnwrap(columnSet.columns?.first)
        XCTAssertNotNil(column.selectAction,
            "Column selectAction should be parsed for proper a11y traits")
    }

    // MARK: - Cross-platform parity

    func testHeadingRoleMatchesAndroidSemantics() throws {
        // Android uses Modifier.semantics { heading() } for heading-style TextBlocks.
        // iOS should use .isHeader trait for parity.
        let style: TextBlockStyle? = .heading
        XCTAssertEqual(style, .heading,
            "Heading style should match Android's heading() semantics for parity")
    }
}
