//
//  ContentView.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State var coordinator = RecordingCoordinator.shared
    
    var body: some View {
        TabView {
            RecordingView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
            
            SessionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("My Recordings")
                }
        }
        .onAppear {
            coordinator.setup(container: context.container)
        }
    }
}

#Preview {
    ContentView()
}
