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
    @State var audioLevels: [Float] = Array(repeating: 0, count: 30)
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(isRecording ? "Recording..." : "Tap to Record")
                .font(.title2)
            
            // Waveform
            HStack(spacing: 3) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isRecording ? Color.red : Color.gray.opacity(0.3))
                        .frame(width: 6, height: CGFloat(audioLevels[index]) * 200 + 4)
                        .animation(.easeOut(duration: 0.1), value: audioLevels[index])
                }
            }
            .frame(height: 100)
            
            Button {
                Task {
                    if !isRecording {
                        await coordinator.startRecording()
                        isRecording = true
                        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            Task { @MainActor in
                                audioLevel = await coordinator.recorder.getAudioLevel()
                                if audioLevels.count >= 30 {
                                    audioLevels.removeFirst()
                                }
                                audioLevels.append(audioLevel)
                            }
                        }
                    } else {
                        _ = await coordinator.stopRecording()
                        isRecording = false
                        levelTimer?.invalidate()
                        levelTimer = nil
                        audioLevel = 0.0
                        audioLevels = Array(repeating: 0, count: 30)
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
