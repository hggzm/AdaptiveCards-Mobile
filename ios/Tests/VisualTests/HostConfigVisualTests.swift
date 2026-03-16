#if canImport(UIKit)
import XCTest
import SwiftUI
@testable import ACCore
@testable import ACRendering

/// Visual regression tests that render the same cards across different HostConfig presets.
///
/// Validates rendering consistency when hosted by different apps (Teams, Outlook, etc.)
/// by applying their HostConfig JSON, which controls spacing, fonts, colors, actions, etc.
///
/// ## Adding a new host config
/// 1. Add JSON to shared/test-cards/host-configs/<name>.json
/// 2. Add a case to HostConfigPreset
/// 3. Record: RECORD_SNAPSHOTS=1 swift test --filter HostConfigVisualTests
final class HostConfigVisualTests: CardSnapshotTestCase {

    enum HostConfigPreset: String, CaseIterable {
        case defaultConfig = "default"
        case teamsLight = "microsoft-teams-light"
        case teamsDark = "microsoft-teams-dark"

        var snapshotName: String {
            switch self {
            case .defaultConfig: return "Default"
            case .teamsLight: return "TeamsLight"
            case .teamsDark: return "TeamsDark"
            }
        }

        func load() -> HostConfig? {
            if self == .defaultConfig { return nil }
            let testFileURL = URL(fileURLWithPath: #filePath)
            let repoRoot = testFileURL
                .deletingLastPathComponent()  // VisualTests/
                .deletingLastPathComponent()  // Tests/
                .deletingLastPathComponent()  // ios/
                .deletingLastPathComponent()  // repo root
            let configPath = repoRoot
                .appendingPathComponent("shared/test-cards/host-configs/\(rawValue).json")
            guard let data = try? Data(contentsOf: configPath) else {
                print("HostConfigPreset: Could not load \(rawValue).json")
                return nil
            }
            return try? HostConfigParser.parse(data)
        }
    }

    static let activePresets: [HostConfigPreset] = [.defaultConfig, .teamsLight, .teamsDark]

    static let representativeCards: [String] = [
        "simple-text", "containers", "all-actions", "all-inputs",
        "table", "accordion", "carousel", "compound-buttons",
        "code-block", "rating", "fluent-theming",
    ]

    // MARK: - Multi-Config Tests

    /// Renders each representative card with every host config preset.
    func testRepresentativeCards_allPresets() {
        var totalTests = 0
        var passed = 0
        var failures: [(String, String, String)] = []

        for card in Self.representativeCards {
            for preset in Self.activePresets {
                let hc = preset.load()
                let name = "\(card)_\(preset.snapshotName)"
                do {
                    let json = try loadTestCard(named: card)
                    let view = createCardView(json: json, hostConfig: hc)
                    let r = assertSnapshot(of: view, named: name, configuration: .iPhone15Pro)
                    totalTests += 1
                    if r.passed || recordMode { passed += 1 }
                    else { failures.append((card, preset.snapshotName, r.message)) }
                } catch {
                    totalTests += 1
                    failures.append((card, preset.snapshotName, "\(error)"))
                }
            }
        }
        print("""
        HOST CONFIG VISUAL TESTS: \(passed)/\(totalTests) passed
        Presets: \(Self.activePresets.map(\.snapshotName).joined(separator: ", "))
        Cards:   \(Self.representativeCards.count)
        """)
        if !failures.isEmpty && !recordMode {
            for f in failures { print("  X \(f.0) [\(f.1)]: \(f.2)") }
        }
    }

    // Individual card tests for focused debugging
    func testSimpleText_allPresets() { renderAcrossPresets("simple-text") }
    func testContainers_allPresets() { renderAcrossPresets("containers") }
    func testAllActions_allPresets() { renderAcrossPresets("all-actions") }
    func testAllInputs_allPresets() { renderAcrossPresets("all-inputs") }
    func testTable_allPresets() { renderAcrossPresets("table") }

    private func renderAcrossPresets(_ card: String) {
        for preset in Self.activePresets {
            assertCardSnapshot(named: card, configuration: .iPhone15Pro, hostConfig: preset.load())
        }
    }
}
#endif
