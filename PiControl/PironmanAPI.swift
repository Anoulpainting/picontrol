import Foundation

enum APIError: LocalizedError {
    case badURL
    case httpError(Int)
    case noData
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .badURL:                 return "URL invalide"
        case .httpError(let code):    return "Erreur HTTP \(code)"
        case .noData:                 return "Pas de données reçues"
        case .decodingError(let msg): return "Erreur décodage : \(msg)"
        }
    }
}

class PironmanAPI {
    static let shared = PironmanAPI()
    private init() {}

    private var baseURL: String {
        let cfg = ConfigManager.shared.config
        return "http://\(cfg.resolvedApiHost):\(cfg.apiPort)/api/v1.0"
    }

    // key   = clé de config pironman5 (ex: "rgb_color", "oled_enable")
    // value = Bool, Int ou String selon le réglage
    //
    // Règles de transformation vers l'API :
    //   endpoint : "rgb_color"          → /set-rgb-color
    //   body key : "rgb_color"          → "color"   (strip le premier segment + "_")
    //              "fan_mode"           → "fan_mode" (override : clé complète)
    //              "oled_sleep_timeout" → "timeout"  (override : dernier segment)
    //   couleur  : "ff0033"             → "#ff0033" (ajout du #)

    // Overrides explicites clé → bodyKey (cas où l'algo général ne donne pas le bon résultat)
    private let bodyKeyOverrides: [String: String] = [
        "fan_mode":           "fan_mode",
        "oled_sleep_timeout": "timeout",
    ]

    func set(key: String, value: Any, completion: @escaping (Result<Void, Error>) -> Void) {
        let endpoint = key.replacingOccurrences(of: "_", with: "-")
        guard let url = URL(string: "\(baseURL)/set-\(endpoint)") else {
            DispatchQueue.main.async { completion(.failure(APIError.badURL)) }
            return
        }

        // Clé du body : override explicite, sinon strip le premier segment
        let bodyKey: String
        if let override = bodyKeyOverrides[key] {
            bodyKey = override
        } else if let idx = key.firstIndex(of: "_") {
            bodyKey = String(key[key.index(after: idx)...])
        } else {
            bodyKey = key
        }

        // Les couleurs hex doivent avoir un # devant
        var bodyValue: Any = value
        if bodyKey == "color", let hex = value as? String, !hex.hasPrefix("#") {
            bodyValue = "#\(hex)"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        guard let body = try? JSONSerialization.data(withJSONObject: [bodyKey: bodyValue]) else {
            DispatchQueue.main.async { completion(.failure(APIError.badURL)) }
            return
        }
        request.httpBody = body

        log("▶ POST \(url.path) \(String(data: body, encoding: .utf8) ?? "")")

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error { self.log("✗ \(error.localizedDescription)"); completion(.failure(error)); return }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.log("✗ HTTP \(http.statusCode)"); completion(.failure(APIError.httpError(http.statusCode))); return
                }
                self.log("✓ OK")
                completion(.success(()))
            }
        }.resume()
    }

    func fetchConfig(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/get-config") else {
            DispatchQueue.main.async { completion(.failure(APIError.badURL)) }
            return
        }

        log("▶ GET \(url.path)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { self.log("✗ \(error.localizedDescription)"); completion(.failure(error)); return }
                guard let data = data else { completion(.failure(APIError.noData)); return }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let raw = String(data: data, encoding: .utf8) ?? ""
                    self.log("✗ JSON non parseable: \(raw)")
                    completion(.failure(APIError.decodingError(raw)))
                    return
                }
                self.log("✓ config reçue")
                completion(.success(json))
            }
        }.resume()
    }

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[PironmanAPI \(ts)] \(msg)")
    }
}
