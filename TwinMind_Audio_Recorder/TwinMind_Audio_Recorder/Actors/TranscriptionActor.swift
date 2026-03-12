//
//  TranscriptionActor.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import Foundation
import AVFoundation
import Speech

actor TranscriptionActor {
    var dataManager: DataManagerActor?
    var consecutiveFailures = 0
    
    func setDataManager(_ manager: DataManagerActor) {
        self.dataManager = manager
    }
    
    func transcribe(filePath: String, segment: AudioSegment) async {
        let url = getDocumentsDirectory().appendingPathComponent(filePath)
        
        if isAudioSilent(fileURL: url) {
            print("Segment is silent, skipping transcription")
            return
        }
        
        if consecutiveFailures < 5 {
            await transcribeWithAPI(fileURL: url, segment: segment)
        } else {
            await transcribeLocally(fileURL: url, segment: segment)
        }
    }
    
    private func transcribeWithAPI(fileURL: URL, segment: AudioSegment, retryCount: Int = 0) async {
        let maxRetries = 5
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("Cannot read audio file")
            return
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
            
            consecutiveFailures = 0
            await dataManager?.saveTranscription(
                text: response.text,
                method: "api",
                retryCount: retryCount,
                segment: segment
            )
            print("Transcription success: \(response.text)")
            
        } catch {
            print("Transcription failed: \(error)")
            consecutiveFailures += 1
            
            if retryCount < maxRetries {
                let delay = pow(2.0, Double(retryCount))
                try? await Task.sleep(for: .seconds(delay))
                await transcribeWithAPI(fileURL: fileURL, segment: segment, retryCount: retryCount + 1)
            } else {
                print("All retries exhausted")
            }
        }
    }
    
    private func transcribeLocally(fileURL: URL, segment: AudioSegment) async {
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        do {
            let result: String = try await withCheckedThrowingContinuation { continuation in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result, result.isFinal {
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
            
            await dataManager?.saveTranscription(
                text: result,
                method: "local",
                retryCount: 0,
                segment: segment
            )
            print("Local transcription: \(result)")
            
        } catch {
            print("Local transcription failed: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func isAudioSilent(fileURL: URL) -> Bool {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else { return true }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return true }
        
        try? audioFile.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else { return true }
        
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(buffer.frameLength)
        return average < 0.01  // below this = basically silence
    }
}

struct WhisperResponse: Codable {
    let text: String
}
