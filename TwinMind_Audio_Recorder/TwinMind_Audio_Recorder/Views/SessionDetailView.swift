//
//  SessionDetailView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: RecordingSession
    
    var body: some View {
        List {
            Section("Session Info") {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(session.date, style: .date)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(formatDuration(session.duration))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Segments")
                    Spacer()
                    Text("\(session.segments.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Transcription") {
                let sortedSegments = session.segments.sorted { $0.segmentIndex < $1.segmentIndex }
                
                if sortedSegments.isEmpty {
                    Text("No segments yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedSegments, id: \.segmentIndex) { segment in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Segment \(segment.segmentIndex + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                            
                            if let transcription = segment.transcription {
                                Text(transcription.text)
                                    .font(.body)
                            } else {
                                Text("Transcribing...")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(session.name)
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

//#Preview{
//    SessionDetailView()
//}
