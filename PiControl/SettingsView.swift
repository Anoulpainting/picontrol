import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void = {}

    @ObservedObject private var cfg   = ConfigManager.shared
    @ObservedObject private var state = CommandState.shared

    @State private var password      = ""
    @State private var passwordSaved  = false
    @State private var editingPassword = false
    @State private var testStatus: String? = nil
    @State private var isTesting    = false

    private var accent: Color { Color(hue: state.currentHue, saturation: 1, brightness: 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text("Connexion")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 2)

            // ── API ──────────────────────────────────────────────
            card {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("API Pironman5")
                    row("IP locale") {
                        field("192.168.1.100", text: $cfg.config.apiHost)
                    }
                    row("Port API") {
                        numberField("34001", value: $cfg.config.apiPort)
                            .frame(width: 80)
                        Spacer()
                    }
                }
            }

            // ── SSH ──────────────────────────────────────────────
            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        sectionLabel("SSH")
                        Text("optionnel — reboot & restart service")
                            .font(.system(size: 10))
                            .foregroundColor(dimText.opacity(0.65))
                    }
                    row("Port SSH") {
                        numberField("22", value: $cfg.config.port)
                            .frame(width: 80)
                        Spacer()
                    }
                    row("Utilisateur") {
                        field("pi", text: $cfg.config.username)
                    }
                    row("Auth") {
                        Picker("", selection: $cfg.config.authMethod) {
                            ForEach(AuthMethod.allCases, id: \.self) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(accent)
                    }
                    if cfg.config.authMethod == .key {
                        row("Clé SSH") {
                            field("~/.ssh/id_rsa", text: $cfg.config.sshKeyPath)
                            Button { pickKeyFile() } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                    .foregroundColor(dimText)
                                    .padding(7)
                                    .background(bgPrimary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if cfg.config.authMethod == .password {
                        row("Mot de passe") {
                            if passwordSaved && !editingPassword {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.3))
                                        .font(.system(size: 12))
                                    Text("Mot de passe enregistré")
                                        .font(.system(size: 12))
                                        .foregroundColor(dimText)
                                    Spacer()
                                    Button("Modifier") { editingPassword = true }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11))
                                        .foregroundColor(dimText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(5)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(red: 0.06, green: 0.08, blue: 0.15))
                                        .overlay(RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1))
                                )
                            } else {
                                SecureField("Nouveau mot de passe", text: $password)
                                    .styledSettingsField()
                            }
                        }
                    }
                    row("Service") {
                        field("pironman5", text: $cfg.config.serviceName)
                    }
                }
            }

            // ── Test SSH ─────────────────────────────────────────
            HStack(spacing: 10) {
                Button { testConnection() } label: {
                    HStack(spacing: 6) {
                        if isTesting { ProgressView().scaleEffect(0.7) }
                        Text("Tester SSH")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isTesting)

                if let status = testStatus {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(
                            status.hasPrefix("OK")
                                ? Color(red: 0.2, green: 0.85, blue: 0.3)
                                : Color(red: 0.95, green: 0.25, blue: 0.25)
                        )
                }
            }

            Divider().background(Color.white.opacity(0.08))

            // ── Footer ────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Annuler") { onClose() }
                    .keyboardShortcut(.escape)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .buttonStyle(.plain)

                Button("Enregistrer") { save() }
                    .keyboardShortcut(.return)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(accent)
                    .cornerRadius(8)
                    .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(width: 400)
        .background(bgPrimary)
        .environment(\.colorScheme, .dark)
        .onAppear {
            passwordSaved = KeychainHelper.getPassword() != nil
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(bgCard)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(dimText)
                .frame(width: 90, alignment: .trailing)
            content()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(dimText)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .styledSettingsField()
    }

    private func numberField(_ placeholder: String, value: Binding<Int>) -> some View {
        TextField(placeholder, value: value, format: .number)
            .styledSettingsField()
    }

    // MARK: - Actions

    private func save() {
        cfg.save()
        if cfg.config.authMethod == .password && !password.isEmpty {
            KeychainHelper.savePassword(password)
            passwordSaved = true
            editingPassword = false
        }
        if cfg.isSSHConfigured {
            Task { await RaspberryPiManager.shared.connect() }
        }
        onClose()
    }

    private func testConnection() {
        if cfg.config.authMethod == .password && !password.isEmpty {
            KeychainHelper.savePassword(password)
        }
        isTesting = true
        testStatus = nil
        SSHManager.shared.testConnection { result in
            isTesting = false
            switch result {
            case .success:          testStatus = "OK — connexion établie"
            case .failure(let err): testStatus = err.localizedDescription
            }
        }
    }

    private func pickKeyFile() {
        let panel = NSOpenPanel()
        panel.title = "Sélectionner la clé SSH"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            cfg.config.sshKeyPath = url.path
        }
    }
}

private extension View {
    func styledSettingsField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.06, green: 0.08, blue: 0.15))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
    }
}
