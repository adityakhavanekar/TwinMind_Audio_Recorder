//
//  RecordingView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    
    @State var isRecording: Bool = false
    @State private var progress = 0.5
    @State var dataManager: DataManagerActor?
    @State var audioLevel: Float = 0.0
    @State var levelTimer: Timer?
    @State var transcriber: TranscriptionActor?

    @Environment(\.modelContext) private var context
    
    let recorder = AudioRecordingActor()
    
    var body: some View {
        
        VStack {
            if isRecording {
                Text("Audio Level: \(audioLevel, specifier: "%.4f")")
                    .font(.caption)
            }
            
            ProgressView(value: progress)
                .padding()
            
            Button {
                Task {
                    if await recorder.isRecording == false {
                        await recorder.start()
                        isRecording = true
                        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            Task {
                                audioLevel = await recorder.getAudioLevel()
                            }
                        }
                    } else {
                        await recorder.stop()
                        isRecording = false
                        levelTimer?.invalidate()
                        levelTimer = nil
                        audioLevel = 0.0
                    }
                }
            } label: {
                Image(systemName: isRecording ? "stop.fill" : "play.fill")
                    .resizable()
                    .frame(width: 25, height: 25)
            }
            
            Button("Play") {
                Task {
                    await recorder.play()
                }
            }
        }
        .onAppear {
            let container = context.container
            let manager = DataManagerActor(container: container)
            let newTranscriber = TranscriptionActor()
            dataManager = manager
            transcriber = newTranscriber
            
            NetworkMonitor.shared.start()
            NetworkMonitor.shared.onStatusChange = { online in
                Task {
                    await newTranscriber.setOnlineStatus(online)
                }
            }
            
            Task {
                await recorder.setDataManager(manager)
                await newTranscriber.setDataManager(manager)
                await recorder.setTranscriptionActor(newTranscriber)
            }
        }
    }
}

#Preview {
    RecordingView()
}
