//
//  RecordingView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    
    @State var isRecording = false
    @State var audioLevel: Float = 0.0
    @State var levelTimer: Timer?
    @State var coordinator = RecordingCoordinator.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(isRecording ? "Recording..." : "Tap to Record")
                .font(.title2)
            
            Text("Audio Level: \(audioLevel, specifier: "%.4f")")
                .font(.caption)
                .opacity(isRecording ? 1 : 0)
            
            Button {
                Task {
                    if !isRecording {
                        await coordinator.startRecording()
                        isRecording = true
                        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            Task {
                                audioLevel = await coordinator.recorder.getAudioLevel()
                            }
                        }
                    } else {
                        _ = await coordinator.stopRecording()
                        isRecording = false
                        levelTimer?.invalidate()
                        levelTimer = nil
                        audioLevel = 0.0
                    }
                }
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.red)
            }
            
            Spacer()
        }
    }
}

#Preview {
    RecordingView()
}
