import SwiftUI
import Observation

/// Live palette. Same `WL.bg` / `WL.mono(...)` / `WL.urgencyColor(...)` API the views
/// already use, but observable — applying a Theme re-themes the whole app instantly.
/// Structure (monospaced, square, LED meters) is constant; only colors change.
@MainActor
@Observable
final class Palette {
    var bg: Color = .black
    var surface: Color = .black
    var border: Color = .gray
    var line: Color = .gray
    var text: Color = .white
    var muted: Color = .gray
    var accent: Color = .teal
    var cyan: Color = .cyan
    var gold: Color = .orange
    var green: Color = .green
    var red: Color = .red

    init() { apply(.waveloop) }

    func apply(_ t: Theme) {
        bg = Color(hex: t.bg)
        surface = Color(hex: t.surface)
        border = Color(hex: t.border)
        line = Color(hex: t.border)
        text = Color(hex: t.text)
        muted = Color(hex: t.dim)
        accent = Color(hex: t.accent)
        cyan = Color(hex: t.cyan)
        gold = Color(hex: t.orange)
        green = Color(hex: t.green)
        red = Color(hex: t.red)
    }

    func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    func urgencyColor(_ tier: UrgencyTier) -> Color {
        switch tier {
        case .calm: green
        case .soon: gold
        case .due, .overdue: red
        }
    }
}

@MainActor let WL = Palette()

extension Color {
    /// `#RRGGBB` or `#RGB`.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >> 8) & 0xff) / 255
        let b = Double(v & 0xff) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
