import AppKit
import SwiftUI
import Testing
@testable import LedgerForge

/// Presentation/responder mechanics only; no financial records or source fixtures.
@MainActor
struct NumericEditingPresentationTests {
    @Test func styledFieldReportsNativeFocusToItsOwningForm() async throws {
        let probe = FocusProbe()
        let host = NSHostingView(rootView: FocusExample(probe: probe))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        func field(in view: NSView) -> NSTextField? {
            (view as? NSTextField) ?? view.subviews.lazy.compactMap { field(in: $0) }.first
        }
        let input = try #require(field(in: host))
        input.selectText(nil)
        for _ in 0..<20 where probe.value != "amount" {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(probe.value == "amount")
        #expect(window.makeFirstResponder(nil))
        for _ in 0..<20 where probe.value != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(probe.value == nil)
    }

    @Test func presentationWaitsForEditingToEndWithoutRewritingInput() {
        var presentation = LFEditingPresentation<String>()
        presentation.begin("Before editing")
        for input in ["", "-", ".", "12.", "12.3", "12.30", "invalid"] {
            presentation.begin(input)
            #expect(presentation.value(or: input) == "Before editing")
        }
        presentation.end()
        #expect(presentation.value(or: "12.") == "12.")
        presentation.begin("Next field")
        #expect(presentation.value(or: "Next update") == "Next field")
        presentation.end()
        #expect(presentation.value(or: "Current") == "Current")
    }

    @Test func liveFeedbackHasTheSameHeightForPartialInputAndLongHints() {
        func height(error: String?, hint: String?) -> CGFloat {
            let host = NSHostingView(rootView: LFNumericInputFeedback(isEditing: true, error: error, hint: hint).frame(width: 120))
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.height
        }
        let baseline = height(error: nil, hint: nil)
        #expect(baseline > 0)
        #expect(height(error: "Finish the decimal entry", hint: nil) == baseline)
        #expect(height(error: nil, hint: "A short hint") == baseline)
        #expect(height(error: nil, hint: String(repeating: "Long spoken hint ", count: 20)) == baseline)
    }

    @Test func healthyFXHasNoExtraMessageButWarningsRemainVisible() throws {
        let name = "NumericEditingPresentationTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let session = AlDarReferenceSession(defaults: defaults, enabled: false)
        #expect(session.observationWarning == nil)
        session.setNetworkAvailable(true)
        #expect(session.observationWarning == nil)
        session.setNetworkAvailable(false)
        #expect(session.observationWarning == "Offline · cached")
        session.installShared([:], failures: [.inr], busy: false, networkAvailable: true)
        #expect(session.observationWarning == "Refresh failed · cached")
        session.installShared([:], failures: [], busy: false, networkAvailable: true)
        #expect(session.observationWarning == nil)
    }

    private final class FocusProbe { var value: String? }
    private struct FocusExample: View {
        let probe: FocusProbe
        @State private var text = ""
        var body: some View {
            TextField("Amount", text: $text, onEditingChanged: { probe.value = $0 ? "amount" : nil })
                .lfTextField()
                .padding()
        }
    }
}
