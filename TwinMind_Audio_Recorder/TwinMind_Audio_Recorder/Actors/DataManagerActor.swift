//
//  DataManagerActor.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import Foundation
import SwiftData

actor DataManagerActor {
    private var context: ModelContext
    
    init(container: ModelContainer) {
        self.context = ModelContext(container)
    }
    
    
    func createSession(name: String) -> RecordingSession {
        let session = RecordingSession(name: name)
        context.insert(session)
        try? context.save()
        return session
    }
    
    func updateSessionDuration(_ session: RecordingSession, duration: Double) {
        session.duration = duration
        session.isRecording = false
        try? context.save()
    }
    
    func fetchSessions() -> [RecordingSession] {
        let descriptor = FetchDescriptor<RecordingSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func deleteSession(_ session: RecordingSession) {
        context.delete(session)
        try? context.save()
    }
    
    
    func createSegment(filePath: String, startTime: Double, duration: Double, segmentIndex: Int, session: RecordingSession) -> AudioSegment {
        let segment = AudioSegment(
            filePath: filePath,
            startTime: startTime,
            duration: duration,
            segmentIndex: segmentIndex,
            session: session
        )
        session.segments.append(segment)
        context.insert(segment)
        try? context.save()
        return segment
    }
    
    
    func saveTranscription(text: String, method: String, retryCount: Int, segment: AudioSegment) {
        let transcription = Transcription(
            text: text,
            retryCount: retryCount,
            method: method,
            segment: segment
        )
        segment.transcription = transcription
        context.insert(transcription)
        try? context.save()
    }
}
