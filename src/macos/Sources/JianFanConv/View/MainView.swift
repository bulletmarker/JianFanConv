import SwiftUI
import AppKit

// Root view: header, toolbar, two cards, status bar, plus all conversion
// behavior (200 ms debounce, background conversion, stale-result dropping,
// paste / copy / clear), mirroring the Windows MainForm.
struct MainView: View {
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var s2t = true
    @State private var variant: ChineseVariant = .taiwan
    @State private var localPhrases = true
    @State private var status = "就绪"
    @State private var generation = 0
    @State private var debounceTask: Task<Void, Never>?
    @State private var pinned = false
    @State private var window: NSWindow?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(isPinned: pinned, onTogglePin: togglePin, onClear: clearAll)
            ToolbarView(s2t: $s2t, variant: $variant, localPhrases: $localPhrases)

            HStack(spacing: 12) {
                Card(title: "原文", count: inputText.count, actionTitle: "粘贴", action: pasteFromClipboard) {
                    ZStack(alignment: .topLeading) {
                        CodeEditor(
                            text: $inputText,
                            isFocused: $inputFocused,
                            onUserEdited: scheduleDebounce
                        )
                        if inputText.isEmpty {
                            Text(s2t ? "在此输入或粘贴简体中文…" : "在此输入或粘贴繁体中文…")
                                .font(Theme.bodyFont)
                                .foregroundColor(Theme.textMuted)
                                .padding(10)
                                .allowsHitTesting(false)
                        }
                    }
                }

                Card(title: "结果", count: outputText.count, actionTitle: "复制", action: copyResult) {
                    CodeEditor(text: $outputText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            StatusBar(status: status)
        }
        .background(Theme.background)
        .background(WindowAccessor { newWindow in
            if window !== newWindow {
                window = newWindow
                applyPinLevel()
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { note in
            // A .floating window wedges the fullscreen transition: the window
            // enters fullscreen but "Exit Full Screen" then does nothing.
            // Hand the level back to AppKit while fullscreen is in charge.
            guard (note.object as? NSWindow) === window else { return }
            window?.level = .normal
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { note in
            guard (note.object as? NSWindow) === window else { return }
            applyPinLevel()
        }
        .onAppear {
            EngineBootstrap.perform()
            DispatchQueue.main.async { inputFocused = true }
        }
        .onChange(of: s2t) { _, _ in convertNow() }
        .onChange(of: variant) { _, _ in convertNow() }
        .onChange(of: localPhrases) { _, _ in convertNow() }
    }

    // ---- behavior ----------------------------------------------------

    private func scheduleDebounce() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            startConversion()
        }
    }

    private func convertNow() {
        debounceTask?.cancel()
        debounceTask = nil
        startConversion()
    }

    private func startConversion() {
        let text = inputText
        if text.isEmpty {
            generation += 1
            if !outputText.isEmpty {
                outputText = ""
            }
            status = "就绪"
            return
        }

        generation += 1
        let ver = generation
        let captureS2t = s2t
        let captureVariant = variant
        let capturePhrases = localPhrases
        let startedAt = Date()

        Task.detached(priority: .userInitiated) {
            var converted: String?
            var convertError: Error?
            do {
                converted = try OpenCCEngine.shared.convert(
                    text,
                    s2t: captureS2t,
                    variant: captureVariant,
                    localPhrases: capturePhrases
                )
            } catch {
                convertError = error
            }
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            let result = converted
            let failure = convertError

            await MainActor.run {
                guard ver == self.generation else { return }
                if let failure {
                    self.status = "转换失败：\(failure.localizedDescription)"
                    return
                }
                self.outputText = result ?? ""
                self.status = "已转换 · \(elapsedMs) ms · "
                    + Self.profileName(s2t: captureS2t, variant: captureVariant, phrases: capturePhrases)
            }
        }
    }

    private static func profileName(s2t: Bool, variant: ChineseVariant, phrases: Bool) -> String {
        let direction = s2t ? "简→繁" : "繁→简"
        var region = variant.title
        if variant != .standard && phrases {
            region += "·用词"
        }
        return direction + " " + region
    }

    private func pasteFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            status = "剪贴板中没有文本"
            return
        }
        inputText = clipboardText
        convertNow()
    }

    private func copyResult() {
        guard !outputText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        status = "已复制到剪贴板"
    }

    private func togglePin() {
        pinned = !pinned
        applyPinLevel()
    }

    // Only the windowed state owns the level; native fullscreen does.
    private func applyPinLevel() {
        guard let window else { return }
        let floating = pinned && !window.styleMask.contains(.fullScreen)
        window.level = floating ? .floating : .normal
    }

    private func clearAll() {
        generation += 1
        debounceTask?.cancel()
        debounceTask = nil
        inputText = ""
        outputText = ""
        status = "就绪"
        inputFocused = true
    }
}
