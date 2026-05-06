import SwiftUI

struct PiRaspberryTabView: View {
    @ObservedObject private var pi = RaspberryPiManager.shared
    @State private var subTab = 0

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)

            if !ConfigManager.shared.isSSHConfigured {
                unconfiguredView
            } else {
                subTabBar
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                subContent
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 12))
                .foregroundColor(dimText)
                .lineLimit(1)
            Spacer()
            if case .connecting = pi.connectionState {
                ProgressView().scaleEffect(0.6)
            } else if pi.isConnected {
                Button("Disconnect") {
                    pi.disconnect()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(dimText)
            } else {
                Button("Connect") {
                    Task { await pi.connect() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Sub-tab bar

    private var subTabBar: some View {
        HStack(spacing: 0) {
            ForEach([("Docker", 0), ("Services", 1), ("Terminal", 2), ("Files", 3)], id: \.1) { label, idx in
                Button { withAnimation(.easeInOut(duration: 0.15)) { subTab = idx } } label: {
                    VStack(spacing: 3) {
                        Text(label)
                            .font(.system(size: 11, weight: subTab == idx ? .semibold : .regular))
                            .foregroundColor(subTab == idx ? .white : dimText)
                        Rectangle()
                            .fill(subTab == idx ? Color.white.opacity(0.6) : Color.clear)
                            .frame(height: 1.5)
                            .cornerRadius(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: subTab)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Sub-content

    @ViewBuilder
    private var subContent: some View {
        if pi.isConnected {
            switch subTab {
            case 0: PiDockerSubView().id(0)
            case 1: PiServicesSubView().id(1)
            case 2: PiTerminalSubView().id(2)
            default: PiFilesSubView().id(3)
            }
        } else {
            notConnectedView
        }
    }

    // MARK: - Empty states

    private var notConnectedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 24))
                .foregroundColor(dimText)
            Text("Non connecté")
                .font(.system(size: 13))
                .foregroundColor(dimText)
            Button("Se connecter") {
                Task { await pi.connect() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(bgCard)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unconfiguredView: some View {
        VStack(spacing: 10) {
            Image(systemName: "gearshape")
                .font(.system(size: 24))
                .foregroundColor(dimText)
            Text("SSH non configuré")
                .font(.system(size: 13))
                .foregroundColor(dimText)
            Text("Configure la connexion dans Settings")
                .font(.system(size: 11))
                .foregroundColor(dimText.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status helpers

    private var statusColor: Color {
        switch pi.connectionState {
        case .connected:    return Color(red: 0.2, green: 0.85, blue: 0.3)
        case .connecting:   return .orange
        case .error:        return Color(red: 0.95, green: 0.25, blue: 0.25)
        case .disconnected: return Color(white: 0.4)
        }
    }

    private var statusText: String {
        switch pi.connectionState {
        case .connected:
            let host = ConfigManager.shared.config.resolvedApiHost
            return "Connecté · \(host)"
        case .connecting:   return "Connexion..."
        case .error(let m): return m
        case .disconnected: return "Déconnecté"
        }
    }
}

// MARK: - Docker

struct PiDockerSubView: View {
    @ObservedObject private var pi = RaspberryPiManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Containers")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(dimText)
                    .textCase(.uppercase)
                Spacer()
                Button { Task { await pi.fetchContainers() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(dimText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)

            if pi.isLoadingContainers {
                Spacer()
                ProgressView()
                Spacer()
            } else if pi.containers.isEmpty {
                Spacer()
                Text("Aucun container")
                    .font(.system(size: 12))
                    .foregroundColor(dimText)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(pi.containers) { c in
                            PiContainerRow(container: c)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

struct PiContainerRow: View {
    @ObservedObject private var pi = RaspberryPiManager.shared
    let container: DockerContainer
    @State private var loading = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(container.isRunning ? Color(red: 0.2, green: 0.85, blue: 0.3) : Color(white: 0.4))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(container.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(container.image)
                    .font(.system(size: 9))
                    .foregroundColor(dimText)
                    .lineLimit(1)
            }
            Spacer()
            if loading {
                ProgressView().scaleEffect(0.55)
            } else {
                Button { toggle() } label: {
                    Image(systemName: container.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(container.isRunning ? Color(red: 0.95, green: 0.25, blue: 0.25) : Color(red: 0.2, green: 0.85, blue: 0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bgCard)
        .cornerRadius(7)
    }

    private func toggle() {
        loading = true
        Task {
            if container.isRunning { await pi.stopContainer(container) }
            else                   { await pi.startContainer(container) }
            loading = false
        }
    }
}

// MARK: - Services

struct PiServicesSubView: View {
    @ObservedObject private var pi = RaspberryPiManager.shared
    @State private var search = ""

    private var filtered: [SystemdService] {
        search.isEmpty ? pi.services
            : pi.services.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(dimText)
                TextField("Filtrer...", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                Spacer()
                Button { Task { await pi.fetchServices() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(dimText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            if pi.isLoadingServices {
                Spacer()
                ProgressView()
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                Text("Aucun service")
                    .font(.system(size: 12))
                    .foregroundColor(dimText)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(filtered) { svc in
                            PiServiceRow(service: svc)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

struct PiServiceRow: View {
    @ObservedObject private var pi = RaspberryPiManager.shared
    let service: SystemdService
    @State private var loading = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(service.isActive ? Color(red: 0.2, green: 0.85, blue: 0.3) : Color(white: 0.35))
                .frame(width: 6, height: 6)
            Text(service.name)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            if loading {
                ProgressView().scaleEffect(0.55)
            } else {
                HStack(spacing: 6) {
                    if service.isActive {
                        Button { run { await pi.restartService(service) } } label: {
                            Image(systemName: "arrow.clockwise").font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                        Button { run { await pi.stopService(service) } } label: {
                            Image(systemName: "stop.fill").font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                    } else {
                        Button { run { await pi.startService(service) } } label: {
                            Image(systemName: "play.fill").font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.3))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bgCard)
        .cornerRadius(6)
    }

    private func run(_ action: @escaping () async -> Void) {
        loading = true
        Task { await action(); loading = false }
    }
}

// MARK: - Terminal

struct PiTerminalSubView: View {
    @ObservedObject private var pi = RaspberryPiManager.shared
    @State private var command = ""
    @State private var history: [(cmd: String, output: String)] = []
    @State private var running = false

    private let quickCmds: [(String, String)] = [
        ("uptime", "uptime"), ("vcgencmd measure_temp", "temp"),
        ("free -h", "RAM"), ("df -h", "disk"), ("uname -r", "kernel")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Quick commands
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(quickCmds, id: \.0) { cmd, label in
                        Button { execute(cmd) } label: {
                            Text(label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(bgCard)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Output
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(history.enumerated()), id: \.offset) { i, entry in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("$").foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.3))
                                    Text(entry.cmd).foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.3))
                                }
                                .font(.system(size: 10, design: .monospaced))

                                Text(entry.output.isEmpty ? "(no output)" : entry.output)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.75))
                                    .textSelection(.enabled)
                            }
                            .id(i)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: .infinity)
                .onChange(of: history.count) {
                    if let last = history.indices.last {
                        withAnimation { proxy.scrollTo(last) }
                    }
                }
            }

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.3))
                TextField("", text: $command, prompt: Text("Commande...").foregroundColor(.white.opacity(0.35)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit { execute(command) }
                if running {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Button { execute(command) } label: {
                        Image(systemName: "return").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(dimText)
                    .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func execute(_ cmd: String) {
        let trimmed = cmd.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        command = ""
        running = true
        Task {
            await pi.runCommand(trimmed)
            history.append((cmd: trimmed, output: pi.commandOutput))
            running = false
        }
    }
}

// MARK: - Files

struct PiFilesSubView: View {
    @ObservedObject private var pi = RaspberryPiManager.shared
    @State private var path = "/home/pi"
    @State private var entries: [PiFileEntry] = []
    @State private var loading = false
    @State private var uploadMsg: String? = nil

    struct PiFileEntry: Identifiable {
        let id = UUID()
        let name: String
        let isDir: Bool
        let size: String
    }

    var body: some View {
        VStack(spacing: 0) {
            // Path bar
            HStack(spacing: 6) {
                Button { goUp() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(path == "/" ? dimText : .white)
                .disabled(path == "/")

                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(dimText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button { loadDir() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(dimText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

            if let msg = uploadMsg {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundColor(dimText)
                    .padding(.bottom, 4)
            }

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            if loading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(entries) { entry in
                            Button {
                                guard entry.isDir else { return }
                                path = path.hasSuffix("/")
                                    ? "\(path)\(entry.name)"
                                    : "\(path)/\(entry.name)"
                                loadDir()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: entry.isDir ? "folder.fill" : "doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(entry.isDir ? .blue : dimText)
                                        .frame(width: 14)
                                    Text(entry.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    if !entry.isDir {
                                        Text(entry.size)
                                            .font(.system(size: 9))
                                            .foregroundColor(dimText)
                                    }
                                    if entry.isDir {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(dimText)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(bgCard)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
        .onAppear { loadDir() }
    }

    private func loadDir() {
        loading = true
        entries = []
        Task {
            let output = await pi.listDirectory(path)
            entries = parseLS(output)
            loading = false
        }
    }

    private func goUp() {
        let parts = path.split(separator: "/").map(String.init)
        path = parts.count > 1 ? "/" + parts.dropLast().joined(separator: "/") : "/"
        loadDir()
    }

    private func parseLS(_ raw: String) -> [PiFileEntry] {
        raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 9 else { return nil }
            let name = parts[8...].joined(separator: " ")
            guard name != "." && name != ".." else { return nil }
            return PiFileEntry(name: name, isDir: parts[0].hasPrefix("d"), size: parts[4])
        }
    }

}
