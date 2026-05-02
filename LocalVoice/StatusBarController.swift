import AppKit
import Combine

/// Owns the NSStatusItem (menu-bar icon) and contextual menu.
@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let appState: AppState
    private weak var transcriptMenuItem: NSMenuItem?
    private weak var ollamaMenuItem: NSMenuItem?
    private weak var deviceMenu: NSMenu?

    init(appState: AppState) {
        self.appState = appState
        buildStatusItem()
        observeState()
    }

    // MARK: - Build

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "LocalVoice")
        item.button?.toolTip = "LocalVoice — Hold Ctrl+Shift+Z to dictate"
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let transcriptItem = NSMenuItem(title: "No transcription yet", action: nil, keyEquivalent: "")
        transcriptItem.isEnabled = false
        menu.addItem(transcriptItem)
        transcriptMenuItem = transcriptItem

        menu.addItem(.separator())

        let deviceItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        let dMenu = NSMenu()
        deviceItem.submenu = dMenu
        menu.addItem(deviceItem)
        deviceMenu = dMenu

        menu.addItem(.separator())

        let hotkey = NSMenuItem(title: "Hotkey: Ctrl+Shift+Z (hold)", action: nil, keyEquivalent: "")
        hotkey.isEnabled = false
        menu.addItem(hotkey)

        menu.addItem(.separator())

        let ollamaStatus = NSMenuItem(
            title: "Ollama: not running — tap to install",
            action: #selector(showOllamaInstructions),
            keyEquivalent: ""
        )
        ollamaStatus.target = self
        menu.addItem(ollamaStatus)
        ollamaMenuItem = ollamaStatus

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit LocalVoice", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func showOllamaInstructions() {
        let a = NSAlert()
        a.messageText = "Enable Smart Cleanup with Ollama"
        a.informativeText =
            "LocalVoice uses Ollama to remove filler words and fix grammar — all on-device.\n\n" +
            "1.  brew install ollama\n" +
            "2.  ollama pull llama3.2:3b\n" +
            "3.  ollama serve\n\n" +
            "LocalVoice will detect Ollama automatically on the next launch."
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        let deviceID = UInt32(sender.tag)
        print("LocalVoice: User selected microphone: \(sender.title) (ID: \(deviceID))")
        appState.selectDevice(id: deviceID)
    }

    // MARK: - Observation

    private func observeState() {
        appState.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                let icon = (phase == .recording) ? "mic.fill" : "mic"
                self.statusItem?.button?.image = NSImage(
                    systemSymbolName: icon,
                    accessibilityDescription: "LocalVoice"
                )
            }
            .store(in: &cancellables)

        appState.$lastTranscript
            .receive(on: RunLoop.main)
            .filter { !$0.isEmpty }
            .sink { [weak self] text in
                let preview = text.count > 60 ? String(text.prefix(57)) + "…" : text
                self?.transcriptMenuItem?.title = preview
            }
            .store(in: &cancellables)

        appState.$ollamaAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] available in
                self?.ollamaMenuItem?.title = available
                    ? "Ollama: running ✓"
                    : "Ollama: not running — tap to install"
                self?.ollamaMenuItem?.action = available ? nil : #selector(self?.showOllamaInstructions)
            }
            .store(in: &cancellables)

        appState.$availableDevices
            .combineLatest(appState.$selectedDeviceID)
            .receive(on: RunLoop.main)
            .sink { [weak self] devices, selectedID in
                guard let self, let dMenu = self.deviceMenu else { return }
                dMenu.removeAllItems()
                for device in devices {
                    let item = NSMenuItem(title: device.name, action: #selector(self.selectDevice), keyEquivalent: "")
                    item.target = self
                    item.tag = Int(device.id)
                    item.state = (device.id == selectedID) ? .on : .off
                    dMenu.addItem(item)
                }
                if devices.isEmpty {
                    let item = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    dMenu.addItem(item)
                }
            }
            .store(in: &cancellables)
    }
}
