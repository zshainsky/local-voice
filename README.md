# LocalVoice

Privacy-first, on-device dictation for macOS. Hold **Ctrl+Shift+Z**, speak, release — text appears at your cursor in any app.

All processing happens locally. No API keys. No network calls (except to localhost Ollama).

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 Sonoma or later |
| Xcode | 15+ |
| xcodegen | `brew install xcodegen` |
| Ollama *(optional)* | For smart cleanup — see below |

Apple Silicon (M1–M4) recommended for fast ANE inference.

---

## Quick Start

```bash
# 1. Clone / open the project directory
cd ~/Projects/local-voice

# 2. Generate the Xcode project
xcodegen generate

# 3. Open in Xcode
open LocalVoice.xcodeproj

# 4. Build & Run (Cmd+R)
```

On first launch, WhisperKit downloads the `whisper-large-v3-turbo` model (~600 MB) to `~/.cache/huggingface`. This happens once. The menu-bar icon appears immediately; dictation is available once "Loading model…" clears.

---

## macOS Permissions

Two permissions are required. macOS will prompt for both on first use.

### 1. Microphone
System Settings → Privacy & Security → Microphone → enable **LocalVoice**

### 2. Input Monitoring (for global hotkey)
System Settings → Privacy & Security → Input Monitoring → enable **LocalVoice**

> If the hotkey doesn't respond, open System Settings → Privacy & Security → Accessibility and add LocalVoice there as well.

---

## Usage

| Action | Gesture |
|---|---|
| Start recording | Hold **Ctrl+Shift+Z** |
| Stop & transcribe | Release **Ctrl+Shift+Z** |

The HUD at the bottom of your screen shows:
- 🔴 **Listening…** — recording
- ⏳ **Transcribing…** — WhisperKit running
- ⏳ **Cleaning…** — Ollama polishing text *(if installed)*
- ✅ **Done** — text injected at cursor

---

## Optional: Ollama Smart Cleanup

Ollama removes filler words, fixes grammar, and handles formatting commands. LocalVoice auto-detects Ollama on startup.

### Setup
1. **Install:** `brew install ollama`
2. **Start:** `ollama serve` (or run the app)
3. **Pull Model:** `ollama pull llama3.2:3b`

### Configuration
- **Toggle:** Click the microphone icon in the menu bar and select **"Ollama Smart Cleanup"** to enable/disable it.
- **Persistence:** The app remembers your enabled/disabled preference across launches.
- **Status:** If Ollama is not detected, the menu bar will display **"Ollama: not running — tap to install"**. Clicking this provides a reminder of the setup steps.

---

## Architecture

```
Ctrl+Shift+Z keydown
      │
      ▼
AudioRecorder (AVAudioEngine → 16 kHz Float32)
      │
      ▼
WhisperTranscriber (WhisperKit, ANE compute)
      │
      ▼
OllamaTransformer (localhost:11434, optional)
      │
      ▼
TextInjector (clipboard swap + Cmd+V simulation)
```

---

## Distribution (Ad-hoc)

To share with others without App Store:

1. In Xcode, set a Development Team under Signing & Capabilities.
2. Enable Hardened Runtime and add the `com.apple.security.device.microphone` entitlement.
3. Archive → Export → Developer ID.

The receiving Mac must still grant Input Monitoring and Microphone permissions.

---

## Customising the Hotkey

Edit `GlobalKeyListener.swift`:

```swift
private static let targetKeyCode: CGKeyCode = 6   // Z key (CGKeyCode reference: https://bit.ly/cg-key-codes)
// required flags:
let required: CGEventFlags = [.maskControl, .maskShift]
```

Full configurability via Settings UI is planned for a future release.
