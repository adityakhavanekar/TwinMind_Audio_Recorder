//
//  RecorderWidgetExtensionLiveActivity.swift
//  RecorderWidgetExtension
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RecorderWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            // Lock Screen - super simple
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                Text("Recording...")
                Spacer()
                Text("\(Int(context.state.elapsedTime))s")
            }
            .padding()
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Recording")
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
            } compactTrailing: {
                Text("REC")
            } minimal: {
                Image(systemName: "mic.fill")
            }
        }
    }
}
