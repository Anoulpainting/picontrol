import Foundation

@MainActor
class RaspberryPiManager: ObservableObject {
    static let shared = RaspberryPiManager()

    @Published var connectionState: PiConnectionState = .disconnected
    @Published var containers: [DockerContainer] = []
    @Published var services: [SystemdService] = []
    @Published var commandOutput: String = ""
    @Published var isLoadingContainers = false
    @Published var isLoadingServices = false

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    // MARK: - Connection (reuses SSHManager — même config, même mécanisme)

    func connect() async {
        guard ConfigManager.shared.isSSHConfigured else {
            connectionState = .error("SSH non configuré")
            return
        }
        connectionState = .connecting
        let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SSHManager.shared.run(command: "echo ok") { result in
                switch result {
                case .success: cont.resume(returning: true)
                case .failure: cont.resume(returning: false)
                }
            }
        }
        if ok {
            connectionState = .connected
            await refreshAll()
        } else {
            connectionState = .error("Connexion impossible · \(ConfigManager.shared.config.resolvedApiHost)")
        }
    }

    func disconnect() {
        connectionState = .disconnected
        containers = []
        services = []
        commandOutput = ""
    }

    func refreshAll() async {
        await fetchContainers()
        await fetchServices()
    }

    // MARK: - Core SSH (délègue à SSHManager.shared — expect, clé, même auth)

    @discardableResult
    func ssh(_ command: String) async -> String {
        await withCheckedContinuation { cont in
            SSHManager.shared.run(command: command) { result in
                switch result {
                case .success(let out): cont.resume(returning: out)
                case .failure:         cont.resume(returning: "")
                }
            }
        }
    }

    // MARK: - Docker

    func fetchContainers() async {
        isLoadingContainers = true
        let out = await ssh("docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null")
        containers = clean(out).components(separatedBy: "\n").compactMap { line in
            let p = line.components(separatedBy: "|")
            guard p.count >= 4,
                  !p[0].contains("{{"),
                  !p[1].contains("{{") else { return nil }
            return DockerContainer(id: p[0], name: p[1], image: p[2],
                                   status: p[3...].joined(separator: "|"))
        }
        isLoadingContainers = false
    }

    func startContainer(_ c: DockerContainer) async {
        await ssh("docker start \(c.id)")
        await fetchContainers()
    }

    func stopContainer(_ c: DockerContainer) async {
        await ssh("docker stop \(c.id)")
        await fetchContainers()
    }

    // MARK: - Systemd

    func fetchServices() async {
        isLoadingServices = true
        let out = await ssh("systemctl list-units --type=service --no-pager --no-legend --all | head -40")
        services = clean(out).components(separatedBy: "\n").compactMap { line in
            let p = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard p.count >= 3 else { return nil }
            let name = p[0].replacingOccurrences(of: ".service", with: "")
            return SystemdService(name: name, isActive: p[2] == "active", isEnabled: p[1] == "enabled")
        }
        isLoadingServices = false
    }

    func startService(_ s: SystemdService) async   { await ssh("sudo systemctl start \(s.name)");   await fetchServices() }
    func stopService(_ s: SystemdService) async    { await ssh("sudo systemctl stop \(s.name)");    await fetchServices() }
    func restartService(_ s: SystemdService) async { await ssh("sudo systemctl restart \(s.name)"); await fetchServices() }

    // MARK: - Terminal

    func runCommand(_ cmd: String) async {
        commandOutput = await ssh(cmd)
    }

    // MARK: - Files

    func listDirectory(_ path: String) async -> String {
        clean(await ssh("ls -la \(path)"))
    }

    // MARK: - Output cleaning

    private func clean(_ s: String) -> String {
        let noANSI = s.replacingOccurrences(of: "\\x1B\\[[0-9;]*[a-zA-Z]",
                                             with: "", options: .regularExpression)
        return noANSI.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .init(charactersIn: "\r")) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
