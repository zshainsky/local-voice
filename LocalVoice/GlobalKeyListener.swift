import CoreGraphics
import Foundation

/// Listens for Ctrl+Shift+Z globally via CGEventTap.
/// Key-down starts recording; key-up stops. Repeated key-down while held is suppressed.
final class GlobalKeyListener {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDown = false

    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void

    // Z = keycode 6
    private static let targetKeyCode: CGKeyCode = 6

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
    }

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let listener = Unmanaged<GlobalKeyListener>.fromOpaque(userInfo).takeUnretainedValue()
                return listener.handle(type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            print("LocalVoice: CGEventTap creation failed — grant Input Monitoring in System Settings › Privacy.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == Self.targetKeyCode else { return Unmanaged.passRetained(event) }

        if type == .keyUp && isDown {
            isDown = false
            onKeyUp()
            return nil
        }

        let flags = event.flags
        let required: CGEventFlags = [.maskControl, .maskShift]
        let forbidden: CGEventFlags = [.maskCommand, .maskAlternate]

        guard flags.isSuperset(of: required),
              flags.intersection(forbidden).isEmpty
        else { return Unmanaged.passRetained(event) }

        if type == .keyDown {
            guard !isDown else { return nil }   // suppress key-repeat
            isDown = true
            onKeyDown()
            return nil                          // swallow event
        }

        return Unmanaged.passRetained(event)
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
    }

    deinit { stop() }
}
