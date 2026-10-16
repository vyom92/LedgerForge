import SwiftUI

/// A presentation snapshot only. The owner's raw input, validation and persistence
/// continue independently; typing must not resize the surface hosting the editor.
struct LFEditingPresentation<Value> {
    private(set) var held: Value?

    init() {}

    mutating func begin(_ value: Value) {
        if held == nil { held = value }
    }

    mutating func end() { held = nil }
    func value(or current: @autoclosure () -> Value) -> Value { held ?? current() }
}

/// Keep live hints within a stable footprint. Full wording remains available to
/// accessibility and help; validation expands only after editing has finished.
struct LFNumericInputFeedback: View {
    @Environment(\.lfTheme) private var theme
    let isEditing: Bool
    let error: String?
    var hint: String? = nil

    private var message: String {
        if isEditing { return hint ?? (error == nil ? "" : "Continue typing…") }
        return error ?? ""
    }

    private var text: Text { Text(message.isEmpty ? " " : message) }

    var body: some View {
        Group {
            if isEditing || error == nil { text.lineLimit(2, reservesSpace: true) }
            else { text.fixedSize(horizontal: false, vertical: true) }
        }
            .font(theme.typography.caption)
            .foregroundStyle(!isEditing && error != nil ? LFTheme.warning : theme.palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(message)
            .accessibilityLabel(message)
            .accessibilityHidden(message.isEmpty)
    }
}
