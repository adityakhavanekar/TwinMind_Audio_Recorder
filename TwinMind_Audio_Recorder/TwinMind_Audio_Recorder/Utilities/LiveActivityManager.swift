//
//  LiveActivityManager.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import ActivityKit
import Foundation
import AVFoundation

class LiveActivityManager {
    static let shared = LiveActivityManager()
    var currentActivity: Activity<RecordingAttributes>?
    
    func startActivity(sessionName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        let attributes = RecordingAttributes(
            sessionName: sessionName,
            startTime: Date()
        )
        
        let state = RecordingAttributes.ContentState(
            recordingState: "Recording",
            elapsedTime: 0,
            inputDevice: getCurrentInputDevice(),
            segmentsTranscribed: 0,
            totalSegments: 0,
            audioLevel: 0
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("Live Activity started with ID: \(currentActivity?.id ?? "none")")
            print("Activity state: \(currentActivity?.activityState ?? .dismissed)")
            
            // Print all active activities
            for activity in Activity<RecordingAttributes>.activities {
                print("Found activity: \(activity.id), state: \(activity.activityState)")
            }
        } catch {
            print("Live Activity failed: \(error)")
        }
    }
    
    func updateActivity(
        recordingState: String,
        elapsedTime: Double,
        segmentsTranscribed: Int,
        totalSegments: Int,
        audioLevel: Float
    ) {
        let state = RecordingAttributes.ContentState(
            recordingState: recordingState,
            elapsedTime: elapsedTime,
            inputDevice: getCurrentInputDevice(),
            segmentsTranscribed: segmentsTranscribed,
            totalSegments: totalSegments,
            audioLevel: audioLevel
        )
        
        Task {
            await currentActivity?.update(.init(state: state, staleDate: nil))
        }
    }
    
    func stopActivity() {
        Task {
            let state = RecordingAttributes.ContentState(
                recordingState: "Stopped",
                elapsedTime: 0,
                inputDevice: "",
                segmentsTranscribed: 0,
                totalSegments: 0,
                audioLevel: 0
            )
            await currentActivity?.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
            print("Live Activity stopped")
        }
    }
    
    private func getCurrentInputDevice() -> String {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.inputs.first?.portName ?? "iPhone Microphone"
    }
}
