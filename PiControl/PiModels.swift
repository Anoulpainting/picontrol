import Foundation

enum PiConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)
}

struct DockerContainer: Identifiable {
    let id: String
    let name: String
    let image: String
    let status: String
    var isRunning: Bool { status.lowercased().contains("up") }
}

struct SystemdService: Identifiable {
    let id = UUID()
    let name: String
    var isActive: Bool
    var isEnabled: Bool
}
