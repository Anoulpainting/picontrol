import SwiftUI
import AVFoundation

// MARK: - Looping Video Player

class VideoHostView: NSView {
    var trailingAligned = false
    var playerLayer: AVPlayerLayer?

    override func layout() {
        super.layout()
        guard let pl = playerLayer, trailingAligned else { return }
        let size = pl.player?.currentItem?.presentationSize ?? .zero
        if size.width > 0, bounds.height > 0 {
            let scale = bounds.height / size.height
            let w = size.width * scale
            pl.frame = CGRect(x: bounds.width - w, y: 0, width: w, height: bounds.height)
        } else {
            pl.frame = bounds
        }
    }
}

struct LoopingVideoPlayer: NSViewRepresentable {
    let resourceName: String
    var fileExtension: String = "mp4"
    var trailingAligned: Bool = false

    func makeNSView(context: Context) -> VideoHostView {
        let view = VideoHostView()
        view.trailingAligned = trailingAligned
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 1).cgColor

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return view
        }

        let player = AVPlayer(url: url)
        player.isMuted = true

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in player.seek(to: .zero); player.play() }

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        if !trailingAligned {
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        }
        view.layer?.addSublayer(layer)
        view.playerLayer = layer

        player.play()
        context.coordinator.attach(player, hostView: view)
        return view
    }

    func updateNSView(_ nsView: VideoHostView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var player: AVPlayer?
        var observation: NSKeyValueObservation?
        var readyObservation: NSKeyValueObservation?
        weak var hostView: VideoHostView?
        var active = true

        func attach(_ p: AVPlayer, hostView: VideoHostView? = nil) {
            player = p
            self.hostView = hostView
            observation = p.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                guard self?.active == true, player.timeControlStatus == .paused else { return }
                player.play()
            }
            if let item = p.currentItem {
                readyObservation = item.observe(\.status) { [weak self] _, _ in
                    DispatchQueue.main.async { self?.hostView?.needsLayout = true }
                }
            }
        }

        deinit {
            active = false
            player?.pause()
        }
    }
}

// MARK: - Step Dots

struct StepDots: View {
    let current: Int
    let total: Int
    var onTap: ((Int) -> Void)? = nil

    @State private var hovered: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                let isActive  = i == current
                let isHovered = hovered == i && !isActive && onTap != nil

                Circle()
                    .fill(isActive  ? Color.white :
                          isHovered ? Color.white.opacity(0.55) :
                                      Color.white.opacity(0.2))
                    .frame(width:  isActive ? 8 : isHovered ? 7 : 5,
                           height: isActive ? 8 : isHovered ? 7 : 5)
                    .animation(.easeInOut(duration: 0.15), value: hovered)
                    .onHover  { over in hovered = over ? i : nil }
                    .onTapGesture { onTap?(i) }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
    }
}

// MARK: - Button Style

struct OnboardingPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isEnabled
                    ? Color(red: 0.2, green: 0.85, blue: 0.3).opacity(configuration.isPressed ? 0.75 : 1)
                    : Color(white: 0.22)
            )
            .cornerRadius(8)
    }
}

struct OnboardingSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color.white.opacity(configuration.isPressed ? 0.4 : 0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0.1))
            .cornerRadius(8)
    }
}

// MARK: - Onboarding Container

struct OnboardingView: View {
    @State private var step = 0

    var body: some View {
        ZStack {
            bgPrimary.ignoresSafeArea()

            Group {
                if step == 0 {
                    OnboardingIntroScreen(onNext: advance, onDotTap: { step = $0 })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if step == 1 {
                    OnboardingSSHScreen(onNext: advance, onBack: goBack, onDotTap: { step = $0 })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    OnboardingDoneScreen(onDone: close, onBack: goBack, onDotTap: { step = $0 })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .frame(minWidth: 560, maxWidth: 560, minHeight: 420, maxHeight: .infinity)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private func advance() { withAnimation { step += 1 } }
    private func goBack()  { withAnimation { step -= 1 } }

    private func close() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        NSApp.keyWindow?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Screen 1 · Intro

struct OnboardingIntroScreen: View {
    let onNext: () -> Void
    let onDotTap: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LoopingVideoPlayer(resourceName: "pivid30000-0096", fileExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                stops: [
                    .init(color: bgPrimary, location: 0),
                    .init(color: .clear,    location: 0.25),
                    .init(color: .clear,    location: 0.5),
                    .init(color: bgPrimary, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome to PiControl")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("Your Raspberry Pi, right in the menu bar.")
                    .font(.system(size: 11))
                    .foregroundColor(dimText)
            }
            Spacer()
            StepDots(current: 0, total: 3, onTap: onDotTap)
            Spacer()
            Button("Get Started →", action: onNext)
                .buttonStyle(OnboardingPrimaryButton())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

// MARK: - Screen 2 · SSH Config

struct OnboardingSSHScreen: View {
    let onNext: () -> Void
    let onBack: () -> Void
    let onDotTap: (Int) -> Void

    @State private var host       = ConfigManager.shared.config.host
    @State private var port       = String(ConfigManager.shared.config.port)
    @State private var username   = ConfigManager.shared.config.username
    @State private var authMethod = ConfigManager.shared.config.authMethod
    @State private var password   = ""
    @State private var keyPath    = ConfigManager.shared.config.sshKeyPath
    @State private var errorMsg: String? = nil

    var body: some View {
        ZStack(alignment: .leading) {
            LoopingVideoPlayer(resourceName: "pivid50000-0096", fileExtension: "mp4")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                stops: [
                    .init(color: bgPrimary,             location: 0),
                    .init(color: bgPrimary.opacity(0.9), location: 0.45),
                    .init(color: bgPrimary.opacity(0.3), location: 0.72),
                    .init(color: .clear,                location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                header
                form
                Spacer(minLength: 0)
                footer
            }
            .frame(maxWidth: 310, maxHeight: .infinity)
        }
        .task {
            await Task.detached(priority: .userInitiated) {
                let pwd = KeychainHelper.getPassword() ?? ""
                await MainActor.run { password = pwd }
            }.value
        }
    }

    // ── Header ────────────────────────────────────────────────────

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Connect your Raspberry Pi")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("Enter your SSH credentials below.")
                .font(.system(size: 11))
                .foregroundColor(dimText)
        }
        .padding(.horizontal, 24)
        .padding(.top, 42)
        .padding(.bottom, 14)
    }

    // ── Form ──────────────────────────────────────────────────────

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Host
            fieldGroup(label: "Host", icon: "network",
                       helper: "IP address or hostname of your Raspberry Pi — e.g. 192.168.1.100") {
                TextField("192.168.1.100", text: $host)
                    .styledField()
            }

            // Port + Username
            HStack(alignment: .top, spacing: 12) {
                fieldGroup(label: "Port", icon: "number", helper: "Default: 22") {
                    TextField("22", text: $port)
                        .styledField()
                }
                .frame(width: 100)

                fieldGroup(label: "Username", icon: "person", helper: "Usually pi or your custom user") {
                    TextField("pi", text: $username)
                        .styledField()
                }
            }

            // Auth
            fieldGroup(label: "Authentication", icon: "key", helper: nil) {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("", selection: $authMethod) {
                        Text("Password").tag(AuthMethod.password)
                        Text("SSH Key") .tag(AuthMethod.key)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if authMethod == .password {
                        SecureField("SSH password", text: $password)
                            .styledField()
                    } else {
                        HStack(spacing: 6) {
                            TextField("~/.ssh/id_rsa", text: $keyPath)
                                .styledField()
                            Button {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = true
                                panel.canChooseDirectories = false
                                panel.allowsMultipleSelection = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    keyPath = url.path
                                }
                                NSApp.activate(ignoringOtherApps: true)
                                NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
                            } label: {
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
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // ── Footer ────────────────────────────────────────────────────

    private var footer: some View {
        VStack(spacing: 8) {
            if let msg = errorMsg {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
            }
            HStack {
                Spacer()
                StepDots(current: 1, total: 3, onTap: onDotTap)
                Spacer()
                Button("Save & Continue →", action: saveAndContinue)
                    .buttonStyle(OnboardingPrimaryButton())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // ── Helpers ───────────────────────────────────────────────────

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, icon: String, helper: String?,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(dimText)
            content()
            if let h = helper {
                Text(h)
                    .font(.system(size: 10))
                    .foregroundColor(dimText.opacity(0.6))
            }
        }
    }

    private func saveAndContinue() {
        let h = host.trimmingCharacters(in: .whitespaces)
        let u = username.trimmingCharacters(in: .whitespaces)

        if h.isEmpty {
            errorMsg = "Host is required."; return
        }
        if u.isEmpty {
            errorMsg = "Username is required."; return
        }
        if authMethod == .password && password.isEmpty {
            errorMsg = "Password is required."; return
        }
        errorMsg = nil

        var cfg = ConfigManager.shared.config
        cfg.host       = h
        cfg.apiHost    = h
        cfg.port       = Int(port) ?? 22
        cfg.username   = u
        cfg.authMethod = authMethod
        cfg.sshKeyPath = keyPath
        ConfigManager.shared.config = cfg
        ConfigManager.shared.save()
        if authMethod == .password {
            KeychainHelper.savePassword(password)
        }
        onNext()
    }
}

// MARK: - Screen 3 · Done

struct OnboardingDoneScreen: View {
    let onDone: () -> Void
    let onBack: () -> Void
    let onDotTap: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LoopingVideoPlayer(resourceName: "tuto", fileExtension: "mp4", trailingAligned: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                stops: [
                    .init(color: .clear,                 location: 0),
                    .init(color: .clear,                 location: 0.6),
                    .init(color: bgPrimary,              location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            StepDots(current: 2, total: 3, onTap: onDotTap)
            Spacer()
            Button("Launch PiControl", action: onDone)
                .buttonStyle(OnboardingPrimaryButton())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

// MARK: - TextField style helper

private extension View {
    func styledField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.08, green: 0.07, blue: 0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}
