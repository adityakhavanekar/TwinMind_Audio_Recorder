//
//  AudioRecordingActor.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import Combine
import SwiftUI
import UIKit
import AVFoundation

actor AudioRecordingActor {
    var isRecording = false
    let engine = AVAudioEngine()
    var audioFile: AVAudioFile?
    var player: AVAudioPlayer?
    var dataManager: DataManagerActor?
    var currentSession: RecordingSession?
    
    var segmentIndex = 0
    var segmentStartTime: Double = 0
    var recordingStartTime: Date?
    var segmentTimer: Task<Void, Never>?
    
    func setDataManager(_ manager: DataManagerActor) {
        self.dataManager = manager
    }
    
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try? session.setActive(true)
    }
    
    func start() async {
        configureAudioSession()
        
        // Create session in SwiftData
        currentSession = await dataManager?.createSession(name: "Recording \(Date())")
        segmentIndex = 0
        segmentStartTime = 0
        recordingStartTime = Date()
        
        startNewSegment()
        
        // Timer to create new segment every 30 seconds
        segmentTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if isRecording {
                    stopCurrentSegment()
                    startNewSegment()
                }
            }
        }
        
        isRecording = true
    }
    
    func stop() async {
        segmentTimer?.cancel()
        segmentTimer = nil
        stopCurrentSegment()
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        
        // Update session duration
        if let session = currentSession, let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            await dataManager?.updateSessionDuration(session, duration: duration)
        }
        
        isRecording = false
    }
    
    private func startNewSegment() {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        let fileName = "segment_\(segmentIndex).wav"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        audioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        
        let file = audioFile
        
        // Remove old tap before installing new one
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            try? file?.write(from: buffer)
        }
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        print("Started segment \(segmentIndex)")
    }
    
    private func stopCurrentSegment() {
        guard let session = currentSession else { return }
        
        let filePath = "segment_\(segmentIndex).wav"
        
        // Save segment to SwiftData
        Task {
            _ = await dataManager?.createSegment(
                filePath: filePath,
                startTime: segmentStartTime,
                duration: 30,
                segmentIndex: segmentIndex,
                session: session
            )
        }
        
        segmentStartTime += 30
        segmentIndex += 1
        audioFile = nil
        print("Stopped segment \(segmentIndex - 1)")
    }
    
    func play() {
        let url = getDocumentsDirectory().appendingPathComponent("segment_0.wav")
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
