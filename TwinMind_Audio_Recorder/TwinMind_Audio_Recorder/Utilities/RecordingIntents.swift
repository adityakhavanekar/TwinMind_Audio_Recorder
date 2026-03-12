//
//  RecordingIntents.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import AppIntents
import Foundation

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description: IntentDescription = "Start a new audio recording session"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Session Name", default: "Siri Recording")
    var sessionName: String
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await RecordingCoordinator.shared.startRecording(name: sessionName)
        return .result(dialog: "Recording started: \(sessionName)")
    }
}

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description: IntentDescription = "Stop the current recording session"
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await RecordingCoordinator.shared.stopRecording()
        return .result(dialog: "Recording stopped. Duration: \(summary)")
    }
}

struct RecordingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording with \(.applicationName)",
                "Record audio with \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop recording with \(.applicationName)",
                "Stop \(.applicationName) recording"
            ],
            shortTitle: "Stop Recording",
            systemImageName: "stop.fill"
        )
    }
}
