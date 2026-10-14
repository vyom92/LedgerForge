import AppKit
import Testing
@testable import LedgerForge

/// Native responder mechanics only; no financial statement or domain fixture.
@MainActor
struct TextEditingFocusTests {
    @Test func backgroundClickEndsFieldEditingWithoutChangingText() throws {
        let (window, _, field) = setup()
        defer { window.close() }
        field.selectText(nil)
        let editor = try #require(window.firstResponder as? NSTextView)
        #expect(editor.isFieldEditor)
        editor.string = "Owner note"
        TextEditingClickObserver.finishEditing(at: NSPoint(x: 20, y: 20), in: window)
        #expect(window.firstResponder !== editor)
        #expect(field.stringValue == "Owner note")
    }

    @Test func clickInsideTheActiveFieldKeepsItsSelection() throws {
        let (window, _, field) = setup()
        defer { window.close() }
        field.selectText(nil)
        let editor = try #require(window.firstResponder as? NSTextView)
        let selected = editor.selectedRange()
        TextEditingClickObserver.finishEditing(at: NSPoint(x: 50, y: 90), in: window)
        #expect(window.firstResponder === editor)
        #expect(editor.selectedRange() == selected)
    }

    @Test func backgroundClickDoesNotForceAResponderToResign() {
        let (window, background, _) = setup()
        defer { window.close() }
        let editor = RefusingEditor(frame: NSRect(x: 20, y: 80, width: 200, height: 24))
        editor.isFieldEditor = true
        background.addSubview(editor)
        #expect(window.makeFirstResponder(editor))
        editor.refusesToResign = true
        TextEditingClickObserver.finishEditing(at: NSPoint(x: 20, y: 20), in: window)
        #expect(window.firstResponder === editor)
        editor.refusesToResign = false
    }

    @Test func backgroundClickLeavesOtherRespondersAlone() throws {
        let (window, background, _) = setup()
        defer { window.close() }
        let textView = NSTextView(frame: .zero)
        background.addSubview(textView)
        #expect(window.makeFirstResponder(textView))
        TextEditingClickObserver.finishEditing(at: NSPoint(x: 20, y: 20), in: window)
        #expect(window.firstResponder === textView)
    }

    private func setup() -> (NSWindow, NSView, NSTextField) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let background = NSView(frame: window.contentView!.bounds)
        let field = NSTextField(string: "Note")
        field.frame = NSRect(x: 20, y: 80, width: 200, height: 24)
        background.addSubview(field)
        window.contentView = background
        return (window, background, field)
    }

    private final class RefusingEditor: NSTextView {
        var refusesToResign = false
        override func resignFirstResponder() -> Bool { !refusesToResign && super.resignFirstResponder() }
    }
}
