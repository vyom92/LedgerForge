import AppKit
import SwiftUI

/// Keeps the native secure editor in place; revealing never replaces its binding,
/// selection, or first responder. The clear overlay exists only while requested.
struct LFPasswordField: View {
    let title: String
    @Binding var text: String
    @Environment(\.lfTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var pressed = false
    @State private var receivedPress = false
    @State private var briefReveal = false

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    private var revealed: Bool { isEnabled && !text.isEmpty && (pressed || briefReveal) }

    var body: some View {
        HStack(spacing: 8) {
            SecureField(title, text: $text)
                .textFieldStyle(.plain)
                .overlay(alignment: .leading) {
                    if revealed {
                        Text(text)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.palette.controlSurface)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            Button {
                // Pointer/Space presses reveal only while held. An accessibility
                // activation has no held phase, so it gets a short reveal instead.
                if receivedPress { receivedPress = false }
                else { briefReveal.toggle() }
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .frame(width: 28, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PasswordRevealStyle { value in
                pressed = value
                if value { receivedPress = true; briefReveal = false }
            })
            .disabled(text.isEmpty)
            .accessibilityLabel("Reveal \(title.lowercased())")
            .accessibilityHint("Press and hold to reveal. Accessibility activation reveals briefly.")
            .help("Press and hold to reveal \(title.lowercased())")
        }
        .lfTextField()
        .task(id: briefReveal) {
            guard briefReveal else { return }
            do { try await Task.sleep(for: .seconds(5)) }
            catch { return }
            briefReveal = false
        }
        .onChange(of: isEnabled) { _, enabled in if !enabled { conceal() } }
        .onChange(of: text) { _, _ in briefReveal = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in conceal() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in conceal() }
        .onDisappear(perform: conceal)
    }

    private func conceal() {
        pressed = false
        receivedPress = false
        briefReveal = false
    }
}

private struct PasswordRevealStyle: ButtonStyle {
    let pressChanged: (Bool) -> Void
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in pressChanged(pressed) }
    }
}
