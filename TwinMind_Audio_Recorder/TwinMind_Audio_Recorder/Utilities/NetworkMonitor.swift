//
//  NetworkMonitor.swift
//  TwinMind_Audio_Recorder
//
//  Created by Aditya Khavanekar on 3/12/26.
//

import Network
import Foundation

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    var isOnline = true
    var onStatusChange: ((Bool) -> Void)?
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            self?.isOnline = online
            self?.onStatusChange?(online)
            print("Network: \(online ? "online" : "offline")")
        }
        monitor.start(queue: DispatchQueue.global())
    }
}
