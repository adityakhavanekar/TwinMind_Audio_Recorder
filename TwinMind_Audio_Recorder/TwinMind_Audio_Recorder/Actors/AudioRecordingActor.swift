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
    var transcriptionActor: TranscriptionActor?
    
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
            
        case .ended:
            print("Interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                try? engine.start()
                print("Recording resumed after interruption")
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
        
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        guard let commonFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        stopCurrentSegment()
        createNewAudioFile(format: commonFormat)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: commonFormat) { [weak self] buffer, time in
            try? self?.audioFile?.write(from: buffer)
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
        recordingStartTime = Date()
        
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        
        guard let commonFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        createNewAudioFile(format: commonFormat)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: commonFormat) { [weak self] buffer, time in
            try? self?.audioFile?.write(from: buffer)
        }
        
        try? engine.start()
        isRecording = true
        
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
        
        if let session = currentSession, let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            await dataManager?.updateSessionDuration(session, duration: duration)
        }
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
            }
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
