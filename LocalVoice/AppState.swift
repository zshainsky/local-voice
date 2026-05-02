import Foundation
import Combine

// MARK: - Phase

enum AppPhase: Sendable {
    case loading        // WhisperKit model loading
    case idle
    case recording
    case transcribing
    case cleaning       // Ollama (optional)
    case injecting
    case error(String)
}

extension AppPhase: Equatable {
    static func == (lhs: AppPhase, rhs: AppPhase) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.idle, .idle), (.recording, .recording),
             (.transcribing, .transcribing), (.cleaning, .cleaning), (.injecting, .injecting):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .loading
    @Published var lastTranscript: String = ""
    @Published var ollamaAvailable: Bool = false
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDeviceID: UInt32?
    @Published var ollamaEnabled: Bool = UserDefaults.standard.bool(forKey: "ollamaEnabled") {
        didSet { UserDefaults.standard.set(ollamaEnabled, forKey: "ollamaEnabled") }
    }

    private var keyListener: GlobalKeyListener?
    private var activeRecorder: AudioRecorder?
    private let transcriber = WhisperTranscriber()
    private let transformer = OllamaTransformer()

    func initialize() {
        Task {
            await transcriber.loadModel()
            ollamaAvailable = await transformer.isAvailable()
            refreshDevices()
            phase = .idle
            startKeyListener()
        }
    }

    func refreshDevices() {
        availableDevices = AudioDeviceFinder.findInputDevices()
        if selectedDeviceID == nil {
            // Default to system default input device
            selectedDeviceID = AudioDeviceFinder.getDefaultInputDeviceID()
        }
    }

    func selectDevice(id: UInt32) {
        selectedDeviceID = id
    }

    // MARK: - Key listener

    private func startKeyListener() {
        keyListener = GlobalKeyListener(
            onKeyDown: { [weak self] in Task { @MainActor in self?.handleKeyDown() } },
            onKeyUp:   { [weak self] in Task { @MainActor in self?.handleKeyUp() } }
        )
        keyListener?.start()
    }

    // MARK: - Recording flow

    private func handleKeyDown() {
        guard phase == .idle else { return }
        phase = .recording
        let recorder = AudioRecorder()
        activeRecorder = recorder
        Task {
            do { try await recorder.start(deviceID: selectedDeviceID) }
            catch {
                activeRecorder = nil
                phase = .error("Mic error: \(error.localizedDescription)")
                scheduleReset(after: 3)
            }
        }
    }

    private func handleKeyUp() {
        guard phase == .recording, let recorder = activeRecorder else { return }
        activeRecorder = nil
        Task { await process(recorder: recorder) }
    }

    private func process(recorder: AudioRecorder) async {
        phase = .transcribing
        let samples = await recorder.stop()

        guard !samples.isEmpty else { phase = .idle; return }

        do {
            let rawText = try await transcriber.transcribe(samples: samples)
            let rawTrimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawTrimmed.isEmpty else { phase = .idle; return }

            var finalOutput = "Raw: \(rawTrimmed)"
            
            if ollamaAvailable && ollamaEnabled {
                phase = .cleaning
                if let cleaned = try? await transformer.clean(text: rawTrimmed) {
                    finalOutput += "\n\nCleaned: \(cleaned)"
                }
            }

            phase = .injecting
            lastTranscript = finalOutput
            print("LocalVoice: Injecting output: \"\(finalOutput)\"")
            await TextInjector.inject(text: finalOutput)

        } catch TranscriberError.silence {
            phase = .error("No audio detected. Is your mic muted or lid closed?")
        } catch {
            phase = .error(error.localizedDescription)
        }

        scheduleReset(after: 1.5)
    }

    private func scheduleReset(after delay: Double) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            if phase != .recording { phase = .idle }
        }
    }
}
