import SwiftUI
import ACCore

public extension View {
    /// Wraps element in a tap gesture for selectAction
    func selectAction(_ action: CardAction?, onTap: @escaping (CardAction) -> Void) -> some View {
        self.modifier(SelectActionModifier(action: action, onTap: onTap))
    }
}

struct SelectActionModifier: ViewModifier {
    let action: CardAction?
    let onTap: (CardAction) -> Void

    func body(content: Content) -> some View {
        if let action = action {
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap(action)
                }
                // Add button trait so VoiceOver announces the container as
                // interactive, and provide an accessibility hint with the
                // action title. This prevents child headings from confusingly
                // announcing "double tap to activate" without context
                // (upstream #170).
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(action.title.map { "Double tap to \($0)" } ?? "Double tap to activate")
        } else {
            content
        }
    }
}
