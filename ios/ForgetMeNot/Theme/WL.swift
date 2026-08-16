import SwiftUI
import Observation

/// Live theme. Same `WL.bg` / `WL.header(...)` / `WL.urgencyColor(...)` API everywhere;
/// applying a Theme re-themes the whole app instantly — colors, corner radius,
/// typography (bundled web fonts), letter case, tracking, and spacing scale.
/// `techno` themes (goldleaf/waveloop) keep the synth-panel identity: system mono,
/// UPPERCASE, tracked. Web-ported themes render their own fonts in natural case.
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
    var radius: CGFloat = 0

    // Typography + layout personality (web parity).
    var headerBase: String? = nil    // FontMap base ("FMNPlayfairDisplay"), nil = system mono
    var bodyBase: String? = nil
    var fontScale: CGFloat = 1       // theme fontSize / 14
    var techno: Bool = true          // UPPERCASE + tracking + mono identity
    var spacingScale: CGFloat = 1    // compact 0.85 / normal 1 / relaxed 1.2
    /// True when the theme's background is bright (sakura, cloud, matcha, sunrise).
    /// Drives `.preferredColorScheme` — otherwise the status bar keeps drawing white
    /// text on a near-white background and reads as broken.
    var isLight: Bool = false

    init() { apply(.goldleaf) }

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
        radius = t.radius
        headerBase = t.headerFont.flatMap { FontMap.families[$0] }
        bodyBase = t.bodyFont.flatMap { FontMap.families[$0] }
        fontScale = t.fontSize / 14
        techno = t.techno
        spacingScale = t.spacing == "compact" ? 0.85 : t.spacing == "relaxed" ? 1.2 : 1
        isLight = Palette.luminance(of: t.bg) > 0.55
    }

    /// Perceived brightness (0...1) of a `#RRGGBB` string, Rec. 601 weighting.
    static func luminance(of hex: String) -> Double {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >> 8) & 0xff) / 255
        let b = Double(v & 0xff) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    // MARK: - Fonts

    /// Theme header font (titles, section labels, buttons). Falls back to system mono.
    func header(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        custom(headerBase, size: size, weight: weight)
    }

    /// Theme body font (content, notes, values). Falls back to system mono.
    func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        custom(bodyBase, size: size, weight: weight)
    }

    /// Always-monospaced — for meters, timers, version strings, numeric readouts.
    func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * fontScale, weight: weight, design: .monospaced)
    }

    private func custom(_ base: String?, size: CGFloat, weight: Font.Weight) -> Font {
        let scaled = size * fontScale
        guard let base else { return .system(size: scaled, weight: weight, design: .monospaced) }
        let bold = weight == .bold || weight == .semibold || weight == .heavy || weight == .black
        let name = bold && !FontMap.boldless.contains(base) ? "\(base)-Bold" : "\(base)-Regular"
        return .custom(name, size: scaled)
    }

    // MARK: - Case / tracking / spacing

    /// Display transform: UPPERCASE on techno themes, natural case otherwise.
    func t(_ s: String) -> String { techno ? s.uppercased() : s }

    /// Letter-spacing: full tracking on techno themes, none otherwise.
    func trk(_ base: CGFloat) -> CGFloat { techno ? base : 0 }

    /// Spacing/padding scaled by the theme's density (compact/normal/relaxed).
    func pad(_ v: CGFloat) -> CGFloat { (v * spacingScale).rounded() }

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

@MainActor
extension View {
    /// Fill + 1pt border at the current theme's corner radius.
    func wlPanel(fill: Color, border: Color, line: CGFloat = 1) -> some View {
        let shape = RoundedRectangle(cornerRadius: WL.radius, style: .continuous)
        return background(fill, in: shape).overlay(shape.stroke(border, lineWidth: line))
    }
    func wlStroke(_ color: Color, line: CGFloat = 1) -> some View {
        overlay(RoundedRectangle(cornerRadius: WL.radius, style: .continuous).stroke(color, lineWidth: line))
    }
    func wlClip() -> some View {
        clipShape(RoundedRectangle(cornerRadius: WL.radius, style: .continuous))
    }
}
