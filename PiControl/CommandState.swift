import SwiftUI
import Combine

// Etat global partagé entre les vues
class CommandState: ObservableObject {
    static let shared = CommandState()
    private init() {}

    @Published var isRunning = false
    @Published var lastMessage: StatusMessage? = nil
    @Published var currentHue: Double = 0.6

    struct StatusMessage: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    // Appel HTTP vers l'API pironman5 (pas de SSH, pas de restart)
    func apiSet(key: String, value: Any, label: String = "") {
        guard !isRunning else { return }
        isRunning = true
        lastMessage = nil

        PironmanAPI.shared.set(key: key, value: value) { [weak self] result in
            guard let self else { return }
            self.isRunning = false
            switch result {
            case .success:
                let msg = label.isEmpty ? "OK" : "\(label) : OK"
                self.lastMessage = StatusMessage(text: msg, isError: false)
            case .failure(let err):
                self.lastMessage = StatusMessage(text: err.localizedDescription, isError: true)
            }
        }
    }

    // Commande SSH (reboot, restart service) — SSH doit être configuré
    func send(_ command: String, label: String = "") {
        guard !isRunning else { return }
        isRunning = true
        lastMessage = nil

        SSHManager.shared.run(command: command) { [weak self] result in
            guard let self else { return }
            self.isRunning = false
            switch result {
            case .success(let out):
                let msg = label.isEmpty ? "OK" : "\(label) : OK"
                self.lastMessage = StatusMessage(
                    text: out.isEmpty ? msg : "\(msg) — \(out)",
                    isError: false
                )
            case .failure(let err):
                self.lastMessage = StatusMessage(text: err.localizedDescription, isError: true)
            }
        }
    }
}
