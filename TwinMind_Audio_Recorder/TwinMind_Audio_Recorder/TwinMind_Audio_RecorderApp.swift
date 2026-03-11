//
//  TwinMind_Audio_RecorderApp.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import SwiftUI
import CoreData

@main
struct TwinMind_Audio_RecorderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
