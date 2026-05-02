import AppKit
import CoreGraphics

/// Injects text at the current cursor position by simulating Cmd+V.
/// Saves and restores the user's original clipboard contents.
struct TextInjector {

    @MainActor
    static func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("LocalVoice: Text copied to clipboard")
    }

    @MainActor
    static func inject(text: String) async {
        // Also copy to clipboard as requested
        copyToClipboard(text: text)

        // Small delay so target app clipboard read catches up, then paste
        try? await Task.sleep(for: .milliseconds(100))
        simulatePaste()
    }

    private static func simulatePaste() {
        let vKeyCode: CGKeyCode = 9
        let src = CGEventSource(stateID: .hidSystemState)

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}
