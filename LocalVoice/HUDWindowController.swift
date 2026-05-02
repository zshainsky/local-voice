import AppKit
import SwiftUI
import Combine

/// Manages the floating, non-activating HUD panel that reflects AppState.
@MainActor
final class HUDWindowController {
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        buildPanel()
        observeState()
    }

    // MARK: - Setup

    private func buildPanel() {
        let hosting = NSHostingView(rootView: HUDView(appState: appState))
        hosting.frame = NSRect(x: 0, y: 0, width: 240, height: 50)

        let p = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false          // shadow baked into HUDView
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.contentView = hosting

        // Position: bottom-center of main screen
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - p.frame.width / 2
            let y = screen.visibleFrame.minY + 80
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel = p
    }

    // MARK: - Observation

    private func observeState() {
        appState.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                switch phase {
                case .idle:
                    self.hide(delay: 0.8)
                default:
                    self.show()
                }
            }
            .store(in: &cancellables)
    }

    private func show() {
        panel?.orderFront(nil)
    }

    private func hide(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }
}
