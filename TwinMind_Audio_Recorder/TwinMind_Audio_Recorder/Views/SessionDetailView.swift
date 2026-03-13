//
//  SessionDetailView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: RecordingSession
    @Environment(\.modelContext) private var context
    @State var refreshTimer: Timer?
    @State var segments: [AudioSegment] = []
    
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
                    Text("\(segments.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Transcription") {
                if segments.isEmpty {
                    Text("No segments yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(segments.sorted { $0.segmentIndex < $1.segmentIndex }, id: \.segmentIndex) { segment in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Segment \(segment.segmentIndex + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                            
                            if let transcription = segment.transcription {
                                Text(transcription.text)
                                    .font(.body)
                            } else {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Transcribing...")
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(session.name)
        .onAppear {
            loadSegments()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                loadSegments()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    func loadSegments() {
        do {
            try context.save()
            let sessionName = session.name
            let descriptor = FetchDescriptor<AudioSegment>()
            let allSegments = try context.fetch(descriptor)
            segments = allSegments.filter { $0.session?.name == sessionName }
        } catch {
            print("Failed to fetch segments: \(error)")
        }
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
