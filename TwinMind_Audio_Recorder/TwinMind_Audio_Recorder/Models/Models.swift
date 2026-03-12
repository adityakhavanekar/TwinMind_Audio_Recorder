//
//  Models.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//
import SwiftUI
import SwiftData
import Foundation

@Model
class RecordingSession {
    var name: String
    var date: Date
    var duration: Double
    var isRecording: Bool
    @Relationship(deleteRule: .cascade) var segments: [AudioSegment]
    
    init(name: String, date: Date = Date(), duration: Double = 0, isRecording: Bool = false) {
        self.name = name
        self.date = date
        self.duration = duration
        self.isRecording = isRecording
        self.segments = []
    }
}

@Model
class AudioSegment {
    var filePath: String
    var startTime: Double
    var duration: Double
    var segmentIndex: Int
    var session: RecordingSession?
    @Relationship(deleteRule: .cascade) var transcription: Transcription?
    
    init(filePath: String, startTime: Double, duration: Double, segmentIndex: Int, session: RecordingSession? = nil) {
        self.filePath = filePath
        self.startTime = startTime
        self.duration = duration
        self.segmentIndex = segmentIndex
        self.session = session
    }
}

@Model
class Transcription {
    var text: String
    var date: Date
    var isSuccess: Bool
    var retryCount: Int
    var method: String  // "api" or "local"
    var segment: AudioSegment?
    
    init(text: String, date: Date = Date(), isSuccess: Bool = true, retryCount: Int = 0, method: String = "api", segment: AudioSegment? = nil) {
        self.text = text
        self.date = date
        self.isSuccess = isSuccess
        self.retryCount = retryCount
        self.method = method
        self.segment = segment
    }
}
