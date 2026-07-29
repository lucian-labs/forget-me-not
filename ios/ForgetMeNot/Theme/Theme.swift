import Foundation

/// Per-theme sound defaults (same synth + preset numbers as the web's YamaBruh).
struct ThemeSound: Equatable, Codable {
    var preset: Int
    var bpm: Int
    var volume: Double
    var mode: Int
}

/// Full web parity with `src/themes.ts` ThemeStyle: colors + shape + typography +
/// spacing + sound defaults. Fonts are the web's Google Fonts, bundled as
/// `FMN<Family>-Regular/Bold` TTFs (see Fonts/); `headerFont`/`bodyFont` hold the
/// web-side names ("Playfair Display") and FontMap resolves them to PostScript names.
/// `techno == true` keeps the waveloop identity treatment (mono, UPPERCASE, tracking)
/// used by the two native themes; web-ported themes render in natural case.
struct Theme: Identifiable, Equatable, Codable {
    var name: String
    var label: String
    var bg, surface, border, text, dim, accent, green, orange, red, cyan: String
    var radius: CGFloat
    var headerFont: String? = nil     // nil = system monospaced
    var bodyFont: String? = nil
    var fontSize: CGFloat = 14        // web base; scales type relative to 14
    var spacing: String = "normal"    // compact | normal | relaxed
    var techno: Bool = false
    var sound: ThemeSound? = nil
    var id: String { name }

    /// Gold-leaf deco — the app's identity look: warm near-black, gilt hairlines, gold
    /// ink accents. Matches the fmn brushstroke logo + the gold-ink task sigils.
    static let goldleaf = Theme(
        name: "goldleaf", label: "Gold Leaf",
        bg: "#0b0a07", surface: "#16130c", border: "#4a3d20", text: "#f3e8cf", dim: "#a89873",
        accent: "#e6b73f", green: "#a9b578", orange: "#e39a3c", red: "#d15a3e", cyan: "#6fb9a7",
        radius: 0, techno: true
    )

    static let waveloop = Theme(
        name: "waveloop", label: "Waveloop",
        bg: "#0e0e10", surface: "#18181b", border: "#2b2b30", text: "#eaecf2", dim: "#aaafbd",
        accent: "#2ec7b8", green: "#4dcc78", orange: "#ffa40a", red: "#eb404d", cyan: "#6be6e0",
        radius: 0, techno: true
    )

    // The 12 web themes, full fidelity from src/themes.ts (colors, radius, fonts,
    // fontSize, spacing, sound). Keep in sync when the web adds themes.
    static let all: [Theme] = [
        goldleaf,
        waveloop,
        Theme(name: "midnight", label: "Midnight", bg: "#0a0a0a", surface: "#141414", border: "#2a2a2a", text: "#e0e0e0", dim: "#666666", accent: "#60a5fa", green: "#4ade80", orange: "#fb923c", red: "#ef4444", cyan: "#22d3ee", radius: 6,
              headerFont: "Fira Code", bodyFont: "Fira Code", fontSize: 14, spacing: "normal", sound: ThemeSound(preset: 88, bpm: 160, volume: 0.4, mode: 1)),
        Theme(name: "sunrise", label: "Sunrise", bg: "#fdf6ee", surface: "#ffffff", border: "#e8ddd0", text: "#3d2e1f", dim: "#a08b72", accent: "#d97706", green: "#65a30d", orange: "#ea580c", red: "#dc2626", cyan: "#0891b2", radius: 12,
              headerFont: "Playfair Display", bodyFont: "Lora", fontSize: 15, spacing: "relaxed", sound: ThemeSound(preset: 91, bpm: 120, volume: 0.3, mode: 3)),
        Theme(name: "selva", label: "Selva", bg: "#0f1a14", surface: "#162118", border: "#2d4a35", text: "#c8e6cf", dim: "#5e8a68", accent: "#34d399", green: "#4ade80", orange: "#fbbf24", red: "#f87171", cyan: "#67e8f9", radius: 8,
              headerFont: "Josefin Sans", bodyFont: "Nunito", fontSize: 14, spacing: "normal", sound: ThemeSound(preset: 77, bpm: 100, volume: 0.35, mode: 5)),
        Theme(name: "kente", label: "Kente", bg: "#1a1207", surface: "#2a1f10", border: "#4a3520", text: "#f5e6c8", dim: "#a08660", accent: "#f59e0b", green: "#84cc16", orange: "#f97316", red: "#ef4444", cyan: "#06b6d4", radius: 4,
              headerFont: "Bebas Neue", bodyFont: "Inter", fontSize: 14, spacing: "compact", sound: ThemeSound(preset: 93, bpm: 140, volume: 0.5, mode: 2)),
        Theme(name: "neon", label: "Neon", bg: "#0d0015", surface: "#150022", border: "#2e0050", text: "#e0d0f0", dim: "#7a5ea0", accent: "#c084fc", green: "#a3e635", orange: "#fb923c", red: "#f43f5e", cyan: "#22d3ee", radius: 10,
              headerFont: "Orbitron", bodyFont: "JetBrains Mono", fontSize: 14, spacing: "normal", sound: ThemeSound(preset: 67, bpm: 200, volume: 0.5, mode: 7)),
        Theme(name: "cloud", label: "Cloud", bg: "#f0f4f8", surface: "#ffffff", border: "#d0dbe6", text: "#2d3748", dim: "#8896a6", accent: "#4299e1", green: "#48bb78", orange: "#ed8936", red: "#fc8181", cyan: "#38b2ac", radius: 14,
              headerFont: "Poppins", bodyFont: "Poppins", fontSize: 15, spacing: "relaxed", sound: ThemeSound(preset: 59, bpm: 110, volume: 0.3, mode: 0)),
        Theme(name: "terracotta", label: "Terracotta", bg: "#1c1210", surface: "#271a16", border: "#3d2b24", text: "#e8d5ca", dim: "#967a6a", accent: "#c2704f", green: "#a3b18a", orange: "#dda15e", red: "#bc4749", cyan: "#89b0ae", radius: 8,
              headerFont: "Cormorant Garamond", bodyFont: "Source Serif 4", fontSize: 15, spacing: "relaxed", sound: ThemeSound(preset: 90, bpm: 100, volume: 0.35, mode: 4)),
        Theme(name: "matcha", label: "Matcha", bg: "#f4f7f0", surface: "#fafcf7", border: "#d4dcc8", text: "#2d3a25", dim: "#7d8a72", accent: "#6b8f4e", green: "#7cb342", orange: "#e0a030", red: "#c0503a", cyan: "#5d9b9b", radius: 16,
              headerFont: "Quicksand", bodyFont: "Quicksand", fontSize: 15, spacing: "relaxed", sound: ThemeSound(preset: 17, bpm: 90, volume: 0.25, mode: 0)),
        Theme(name: "vinyl", label: "Vinyl", bg: "#121212", surface: "#1e1e1e", border: "#333333", text: "#d4d4d4", dim: "#737373", accent: "#e53e3e", green: "#68d391", orange: "#f6ad55", red: "#fc5c65", cyan: "#63b3ed", radius: 3,
              headerFont: "Space Mono", bodyFont: "IBM Plex Mono", fontSize: 13, spacing: "compact", sound: ThemeSound(preset: 0, bpm: 180, volume: 0.45, mode: 6)),
        Theme(name: "oceano", label: "Océano", bg: "#0b1628", surface: "#0f2035", border: "#1a3554", text: "#c8ddf0", dim: "#5a7a9a", accent: "#38bdf8", green: "#34d399", orange: "#fbbf24", red: "#f87171", cyan: "#67e8f9", radius: 10,
              headerFont: "Raleway", bodyFont: "Open Sans", fontSize: 14, spacing: "normal", sound: ThemeSound(preset: 92, bpm: 130, volume: 0.35, mode: 3)),
        Theme(name: "sakura", label: "Sakura", bg: "#fef5f7", surface: "#ffffff", border: "#f0d4db", text: "#4a2c3a", dim: "#b08a98", accent: "#e8729a", green: "#7bc47f", orange: "#e8a87c", red: "#d94f6b", cyan: "#6cc0c0", radius: 18,
              headerFont: "Kaisei Tokumin", bodyFont: "Noto Sans JP", fontSize: 15, spacing: "relaxed", sound: ThemeSound(preset: 30, bpm: 100, volume: 0.25, mode: 0)),
    ]

    static func named(_ n: String) -> Theme {
        all.first { $0.name == n } ?? UserThemes.load().first { $0.name == n } ?? goldleaf
    }
}

/// Web font name -> bundled PostScript base name ("Playfair Display" -> FMNPlayfairDisplay).
/// Bold variant is "<base>-Bold"; Bebas Neue ships regular-only (bold falls back).
enum FontMap {
    static let families: [String: String] = [
        "Fira Code": "FMNFiraCode",
        "Playfair Display": "FMNPlayfairDisplay",
        "Lora": "FMNLora",
        "Josefin Sans": "FMNJosefinSans",
        "Nunito": "FMNNunito",
        "Bebas Neue": "FMNBebasNeue",
        "Inter": "FMNInter",
        "Orbitron": "FMNOrbitron",
        "JetBrains Mono": "FMNJetBrainsMono",
        "Poppins": "FMNPoppins",
        "Cormorant Garamond": "FMNCormorantGaramond",
        "Source Serif 4": "FMNSourceSerif4",
        "Quicksand": "FMNQuicksand",
        "Space Mono": "FMNSpaceMono",
        "IBM Plex Mono": "FMNIBMPlexMono",
        "Raleway": "FMNRaleway",
        "Open Sans": "FMNOpenSans",
        "Kaisei Tokumin": "FMNKaiseiTokumin",
        "Noto Sans JP": "FMNNotoSansJp",
    ]
    static let boldless: Set<String> = ["FMNBebasNeue"]

    /// PostScript name for a web font name at a weight, or nil if not bundled.
    static func postScript(_ webName: String?, bold: Bool) -> String? {
        guard let webName, let base = families[webName] else { return nil }
        if bold && !boldless.contains(base) { return "\(base)-Bold" }
        return "\(base)-Regular"
    }
}

/// User-imported themes (web ThemeStyle JSON), persisted in UserDefaults.
enum UserThemes {
    private static let key = "fmn.userThemes"

    static func load() -> [Theme] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let themes = try? JSONDecoder().decode([Theme].self, from: data) else { return [] }
        return themes
    }

    static func save(_ themes: [Theme]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(themes), forKey: key)
    }

    /// Import a web ThemeStyle JSON blob (same shape the web's "Copy JSON" produces).
    /// Returns the imported theme, or nil if the JSON doesn't parse.
    static func importWebJson(_ json: String) -> Theme? {
        guard let data = json.data(using: .utf8),
              let web = try? JSONDecoder().decode(WebThemeStyle.self, from: data) else { return nil }
        var theme = web.toTheme()
        if Theme.all.contains(where: { $0.name == theme.name }) {
            theme.name = "\(theme.name)-custom"
        }
        var user = load().filter { $0.name != theme.name }
        user.append(theme)
        save(user)
        return theme
    }

    static func remove(_ name: String) {
        save(load().filter { $0.name != name })
    }
}

/// Decoder for the web's ThemeStyle JSON shape (nested colors, borderRadius key).
struct WebThemeStyle: Codable {
    struct Colors: Codable {
        var bg, surface, border, text, dim, accent, green, orange, red, cyan: String
    }
    var name: String
    var label: String?
    var colors: Colors
    var borderRadius: CGFloat?
    var fontSize: CGFloat?
    var headerFont: String?
    var bodyFont: String?
    var spacing: String?
    var sound: ThemeSound?

    func toTheme() -> Theme {
        Theme(name: name, label: label ?? name,
              bg: colors.bg, surface: colors.surface, border: colors.border, text: colors.text,
              dim: colors.dim, accent: colors.accent, green: colors.green, orange: colors.orange,
              red: colors.red, cyan: colors.cyan,
              radius: borderRadius ?? 8,
              headerFont: headerFont, bodyFont: bodyFont,
              fontSize: fontSize ?? 14, spacing: spacing ?? "normal")
    }
}
