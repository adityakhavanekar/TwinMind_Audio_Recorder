//
//  RecordingAttributes.swift.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import ActivityKit
import Foundation
import AVFoundation

struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var recordingState: String
        var elapsedTime: Double
        var inputDevice: String
        var segmentsTranscribed: Int
        var totalSegments: Int
        var audioLevel: Float
    }
    
    var sessionName: String
    var startTime: Date
}
