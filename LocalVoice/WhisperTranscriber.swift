import Foundation
import WhisperKit

enum TranscriberError: Error {
    case notLoaded
    case noResult
    case silence
}

/// Wraps WhisperKit. Model loads once at app start; stays resident for sub-500 ms transcription.
actor WhisperTranscriber {
    private var whisper: WhisperKit?

    func loadModel() async {
        let modelName = "openai_whisper-large-v3-v20240930_turbo"
        print("LocalVoice: WhisperKit initializing (Checking cache for \(modelName))...")
        
        do {
            // 1. Download/Verify the model with progress tracking
            let modelFolder = try await WhisperKit.download(
                variant: modelName,
                progressCallback: { progress in
                    let percent = Int(progress.fractionCompleted * 100)
                    print("LocalVoice: Downloading/Verifying model... \(percent)%")
                }
            )
            
            print("LocalVoice: Model folder located at: \(modelFolder.path)")

            // 2. Initialize with the specific folder
            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                )
            )
            
            whisper = try await WhisperKit(config)
            print("LocalVoice: WhisperKit ready (Model loaded in memory)")
        } catch {
            print("LocalVoice: WhisperKit load failed — \(error)")
        }
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let whisper else { 
            print("LocalVoice: Transcription failed — Model not loaded")
            throw TranscriberError.notLoaded 
        }

        // Silence detection: Calculate Root Mean Square (RMS) energy
        // If energy is extremely low, the mic is likely hardware-muted (clamshell mode)
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        print("LocalVoice: Audio energy (RMS): \(rms)")
        
        if rms < 0.001 {
            print("LocalVoice: Silence detected. Mic may be hardware-muted.")
            throw TranscriberError.silence
        }
        
        print("LocalVoice: Starting transcription (\(samples.count) samples)...")
        let results = try await whisper.transcribe(audioArray: samples)
        
        guard let first = results.first else { 
            print("LocalVoice: Transcription returned no results")
            throw TranscriberError.noResult 
        }
        
        print("LocalVoice: Transcription result: \"\(first.text)\"")
        return first.text
    }
}
