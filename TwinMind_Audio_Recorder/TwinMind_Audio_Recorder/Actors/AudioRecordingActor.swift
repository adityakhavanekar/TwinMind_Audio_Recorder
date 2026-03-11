//
//  AudioRecordingActor.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/11/26.
//

import Combine
import SwiftUI
import UIKit
import AVFoundation

actor AudioRecordingActor{
    var isRecording = false
    var engine = AVAudioEngine()
    var audioFile: AVAudioFile?
    var player: AVAudioPlayer?

    func play() {
        let url = getDocumentsDirectory().appendingPathComponent("recording.wav")
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
    
    func start(){
        configureAudioSession()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let file = audioFile
        
        let url = getDocumentsDirectory().appendingPathComponent("recording.wav")
        audioFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            try? file?.write(from: buffer)
        }
        
        try? engine.start()
        isRecording = true
        print("Recording started: \(url.path)")
    }
    
    func stop(){
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try? session.setActive(true)
    }
}
