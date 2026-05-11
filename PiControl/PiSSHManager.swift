import Foundation

class PiSSHManager {
    private var isConnectedFlag = false
    var isConnected: Bool { isConnectedFlag }

    func connect() async -> Bool {
        let result = await run("echo pi_ok")
        isConnectedFlag = result.contains("pi_ok")
        return isConnectedFlag
    }

    func disconnect() {
        isConnectedFlag = false
    }

    func run(_ command: String) async -> String {
        let cfg = ConfigManager.shared.config
        let host = cfg.host
        guard !host.isEmpty, !cfg.username.isEmpty else { return "" }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                switch cfg.authMethod {
                case .password:
                    let password = KeychainHelper.getPassword() ?? ""
                    let sshpass = "/opt/homebrew/bin/sshpass"
                    if !password.isEmpty && FileManager.default.fileExists(atPath: sshpass) {
                        process.executableURL = URL(fileURLWithPath: sshpass)
                        process.arguments = [
                            "-p", password, "ssh",
                            "-o", "StrictHostKeyChecking=no",
                            "-o", "ConnectTimeout=8",
                            "-p", "\(cfg.port)",
                            "\(cfg.username)@\(host)", command
                        ]
                    } else {
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                        process.arguments = [
                            "-o", "StrictHostKeyChecking=no",
                            "-o", "ConnectTimeout=8",
                            "-p", "\(cfg.port)",
                            "\(cfg.username)@\(host)", command
                        ]
                    }

                case .key:
                    let rawKey = cfg.sshKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = (rawKey.isEmpty ? "~/.ssh/id_rsa" : rawKey as NSString).expandingTildeInPath
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                    process.arguments = [
                        "-i", key,
                        "-o", "StrictHostKeyChecking=no",
                        "-o", "ConnectTimeout=8",
                        "-p", "\(cfg.port)",
                        "\(cfg.username)@\(host)", command
                    ]
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    func scpUpload(localURL: URL, remotePath: String) async -> Bool {
        let cfg = ConfigManager.shared.config
        let host = cfg.host
        guard !host.isEmpty else { return false }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                let sshpass = "/opt/homebrew/bin/sshpass"

                switch cfg.authMethod {
                case .password:
                    let password = KeychainHelper.getPassword() ?? ""
                    if !password.isEmpty && FileManager.default.fileExists(atPath: sshpass) {
                        process.executableURL = URL(fileURLWithPath: sshpass)
                        process.arguments = [
                            "-p", password, "scp",
                            "-o", "StrictHostKeyChecking=no",
                            "-P", "\(cfg.port)",
                            localURL.path,
                            "\(cfg.username)@\(host):\(remotePath)/"
                        ]
                    } else {
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
                        process.arguments = [
                            "-o", "StrictHostKeyChecking=no",
                            "-P", "\(cfg.port)",
                            localURL.path,
                            "\(cfg.username)@\(host):\(remotePath)/"
                        ]
                    }
                case .key:
                    let scpKey = (cfg.sshKeyPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
                    process.arguments = [
                        "-i", scpKey,
                        "-o", "StrictHostKeyChecking=no",
                        "-P", "\(cfg.port)",
                        localURL.path,
                        "\(cfg.username)@\(host):\(remotePath)/"
                    ]
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func scpDownload(remotePath: String, localURL: URL) async -> Bool {
        let cfg = ConfigManager.shared.config
        let host = cfg.host
        guard !host.isEmpty else { return false }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                let sshpass = "/opt/homebrew/bin/sshpass"

                switch cfg.authMethod {
                case .password:
                    let password = KeychainHelper.getPassword() ?? ""
                    if !password.isEmpty && FileManager.default.fileExists(atPath: sshpass) {
                        process.executableURL = URL(fileURLWithPath: sshpass)
                        process.arguments = [
                            "-p", password, "scp",
                            "-o", "StrictHostKeyChecking=no",
                            "-P", "\(cfg.port)",
                            "\(cfg.username)@\(host):\(remotePath)",
                            localURL.path
                        ]
                    } else {
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
                        process.arguments = [
                            "-o", "StrictHostKeyChecking=no",
                            "-P", "\(cfg.port)",
                            "\(cfg.username)@\(host):\(remotePath)",
                            localURL.path
                        ]
                    }
                case .key:
                    let dlKey = (cfg.sshKeyPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
                    process.arguments = [
                        "-i", dlKey,
                        "-o", "StrictHostKeyChecking=no",
                        "-P", "\(cfg.port)",
                        "\(cfg.username)@\(host):\(remotePath)",
                        localURL.path
                    ]
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
