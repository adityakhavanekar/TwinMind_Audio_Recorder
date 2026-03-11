//
//  RecordingView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI

struct RecordingView: View {
    
    @State var isRecording: Bool = false
    @State private var progress = 0.5
    let recorder = AudioRecordingActor()
    
    var body: some View {
        
        VStack{
            ProgressView(value: progress)
                .padding()
            Button {
                Task {
                    if await recorder.isRecording == false {
                        await recorder.start()
                        isRecording = true
                    } else {
                        await recorder.stop()
                        isRecording = false
                    }
                    print(await recorder.isRecording)
                }
            } label: {
                Image(systemName: isRecording ? "stop.fill" : "play.fill")
                    .resizable()
                    .frame(width: 25,height: 25)
            }
            
            Button("Play") {
                Task {
                    await recorder.play()
                }
            }
        }
    }
}

#Preview {
    RecordingView()
}
