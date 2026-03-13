//
//  TwinMind_Audio_RecorderApp.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI
import CoreData
import SwiftData

@main
struct TwinMind_Audio_RecorderApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }.modelContainer(for: [RecordingSession.self, AudioSegment.self, Transcription.self])
    }
}
