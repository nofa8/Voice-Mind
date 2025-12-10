// FirstApp/Utilities/NetworkMonitor.swift
import Foundation
import Network

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // 1. Capture self weakly to avoid memory leaks
            // 2. Dispatch to Main Thread because 'isConnected' updates the UI
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}