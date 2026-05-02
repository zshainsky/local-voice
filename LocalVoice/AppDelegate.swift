import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hudWindowController: HUDWindowController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissions()

        statusBarController = StatusBarController(appState: appState)
        hudWindowController = HUDWindowController(appState: appState)

        // Load WhisperKit model + start key listener
        appState.initialize()
    }

    private func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Permissions Required"
            alert.informativeText = "LocalVoice needs 'Input Monitoring' and 'Accessibility' permissions to detect the global hotkey (Ctrl+Shift+Z).\n\nPlease enable LocalVoice in System Settings > Privacy & Security, then restart the app."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
