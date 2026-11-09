import SwiftUI
import AppKit

// NSTextView-backed editor inside an NSScrollView.
// Two-way binding is IME-safe: while marked text (composition) is active the
// binding is not propagated; it propagates when the composition commits.
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var isFocused: FocusState<Bool>.Binding? = nil
    var onUserEdited: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor(hex: 0x111827)
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        textView.isEditable = isEditable

        // Sync external changes only when they differ, to avoid update loops.
        if textView.string != text {
            let previousRange = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            let location = min(previousRange.location, length)
            let clampedLength = min(previousRange.length, length - location)
            textView.selectedRange = NSRange(location: location, length: clampedLength)
        }

        if let focusBinding = isFocused, focusBinding.wrappedValue,
           textView.window?.firstResponder !== textView {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor

        init(parent: CodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Do not propagate while IME composition is in progress.
            if textView.hasMarkedText() { return }
            parent.text = textView.string
            parent.onUserEdited?()
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused?.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused?.wrappedValue = false
            guard let textView = notification.object as? NSTextView else { return }
            if !textView.hasMarkedText() {
                parent.text = textView.string
            }
        }
    }
}
