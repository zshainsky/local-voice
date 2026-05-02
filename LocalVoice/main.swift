import AppKit

// The main thread is the main actor. Declare that explicitly so @MainActor types
// (AppDelegate, AppState) can be instantiated safely from this entry point.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory) // Menu bar only; no Dock icon
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
