import SwiftUI

let bgPrimary  = Color(red: 0.08, green: 0.11, blue: 0.19)
let bgCard     = Color(red: 0.12, green: 0.16, blue: 0.26)
let dimText    = Color(white: 0.55)

struct MenuBarView: View {
    @ObservedObject private var state = CommandState.shared

    // RGB
    @State private var rgbEnabled    = true
    @State private var rgbStyle      = "breathing"
    @State private var rgbHue        = 0.6
    @State private var rgbBrightness = 80.0
    @State private var rgbSpeed      = 60.0

    // OLED
    @State private var oledEnabled      = true
    @State private var oledRotation     = 0
    @State private var oledPageMix      = true
    @State private var oledPagePerf     = true
    @State private var oledPageIps      = true
    @State private var oledPageDisk     = true
    @State private var oledSleepTimeout = 0.0
    @State private var tempUnit         = "C"

    // Fan
    @State private var fanMode = 3

    // UI
    private var accent: Color { Color(hue: rgbHue, saturation: 1, brightness: 1) }

    @ObservedObject private var pi = RaspberryPiManager.shared
    @State private var heroTab          = 0   // 0 = Pironman5, 1 = Raspberry Pi
    @State private var selectedTab      = 0   // RGB / OLED / FAN
    @State private var piSubTab         = 0   // Docker / Services / Terminal / Files
    @State private var isSyncing        = false
    @State private var isApplyingConfig = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            panelDivider
            tabBarView
            panelDivider
            contentView
            panelDivider
            footerView
        }
        .background(bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 340)
        .background(WindowTransparency())
        .onAppear {
            syncConfig()
            if ConfigManager.shared.isSSHConfigured {
                Task { await pi.connect() }
            }
        }
    }

    // MARK: - Header (hero tabs)

    private var headerView: some View {
        HStack(spacing: 10) {
            // Pironman5 hero card
            Button { withAnimation(.easeInOut(duration: 0.2)) { heroTab = 0 } } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Circle()
                        .fill(state.isRunning ? Color.orange : Color(red: 0.2, green: 0.85, blue: 0.3))
                        .frame(width: 10, height: 10)
                    Spacer()
                    Text("Pironman5")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(heroTab == 0 ? .white : Color(white: 0.5))
                        .lineSpacing(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                .background(heroTab == 0 ? bgCard : bgCard.opacity(0.5))
                .cornerRadius(13)
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(Color.white.opacity(heroTab == 0 ? 0.18 : 0), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: heroTab)

            // Pi hero card
            Button { withAnimation(.easeInOut(duration: 0.2)) { heroTab = 1 } } label: {
                VStack(alignment: .leading, spacing: 0) {
                    if case .connected = pi.connectionState {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.85, blue: 0.3))
                            .frame(width: 10, height: 10)
                    } else {
                        Circle()
                            .fill(Color(white: 0.35))
                            .frame(width: 10, height: 10)
                    }
                    Spacer()
                    Text("Pi")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(heroTab == 1 ? .white : Color(white: 0.5))
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                .background(heroTab == 1 ? bgCard : bgCard.opacity(0.5))
                .cornerRadius(13)
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(Color.white.opacity(heroTab == 1 ? 0.18 : 0), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: heroTab)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Bar (adapts to active hero tab)

    private var tabBarView: some View {
        Group {
            if heroTab == 0 {
                tabRow([("RGB", 0), ("OLED", 1), ("FAN", 2)], binding: $selectedTab)
            } else {
                tabRow([("Docker", 0), ("Services", 1), ("Terminal", 2), ("Files", 3)], binding: $piSubTab)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: heroTab)
    }

    private func tabRow(_ tabs: [(String, Int)], binding: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.1) { label, idx in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { binding.wrappedValue = idx }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: binding.wrappedValue == idx ? .semibold : .regular))
                        .foregroundColor(binding.wrappedValue == idx ? .white : dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(binding.wrappedValue == idx ? bgCard : Color.clear)
                        .cornerRadius(9)
                        .animation(.easeInOut(duration: 0.18), value: binding.wrappedValue)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        ZStack(alignment: .top) {
            if heroTab == 0 {
                switch selectedTab {
                case 0:  rgbTabView.id("rgb")
                case 1:  oledTabView.id("oled")
                default: fanTabView.id("fan")
                }
            } else {
                piContentView.id("pi-\(piSubTab)")
            }
        }
        .frame(height: 318)
        .animation(.easeInOut(duration: 0.18), value: heroTab)
        .animation(.easeInOut(duration: 0.18), value: selectedTab)
        .animation(.easeInOut(duration: 0.18), value: piSubTab)
        .clipped()
    }

    // MARK: - Pi content

    @ViewBuilder
    private var piContentView: some View {
        VStack(spacing: 0) {
            if !ConfigManager.shared.isSSHConfigured {
                piMessageView(icon: "gearshape", text: "SSH non configuré", sub: "Configure dans Settings")
            } else if !pi.isConnected {
                VStack(spacing: 10) {
                    piMessageView(icon: "bolt.slash", text: "Non connecté", sub: nil)
                    Button("Se connecter") { Task { await pi.connect() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(bgCard).cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch piSubTab {
                case 0: PiDockerSubView()
                case 1: PiServicesSubView()
                case 2: PiTerminalSubView()
                default: PiFilesSubView()
                }
            }
        }
    }

    private func piMessageView(icon: String, text: String, sub: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(dimText)
            Text(text).font(.system(size: 13)).foregroundColor(dimText)
            if let sub { Text(sub).font(.system(size: 11)).foregroundColor(dimText.opacity(0.7)) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - RGB Tab

    private var rgbTabView: some View {
        VStack(spacing: 0) {
            // LEDs
            HStack {
                Text("LEDs").foregroundColor(.white).font(.system(size: 14))
                Spacer()
                Toggle("", isOn: $rgbEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(accent)
                    .onChange(of: rgbEnabled) { _, v in apiSet("rgb_enable", value: v, label: "LEDs") }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)

            rowDivider

            // Color
            HStack {
                Text("Color").foregroundColor(.white).font(.system(size: 14))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 8)

            SpectrumSlider(hue: $rgbHue) { h in applyHue(h) }
                .padding(.horizontal, 14)
                .padding(.bottom, 13)

            rowDivider

            // Style
            HStack(spacing: 12) {
                Text("Style").foregroundColor(.white).font(.system(size: 14))
                Menu {
                    ForEach(rgbStyles, id: \.0) { value, label in
                        Button(label) {
                            rgbStyle = value
                            apiSet("rgb_style", value: value, label: "Style")
                        }
                    }
                } label: {
                    HStack {
                        Text(rgbStyleLabel(rgbStyle))
                            .foregroundColor(.white)
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            rowDivider

            // Brightness
            sliderRow(label: "Brightness", value: $rgbBrightness, displayValue: "\(Int(rgbBrightness))%") { v in
                apiSet("rgb_brightness", value: Int(v), label: "Brightness")
            }

            rowDivider

            // Speed
            sliderRow(label: "Speed", value: $rgbSpeed, displayValue: "\(Int(rgbSpeed))%") { v in
                apiSet("rgb_speed", value: Int(v), label: "Speed")
            }

            Spacer()
        }
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        displayValue: String,
        onRelease: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundColor(.white)
                .font(.system(size: 14))
                .frame(width: 90, alignment: .leading)
            Text(displayValue)
                .foregroundColor(dimText)
                .font(.system(size: 12))
                .monospacedDigit()
            PinkSlider(value: value, range: 0...100, step: 5, color: accent, onRelease: onRelease)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
    }

    // MARK: - OLED Tab

    private var oledTabView: some View {
        VStack(spacing: 0) {
            // Screen
            HStack {
                Text("Screen").foregroundColor(.white).font(.system(size: 14))
                Spacer()
                Toggle("", isOn: $oledEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(accent)
                    .onChange(of: oledEnabled) { _, v in apiSet("oled_enable", value: v, label: "OLED") }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)

            rowDivider

            // Pages
            HStack(spacing: 8) {
                ForEach([("Mix", "mix"), ("Perf", "performance"), ("IPS", "ips"), ("Disk", "disk")], id: \.1) { label, key in
                    let isOn = bindingForPage(key).wrappedValue
                    Button {
                        bindingForPage(key).wrappedValue.toggle()
                        applyOledPages()
                    } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(bgCard)
                            .cornerRadius(9)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(isOn ? accent : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            rowDivider

            // Rotation
            HStack {
                Text("Rotation").foregroundColor(.white).font(.system(size: 14))
                Spacer()
                HStack(spacing: 8) {
                    ForEach([(0, "0°"), (180, "180°")], id: \.0) { val, lbl in
                        Button {
                            oledRotation = val
                            apiSet("oled_rotation", value: val, label: "Rotation")
                        } label: {
                            Text(lbl)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 72)
                                .padding(.vertical, 9)
                                .background(bgCard)
                                .cornerRadius(9)
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(oledRotation == val ? accent : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            rowDivider

            // Sleep
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Sleep").foregroundColor(.white).font(.system(size: 14))
                    Text(oledSleepTimeout == 0 ? "off" : "\(Int(oledSleepTimeout))s")
                        .foregroundColor(dimText)
                        .font(.system(size: 13))
                    Spacer()
                }
                PinkSlider(value: $oledSleepTimeout, range: 0...300, step: 10, color: accent) { v in
                    apiSet("oled_sleep_timeout", value: Int(v), label: "Sleep")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            rowDivider

            // Temp Unit
            HStack {
                Text("Temp Unit").foregroundColor(.white).font(.system(size: 14))
                Spacer()
                HStack(spacing: 8) {
                    ForEach([("C", "Celsius °C"), ("F", "Fahrenheit °F")], id: \.0) { val, lbl in
                        Button {
                            tempUnit = val
                            apiSet("temperature_unit", value: val, label: "Temp")
                        } label: {
                            Text(lbl)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(bgCard)
                                .cornerRadius(9)
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(tempUnit == val ? accent : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer()
        }
    }

    // MARK: - Fan Tab

    private var fanTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fan Mode")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 18)
                .padding(.horizontal, 14)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach([("Always On", 0), ("Performance", 1), ("Cool", 2), ("Balanced", 3), ("Silent", 4)], id: \.1) { lbl, val in
                    Button {
                        fanMode = val
                        apiSet("fan_mode", value: val, label: "Fan")
                    } label: {
                        Text(lbl)
                            .font(.system(size: 13, weight: fanMode == val ? .semibold : .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(bgCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(fanMode == val ? accent : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Settings") {
                AppDelegate.shared?.showSettings()
            }
            Spacer()
            if isSyncing {
                ProgressView().scaleEffect(0.65)
            } else {
                Button { syncConfig() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .foregroundColor(dimText)
    }

    // MARK: - Shared sub-views

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(height: 1)
    }

    // MARK: - RGB style data

    private let rgbStyles: [(String, String)] = [
        ("solid",           "Solid"),
        ("breathing",       "Breathing"),
        ("flow",            "Flow"),
        ("flow_reverse",    "Flow Reverse"),
        ("rainbow",         "Rainbow"),
        ("rainbow_reverse", "Rainbow Reverse"),
        ("hue_cycle",       "Hue Cycle"),
    ]

    private func rgbStyleLabel(_ value: String) -> String {
        rgbStyles.first { $0.0 == value }?.1 ?? value
    }

    // MARK: - Sync

    private func syncConfig() {
        guard !isSyncing else { return }
        isSyncing = true
        PironmanAPI.shared.fetchConfig { result in
            isSyncing = false
            guard case .success(let cfg) = result else { return }
            isApplyingConfig = true
            applyConfig(cfg)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isApplyingConfig = false }
        }
    }

    private func applyConfig(_ raw: [String: Any]) {
        let cfg = raw["system"] as? [String: Any] ?? raw
        if let v = cfg["rgb_enable"]         as? Bool   { rgbEnabled    = v }
        if let v = cfg["rgb_style"]          as? String { rgbStyle      = v }
        if let v = cfg["rgb_brightness"]     as? Int    { rgbBrightness = Double(v) }
        if let v = cfg["rgb_speed"]          as? Int    { rgbSpeed      = Double(v) }
        if let v = cfg["rgb_color"] as? String, v.count == 6,
           let nsColor = NSColor(Color(hex: v) ?? .blue).usingColorSpace(.sRGB) {
            var h: CGFloat = 0
            nsColor.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
            rgbHue = Double(h)
            CommandState.shared.currentHue = Double(h)
        }
        if let v = cfg["oled_enable"]        as? Bool { oledEnabled      = v }
        if let v = cfg["oled_rotation"]      as? Int  { oledRotation     = v }
        if let v = cfg["oled_sleep_timeout"] as? Int  { oledSleepTimeout = Double(v) }
        let pages: [String]
        if let arr = cfg["oled_pages"] as? [String] { pages = arr }
        else if let str = cfg["oled_pages"] as? String {
            pages = str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else { pages = [] }
        if !pages.isEmpty {
            oledPageMix  = pages.contains("mix")
            oledPagePerf = pages.contains("performance")
            oledPageIps  = pages.contains("ips")
            oledPageDisk = pages.contains("disk")
        }
        if let v = cfg["temperature_unit"] as? String { tempUnit = v }
        if let v = cfg["fan_mode"]          as? Int   { fanMode  = v }
    }

    // MARK: - Helpers

    private func apiSet(_ key: String, value: Any, label: String = "") {
        guard !isApplyingConfig else { return }
        state.apiSet(key: key, value: value, label: label)
    }

    private func applyHue(_ hue: Double) {
        CommandState.shared.currentHue = hue
        let hex = Color(hue: hue, saturation: 1, brightness: 1).toHex() ?? "ffffff"
        apiSet("rgb_color", value: hex, label: "Color")
    }

    private func applyOledPages() {
        var pages: [String] = []
        if oledPageMix  { pages.append("mix") }
        if oledPagePerf { pages.append("performance") }
        if oledPageIps  { pages.append("ips") }
        if oledPageDisk { pages.append("disk") }
        guard !pages.isEmpty else { return }
        apiSet("oled_pages", value: pages, label: "OLED Pages")
    }

    private func bindingForPage(_ key: String) -> Binding<Bool> {
        switch key {
        case "mix":         return $oledPageMix
        case "performance": return $oledPagePerf
        case "ips":         return $oledPageIps
        case "disk":        return $oledPageDisk
        default:            return .constant(false)
        }
    }
}

// MARK: - Color extensions

extension Color {
    func toHex() -> String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "%02x%02x%02x",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }

    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
