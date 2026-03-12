//
//  RecordingView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    
    @State var coordinator = RecordingCoordinator.shared
    @State var audioLevel: Float = 0.0
    @State var levelTimer: Timer?

    @Environment(\.modelContext) private var context
    
    var body: some View {
        
        VStack {
            if coordinator.isRecording {
                Text("Audio Level: \(audioLevel, specifier: "%.4f")")
                    .font(.caption)
            }
            
            Button {
                Task {
                    if !coordinator.isRecording {
                        await coordinator.startRecording()
                        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            Task {
                                audioLevel = await coordinator.recorder.getAudioLevel()
                            }
                        }
                    } else {
                        _ = await coordinator.stopRecording()
                        levelTimer?.invalidate()
                        levelTimer = nil
                        audioLevel = 0.0
                    }
                }
            } label: {
                Image(systemName: coordinator.isRecording ? "stop.fill" : "play.fill")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
            
            Button("Play") {
                Task {
                    await coordinator.recorder.play()
                }
            }
        }
        .onAppear {
            coordinator.setup(container: context.container)
        }
    }
}

#Preview {
    RecordingView()
}
