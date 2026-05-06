import Foundation

enum SSHError: LocalizedError {
    case connectionFailed(String)
    case commandFailed(Int32, String)
    case noPassword

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connexion échouée : \(msg)"
        case .commandFailed(let code, let msg): return "Erreur (\(code)) : \(msg)"
        case .noPassword: return "Mot de passe non configuré (Réglages SSH)"
        }
    }
}

class SSHManager {
    static let shared = SSHManager()
    private init() {}

    func run(command: String, completion: @escaping (Result<String, Error>) -> Void) {
        let cfg = ConfigManager.shared.config
        log("▶ run() host=\(cfg.resolvedApiHost) user=\(cfg.username) auth=\(cfg.authMethod.rawValue)")
        log("  commande: \(command)")

        switch cfg.authMethod {
        case .key:
            runWithKey(command: command, cfg: cfg, completion: completion)
        case .password:
            guard let pwd = KeychainHelper.getPassword(), !pwd.isEmpty else {
                log("✗ Pas de mot de passe dans le Keychain")
                DispatchQueue.main.async { completion(.failure(SSHError.noPassword)) }
                return
            }
            log("  mot de passe trouvé dans le Keychain ✓")
            runWithPassword(command: command, password: pwd, cfg: cfg, completion: completion)
        }
    }

    func testConnection(completion: @escaping (Result<String, Error>) -> Void) {
        log("▶ testConnection()")
        run(command: "echo OK", completion: completion)
    }

    // Lecture de la config actuelle du Pi
    func fetchConfig(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        log("▶ fetchConfig()")
        run(command: "sudo pironman5 -c") { [weak self] result in
            switch result {
            case .success(let output):
                self?.log("  config brute: \(output)")
                if let start = output.firstIndex(of: "{"),
                   let end = output.lastIndex(of: "}") {
                    let jsonStr = String(output[start...end])
                    if let data = jsonStr.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self?.log("  config parsée ✓")
                        completion(.success(json))
                        return
                    }
                }
                completion(.failure(SSHError.commandFailed(0, "Config non parseable: \(output)")))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // ── Auth par clé SSH ────────────────────────────────────────

    private func runWithKey(command: String, cfg: PiConfig,
                            completion: @escaping (Result<String, Error>) -> Void) {
        let keyPath = (cfg.sshKeyPath as NSString).expandingTildeInPath
        log("  → auth par clé: \(keyPath)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-T",
            "-i", keyPath,
            "-p", String(cfg.port),
            "-o", "StrictHostKeyChecking=no",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=15",
            "\(cfg.username)@\(cfg.resolvedApiHost)",
            command
        ]
        launch(process: process, completion: completion)
    }

    // ── Auth par mot de passe (via expect) ──────────────────────

    private func runWithPassword(command: String, password: String, cfg: PiConfig,
                                 completion: @escaping (Result<String, Error>) -> Void) {
        // SSH lit ~/.ssh/config → ProxyCommand cloudflared est appliqué automatiquement
        let script = """
set timeout 30
log_user 0
spawn /usr/bin/ssh -T -o ConnectTimeout=15 -o StrictHostKeyChecking=no -p \(cfg.port) \(cfg.username)@\(cfg.resolvedApiHost) \(command.sshEscaped)
expect {
    -re {[Pp]assword[^:]*:} {
        send "$env(SSH_PASS)\\r"
        exp_continue
    }
    timeout {
        puts "EXPECT_TIMEOUT"
        exit 1
    }
    eof
}
puts -nonewline $expect_out(buffer)
"""
        log("  → auth par mot de passe via expect")
        log("  script expect:\n\(script)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
        process.arguments = ["-c", script]

        var env = ProcessInfo.processInfo.environment
        env["SSH_PASS"] = password
        process.environment = env

        launch(process: process, completion: completion)
    }

    // ── Lancement commun ────────────────────────────────────────

    private func launch(process: Process,
                        completion: @escaping (Result<String, Error>) -> Void) {
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError  = stdErr

        process.terminationHandler = { p in
            let out = String(data: stdOut.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let err = String(data: stdErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            self.log("  ← exit code: \(p.terminationStatus)")
            if !out.isEmpty { self.log("  stdout: \(out)") }
            if !err.isEmpty { self.log("  stderr: \(err)") }

            DispatchQueue.main.async {
                if p.terminationStatus == 0 {
                    completion(.success(out))
                } else {
                    let msg = err.isEmpty ? out : err
                    completion(.failure(SSHError.commandFailed(p.terminationStatus, msg)))
                }
            }
        }

        do {
            log("  lancement du processus: \(process.executableURL?.path ?? "?") \(process.arguments ?? [])")
            try process.run()
        } catch {
            log("✗ Impossible de lancer le processus: \(error)")
            DispatchQueue.main.async { completion(.failure(SSHError.connectionFailed(error.localizedDescription))) }
        }
    }

    // ── Logger ──────────────────────────────────────────────────

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[PiControl \(ts)] \(msg)")
    }
}

private extension String {
    var sshEscaped: String { "{" + self + "}" }
}
