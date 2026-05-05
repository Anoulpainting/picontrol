import Foundation
import Combine

enum AuthMethod: String, Codable, CaseIterable {
    case key      = "key"
    case password = "password"

    var label: String {
        switch self {
        case .key:      return "Clé SSH"
        case .password: return "Mot de passe"
        }
    }
}

struct PiConfig: Codable {
    var host: String            // hôte SSH (peut être domaine externe / tunnel)
    var port: Int               // port SSH
    var apiHost: String         // hôte API HTTP (IP locale, ex: 192.168.1.100)
    var apiPort: Int            // port API HTTP (défaut 34001)
    var username: String
    var authMethod: AuthMethod
    var sshKeyPath: String      // utilisé uniquement si authMethod == .key
    var serviceName: String

    // Hôte effectif pour l'API : apiHost si renseigné, sinon host
    var resolvedApiHost: String {
        let trimmed = apiHost.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? host : trimmed
    }

    init(host: String, port: Int, apiHost: String, apiPort: Int, username: String,
         authMethod: AuthMethod, sshKeyPath: String, serviceName: String) {
        self.host        = host
        self.port        = port
        self.apiHost     = apiHost
        self.apiPort     = apiPort
        self.username    = username
        self.authMethod  = authMethod
        self.sshKeyPath  = sshKeyPath
        self.serviceName = serviceName
    }

    static let `default` = PiConfig(
        host: "",
        port: 22,
        apiHost: "",
        apiPort: 34001,
        username: "",
        authMethod: .password,
        sshKeyPath: "~/.ssh/id_rsa",
        serviceName: "pironman5"
    )

    // Migration rétro-compatible
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host        = try c.decode(String.self,       forKey: .host)
        port        = try c.decode(Int.self,          forKey: .port)
        apiHost     = try c.decodeIfPresent(String.self, forKey: .apiHost) ?? ""
        apiPort     = try c.decodeIfPresent(Int.self, forKey: .apiPort) ?? 34001
        username    = try c.decode(String.self,       forKey: .username)
        authMethod  = try c.decode(AuthMethod.self,   forKey: .authMethod)
        sshKeyPath  = try c.decode(String.self,       forKey: .sshKeyPath)
        serviceName = try c.decode(String.self,       forKey: .serviceName)
    }
}

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var config: PiConfig

    private let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/picontrol")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    private init() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/picontrol/config.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(PiConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = .default
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: configURL)
    }

    // SSH est configuré si un nom d'utilisateur est renseigné
    // et qu'un mot de passe ou une clé est disponible
    var isSSHConfigured: Bool {
        guard !config.resolvedApiHost.isEmpty, !config.username.isEmpty else { return false }
        switch config.authMethod {
        case .password: return KeychainHelper.getPassword() != nil
        case .key:      return !config.sshKeyPath.isEmpty
        }
    }
}
