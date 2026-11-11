import SwiftUI
import AppKit

// Bridges the hosting NSWindow into SwiftUI. macOS 14 has no scene modifier
// for window level, so the header pin needs the NSWindow instance itself.
// The window is reported from viewDidMoveToWindow only: writing observable
// state from updateNSView would re-enter the view update and loop.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: WindowReaderView, context: Context) {
        nsView.onWindow = onWindow
    }
}

final class WindowReaderView: NSView {
    var onWindow: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let window = self.window
        // Defer: viewDidMoveToWindow can run inside a layout pass, where
        // publishing SwiftUI state is not allowed.
        DispatchQueue.main.async { [weak self] in
            self?.onWindow?(window)
        }
    }
}
