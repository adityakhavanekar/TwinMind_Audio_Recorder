//
//  RecordingCoordinator.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import Foundation
import SwiftData

@MainActor
class RecordingCoordinator {
    static let shared = RecordingCoordinator()
    
    let recorder = AudioRecordingActor()
    let transcriber = TranscriptionActor()
    var dataManager: DataManagerActor?
    
    var isRecording = false
    
    func setup(container: ModelContainer) {
        let manager = DataManagerActor(container: container)
        dataManager = manager
        
        NetworkMonitor.shared.start()
        NetworkMonitor.shared.onStatusChange = { [weak self] online in
            Task {
                await self?.transcriber.setOnlineStatus(online)
            }
        }
        
        Task {
            await recorder.setDataManager(manager)
            await transcriber.setDataManager(manager)
            await recorder.setTranscriptionActor(transcriber)
        }
    }
    
    func startRecording(name: String = "Recording") async {
        await recorder.start()
        isRecording = true
    }
    
    func stopRecording() async -> String {
        let startTime = await recorder.recordingStartTime
        await recorder.stop()
        isRecording = false
        
        if let startTime = startTime {
            let duration = Int(Date().timeIntervalSince(startTime))
            let mins = duration / 60
            let secs = duration % 60
            return String(format: "%02d:%02d", mins, secs)
        }
        return "00:00"
    }
}
