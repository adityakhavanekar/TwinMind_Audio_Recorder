# TwinMind Audio Recorder

A production-ready iOS audio recording application that records audio, transcribes it live using OpenAI Whisper API, and manages recordings with SwiftData. Built with Swift Concurrency (async/await) and Actor-based architecture.

## Note on Development

This assignment had a 48-hour deadline which was quite tight given the breadth of requirements. To maximize productivity, I used **Claude Code** (Anthropic's AI coding assistant) as a development aid to help with boilerplate code generation, debugging, and learning SwiftUI patterns (this was my first SwiftUI project — my background is in UIKit). All architectural decisions, testing, and integration were done by me. The AI helped me move faster, not think less.

## Setup Instructions

1. Clone the repository
2. Open `TwinMind_Audio_Recorder.xcodeproj` in Xcode 16+
3. Set your OpenAI API key in `TranscriptionActor.swift` (line with `Bearer` token)
4. Select your development team in Signing & Capabilities
5. Build and run on a physical iOS device (iOS 16.1+)

**Required Permissions (configured in Info.plist):**
- Microphone Usage
- Speech Recognition
- Live Activities
- Background Modes: Audio, AirPlay, and Picture in Picture

## What's Implemented & What's Not

### Fully Working

| Feature | Notes |
|---|---|
| AVAudioEngine recording | Continuous tap, no audio gaps between segments |
| Actor-based architecture | 3 actors: AudioRecordingActor, TranscriptionActor, DataManagerActor |
| 30-second auto-segmentation | Seamless file swap without removing the tap |
| Route change handling | Bluetooth connect/disconnect, headphone plug/unplug — rebuilds tap with correct sample rate |
| Interruption recovery | Phone calls, Siri — engine pauses and auto-resumes |
| Background recording | Audio background mode enabled, recording continues when app is backgrounded |
| Configurable audio quality | Low (Int16), Medium (Float32), High (Float32) presets |
| Real-time audio levels | Waveform visualization on recording screen |
| OpenAI Whisper API | Multipart upload, language set to "en" to reduce hallucination |
| Exponential backoff retry | Up to 5 retries with 1s, 2s, 4s, 8s, 16s delays |
| Local fallback | Falls back to Apple SFSpeechRecognizer after 5 consecutive API failures |
| Offline queuing | NetworkMonitor detects connectivity, queues segments offline, auto-processes when back online |
| SwiftData persistence | DataManagerActor wraps all CRUD, cascade deletes |
| Session/Segment/Transcription models | Proper relationships, cascade delete rules |
| Recording UI with waveform | Live animated bars driven by audio level data |
| Session list | Shows completed recordings, swipe to delete |
| Session detail view | Shows segments with transcription text, auto-refreshes |
| Permission and storage checks | Checks mic permission and disk space before recording |
| Tab-based navigation | Record tab + My Recordings tab |

### Partially Working

| Feature | Notes |
|---|---|
| App Intents (Siri) | Start/Stop Recording intents are registered and **visible in the Shortcuts app**. You can add them as shortcuts and trigger them. However, direct Siri voice activation ("Hey Siri, start recording with...") was inconsistent during testing. The intents work correctly when triggered from the Shortcuts app. |
| Live Activity | Fully implemented with ActivityKit. Console confirms activity is created and state is "active" with updates being sent. However, the visual Live Activity did not appear on the lock screen during testing on iPhone 13 (no Dynamic Island). The code follows Apple's documentation and should work on Dynamic Island devices (iPhone 14 Pro+). |
| Keychain for API token | KeychainManager is fully built with save/get/delete using iOS Keychain Services. Not wired up to the transcription flow — API key is hardcoded for development. In production, the key would be stored in and retrieved from Keychain. |
| Widget | Widget extension target is created with correct bundle structure. Contains boilerplate widget + Live Activity widget. Not customized with recording-specific controls. |

### Not Implemented

| Feature | Reason |
|---|---|
| Search/filter on session list | Time constraint — would add `.searchable()` modifier with text filtering |
| Sessions grouped by date | Time constraint — would use `Dictionary(grouping:)` on session dates |
| Pull-to-refresh / pagination | Time constraint — would add `.refreshable {}` and limit fetch with `fetchLimit` |
| Accessibility (VoiceOver) | Time constraint — would add `.accessibilityLabel()` and `.accessibilityHint()` to all elements |
| Data encryption at rest | Time constraint — would use CommonCrypto AES-256 to encrypt audio files |
| Unit / Integration tests | Time constraint — test targets exist but test cases are not written |
| App termination recovery | Time constraint — would use UserDefaults flags to detect incomplete sessions |

## Architecture

### Actor-Based Concurrency

The app uses three core actors to ensure thread-safe access to shared mutable state. All concurrent systems use Swift Concurrency (async/await).

**AudioRecordingActor** — Owns all audio recording state.
- Manages AVAudioEngine lifecycle (start, stop, pause, rebuild)
- Handles audio session configuration with proper category and options
- Listens for route change and interruption notifications
- Controls 30-second segment creation by swapping audio files
- Computes real-time audio levels from buffer data
- Coordinates with TranscriptionActor for live transcription

**TranscriptionActor** — Manages all transcription operations.
- Sends audio segments to OpenAI Whisper API as multipart requests
- Implements retry with exponential backoff (5 retries max)
- Tracks consecutive failures and switches to Apple Speech after 5
- Maintains offline queue for segments recorded without network
- Auto-processes queued segments when connectivity returns

**DataManagerActor** — Wraps all SwiftData operations.
- Single point of access for all database reads and writes
- Creates and manages RecordingSession, AudioSegment, Transcription records
- Handles relationship management and cascade operations
- Provides thread-safe context management

**RecordingCoordinator** — Shared state between UI and Siri intents.
- Singleton that both RecordingView and App Intents use
- Sets up all actors and their dependencies
- Provides simple startRecording/stopRecording interface

### Data Flow

```
User taps Record (or Siri Intent)
       |
       v
RecordingCoordinator
       |
       v
AudioRecordingActor (configures session, starts AVAudioEngine)
       |
       |  continuous tap writes to file
       |  every 30 seconds: swap file
       |
       v
stopCurrentSegment()
       |
       |---> DataManagerActor (saves segment to SwiftData)
       |
       |---> TranscriptionActor
                |
                |-- Online? --> Whisper API --> DataManagerActor (save transcription)
                |
                |-- Offline? --> Queue for later
                |
                |-- 5+ failures? --> Apple Speech (local) --> DataManagerActor
```

## Audio System Design

### Key Design Decision: No-Gap Segmentation

The most important audio design decision was how to handle 30-second segmentation. The naive approach of removing the tap, creating a new file, and reinstalling the tap causes a 50-200ms gap where audio is lost. Instead, the app installs the tap once and keeps it running for the entire recording session. Every 30 seconds, only the AVAudioFile reference is swapped to a new file. The tap closure captures `self?.audioFile` weakly, so it automatically writes to whichever file is current. Zero audio loss.

### Route Change Format Handling

A common crash in audio apps: Bluetooth devices use 16kHz sample rate while iPhone mic uses 48kHz. If the tap format doesn't match the hardware format, AVAudioEngine throws "Input HW format and tap format not matching" and crashes. The app handles this by reading `inputNode.inputFormat(forBus: 0)` fresh after every route change and rebuilding the tap with the correct sample rate.

### Audio Session Configuration

Category: `.playAndRecord` with options `.defaultToSpeaker` and `.allowBluetoothHFP`. This ensures audio plays from the main speaker (not earpiece) and supports Bluetooth HFP devices for both input and output.

## Data Model Design

### SwiftData Schema

**RecordingSession** has many **AudioSegments**, each has one **Transcription**.

- Cascade delete: deleting a session removes all its segments and their transcriptions
- `isRecording` flag: active sessions are filtered out of the session list query
- Sessions sorted by date descending for display

Audio files (.wav) are stored in the Documents directory. SwiftData stores the file path (metadata), not the audio data itself. This keeps the database lightweight.

## Transcription System

### Whisper API Integration

Segments are uploaded as WAV files via multipart/form-data POST to OpenAI's transcription endpoint. The `language` parameter is set to `en` to reduce Whisper's tendency to hallucinate text in other languages on silent segments.

### Retry Strategy

Retry 1: 1s delay, Retry 2: 2s delay, Retry 3: 4s delay, Retry 4: 8s delay, Retry 5: 16s delay. After all retries exhausted, the segment is marked as failed. After 5 consecutive failures across segments, the system switches to Apple's local SFSpeechRecognizer.

### Known Whisper Quirk

On segments with mostly silence or background noise, Whisper sometimes generates phantom text. Setting `language: "en"` reduces this but doesn't eliminate it entirely.

## Project Structure

```
TwinMind_Audio_Recorder/
├── Actors/
│   ├── AudioRecordingActor.swift    — Audio engine, recording, route handling
│   ├── DataManagerActor.swift       — SwiftData CRUD operations
│   └── TranscriptionActor.swift     — Whisper API, retry, local fallback
├── Models/
│   └── Models.swift                 — SwiftData models
├── Views/
│   ├── ContentView.swift            — Tab bar (Record / My Recordings)
│   ├── RecordingView.swift          — Recording UI with waveform
│   ├── SessionListView.swift        — List of completed recordings
│   └── SessionDetailView.swift      — Session details with transcription
├── Utilities/
│   ├── KeychainManager.swift        — Secure key storage
│   ├── LiveActivityManager.swift    — Live Activity lifecycle
│   ├── NetworkMonitor.swift         — Network connectivity observer
│   ├── RecordingAttributes.swift    — Shared ActivityKit model
│   ├── RecordingCoordinator.swift   — Shared state for UI + Siri
│   └── RecordingIntents.swift       — AppIntents for Siri and Shortcuts
├── App Files/
│   └── TwinMind_Audio_RecorderApp.swift
└── RecorderWidgetExtension/
    ├── RecorderWidgetExtensionBundle.swift
    ├── RecorderWidgetExtensionLiveActivity.swift
    └── Supporting files
```

## Technologies Used

- Swift 5.9+, SwiftUI, Swift Concurrency (async/await, Actors)
- AVFoundation (AVAudioEngine, AVAudioSession, AVAudioFile)
- SwiftData (persistence with @Model, relationships, FetchDescriptor)
- ActivityKit (Live Activities)
- AppIntents (Siri and Shortcuts integration)
- WidgetKit (Widget Extension)
- Speech Framework (SFSpeechRecognizer for local fallback)
- Network Framework (NWPathMonitor)
- Security Framework (Keychain Services)
- OpenAI Whisper API (remote transcription)

## If I Had More Time

Given additional time, my priority order would be:
1. Wire up Keychain properly and remove hardcoded API key
2. Add unit tests for DataManagerActor and TranscriptionActor retry logic
3. Debug Live Activity display on physical device (test on Dynamic Island device)
4. Add search and date grouping to session list
5. Implement audio file encryption at rest using CommonCrypto
6. Add VoiceOver accessibility labels throughout the app
7. Customize the widget with recording status and quick-start button
8. Add silence detection to skip empty segments before sending to Whisper
9. Implement app termination recovery using UserDefaults flags
10. Add pull-to-refresh and pagination for large session lists
