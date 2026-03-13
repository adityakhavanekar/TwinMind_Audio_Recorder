//
//  SessionListView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query(sort: \RecordingSession.date, order: .reverse) var sessions: [RecordingSession]
    @Environment(\.modelContext) private var context
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        VStack(alignment: .leading) {
                            Text(session.name)
                                .font(.headline)
                            Text("\(session.segments.count) segments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(sessions[index])
                    }
                    try? context.save()
                }
            }
            .navigationTitle("My Recordings")
            .toolbar {
                EditButton()
            }
        }
    }
}

#Preview {
    SessionListView()
}
