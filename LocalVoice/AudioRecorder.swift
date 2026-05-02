import AVFoundation

enum RecorderError: Error {
    case formatUnsupported
    case converterFailed
    case engineStartFailed
}

/// Captures microphone audio and resamples to 16 kHz Float32 mono for WhisperKit.
actor AudioRecorder {
    private var engine: AVAudioEngine?
    private var samples: [Float] = []

    func start(deviceID: UInt32? = nil) throws {
        samples = []

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Set device ID as early as possible
        if let deviceID = deviceID {
            print("LocalVoice: Recorder attempting to use device ID: \(deviceID)")
            do {
                try inputNode.auAudioUnit.setDeviceID(deviceID)
            } catch {
                print("LocalVoice: Failed to set input device \(deviceID) — \(error)")
            }
        }

        let nativeFormat = inputNode.inputFormat(forBus: 0)
        
        // Log the format to help debugging if it still fails
        print("LocalVoice: Input format: \(nativeFormat.sampleRate)Hz, \(nativeFormat.channelCount) channels")

        guard nativeFormat.sampleRate > 0, nativeFormat.channelCount > 0 else {
            throw RecorderError.formatUnsupported
        }

        guard let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1) else {
            throw RecorderError.formatUnsupported
        }
        
        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            throw RecorderError.converterFailed
        }

        // Install tap directly on inputNode. 
        // We DO NOT access mixer or outputNode to avoid -10875 in clamshell mode.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            let ratio = 16_000.0 / nativeFormat.sampleRate
            let outCount = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
            guard outCount > 0,
                  let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCount)
            else { return }

            var provided = false
            let status = converter.convert(to: output, error: nil) { _, outStatus in
                if !provided {
                    provided = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                outStatus.pointee = .noDataNow
                return nil
            }

            guard status != .error, let channelData = output.floatChannelData?[0] else { return }
            let floats = Array(UnsafeBufferPointer(start: channelData, count: Int(output.frameLength)))

            Task { await self?.append(floats) }
        }

        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    private func append(_ new: [Float]) {
        samples.append(contentsOf: new)
    }

    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        return samples
    }
}
