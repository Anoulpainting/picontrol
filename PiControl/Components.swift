import SwiftUI

// Makes the hosting NSPanel transparent so macOS doesn't draw its own border highlight
struct WindowTransparency: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.backgroundColor = .clear
            window.isOpaque = false
            if let panel = window as? NSPanel {
                panel.becomesKeyOnlyIfNeeded = false
            }
        }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

// Full-width spectrum (hue) slider
struct SpectrumSlider: View {
    @Binding var hue: Double
    let onRelease: (Double) -> Void

    private static let spectrumColors: [Color] =
        (0...36).map { Color(hue: Double($0) / 36, saturation: 1, brightness: 1) }

    var body: some View {
        GeometryReader { geo in
            let thumbR: CGFloat = 10
            let usable = max(1, geo.size.width - thumbR * 2)

            ZStack(alignment: .leading) {
                LinearGradient(colors: Self.spectrumColors, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 14)
                    .cornerRadius(7)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .frame(width: thumbR * 2, height: thumbR * 2)
                    .overlay(
                        Circle()
                            .fill(Color(hue: hue, saturation: 1, brightness: 1))
                            .frame(width: thumbR * 1.15, height: thumbR * 1.15)
                    )
                    .offset(x: CGFloat(hue) * usable)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        hue = max(0, min(1, Double((v.location.x - thumbR) / usable)))
                    }
                    .onEnded { v in
                        hue = max(0, min(1, Double((v.location.x - thumbR) / usable)))
                        onRelease(hue)
                    }
            )
        }
        .frame(height: 20)
    }
}

// Pink slider — custom track + thumb with accent color
struct PinkSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var color: Color = Color(red: 1.0, green: 0.176, blue: 0.471)
    let onRelease: (Double) -> Void

    private let thumbR: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumbR * 2)
            let ratio = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: thumbR + ratio * usable, height: 4)

                Circle()
                    .fill(color)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .frame(width: thumbR * 2, height: thumbR * 2)
                    .offset(x: ratio * usable)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        setValue(from: v.location.x, usable: usable)
                    }
                    .onEnded { v in
                        setValue(from: v.location.x, usable: usable)
                        onRelease(value)
                    }
            )
        }
        .frame(height: 20)
    }

    private func setValue(from x: CGFloat, usable: CGFloat) {
        let ratio = max(0, min(1, Double((x - thumbR) / usable)))
        let raw = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
        value = step > 0 ? (raw / step).rounded() * step : raw
        value = max(range.lowerBound, min(range.upperBound, value))
    }
}
