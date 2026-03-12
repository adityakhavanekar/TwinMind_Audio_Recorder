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

enum AudioQuality {
    case low
    case medium
    case high
    
    var bitDepth: Int {
        switch self {
        case .low: return 16
        case .medium: return 16
        case .high: return 24
        }
    }
    
    var format: AVAudioCommonFormat {
        switch self {
        case .low: return .pcmFormatInt16
        case .medium: return .pcmFormatFloat32
        case .high: return .pcmFormatFloat32
        }
    }
}

actor AudioRecordingActor {
    var isRecording = false
    let engine = AVAudioEngine()
    var audioFile: AVAudioFile?
    var player: AVAudioPlayer?
    var dataManager: DataManagerActor?
    var currentSession: RecordingSession?
    var transcriptionActor: TranscriptionActor?
    var audioQuality: AudioQuality = .medium
    var currentAudioLevel: Float = 0.0
    var segmentsTranscribed = 0
    
    var segmentIndex = 0
    var segmentStartTime: Double = 0
    var recordingStartTime: Date?
    var segmentTimer: Task<Void, Never>?
    
    func setDataManager(_ manager: DataManagerActor) {
        self.dataManager = manager
    }
    
    func setTranscriptionActor(_ actor: TranscriptionActor) {
        self.transcriptionActor = actor
    }
    
    func setAudioQuality(_ quality: AudioQuality) {
        self.audioQuality = quality
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
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task { await self?.handleInterruption(notification) }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task { await self?.handleRouteChange(notification) }
        }
    }
    
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            print("Interruption began")
            engine.pause()
            
            // Update Live Activity
            if let startTime = recordingStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                LiveActivityManager.shared.updateActivity(
                    recordingState: "Interrupted",
                    elapsedTime: elapsed,
                    segmentsTranscribed: segmentsTranscribed,
                    totalSegments: segmentIndex,
                    audioLevel: 0
                )
            }
            
        case .ended:
            print("Interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                try? engine.start()
                print("Recording resumed after interruption")
                
                // Update Live Activity
                if let startTime = recordingStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    LiveActivityManager.shared.updateActivity(
                        recordingState: "Recording",
                        elapsedTime: elapsed,
                        segmentsTranscribed: segmentsTranscribed,
                        totalSegments: segmentIndex,
                        audioLevel: currentAudioLevel
                    )
                }
            }
            
        @unknown default:
            break
        }
    }
    
    func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable:
            print("Audio route changed: \(reason.rawValue)")
            if isRecording {
                rebuildTap()
            }
            
        default:
            break
        }
    }
    
    private func rebuildTap() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        
        let hardwareFormat = engine.inputNode.inputFormat(forBus: 0)
        
        guard let commonFormat = AVAudioFormat(
            commonFormat: audioQuality.format,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        stopCurrentSegment()
        createNewAudioFile(format: commonFormat)
        
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: commonFormat) { [weak self] buffer, time in
            try? self?.audioFile?.write(from: buffer)
            self?.updateAudioLevel(buffer: buffer)
        }
        
        try? engine.start()
        print("Recording resumed with new route")
    }
    
    func start() async {
        configureAudioSession()
        setupNotifications()
        
        currentSession = await dataManager?.createSession(name: "Recording \(Date())")
        segmentIndex = 0
        segmentStartTime = 0
        segmentsTranscribed = 0
        recordingStartTime = Date()
        
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        
        guard let commonFormat = AVAudioFormat(
            commonFormat: audioQuality.format,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        createNewAudioFile(format: commonFormat)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: commonFormat) { [weak self] buffer, time in
            try? self?.audioFile?.write(from: buffer)
            self?.updateAudioLevel(buffer: buffer)
        }
        
        try? engine.start()
        isRecording = true
        
        // Start Live Activity
        LiveActivityManager.shared.startActivity(sessionName: "Recording \(Date())")
        
        segmentTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if isRecording {
                    stopCurrentSegment()
                    createNewAudioFile(format: commonFormat)
                }
            }
        }
    }
    
    func stop() async {
        segmentTimer?.cancel()
        segmentTimer = nil
        stopCurrentSegment()
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        currentAudioLevel = 0.0
        
        // Stop Live Activity
        LiveActivityManager.shared.stopActivity()
        
        if let session = currentSession, let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            await dataManager?.updateSessionDuration(session, duration: duration)
        }
    }
    
    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frames {
            sum += abs(channelData[i])
        }
        
        currentAudioLevel = sum / Float(frames)
    }
    
    func getAudioLevel() -> Float {
        return currentAudioLevel
    }
    
    private func createNewAudioFile(format: AVAudioFormat) {
        let fileName = "segment_\(segmentIndex).wav"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        audioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        print("Started segment \(segmentIndex)")
    }
    
    private func stopCurrentSegment() {
        guard let session = currentSession else { return }
        
        let filePath = "segment_\(segmentIndex).wav"
        
        Task {
            if let segment = await dataManager?.createSegment(
                filePath: filePath,
                startTime: segmentStartTime,
                duration: 30,
                segmentIndex: segmentIndex,
                session: session
            ) {
                await transcriptionActor?.transcribe(filePath: filePath, segment: segment)
                segmentsTranscribed += 1
            }
        }
        
        // Update Live Activity
        if let startTime = recordingStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            LiveActivityManager.shared.updateActivity(
                recordingState: "Recording",
                elapsedTime: elapsed,
                segmentsTranscribed: segmentsTranscribed,
                totalSegments: segmentIndex + 1,
                audioLevel: currentAudioLevel
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
