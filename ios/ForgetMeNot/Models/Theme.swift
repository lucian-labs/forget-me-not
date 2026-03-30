import SwiftUI
import UIKit

struct ThemeColors {
    var bg: Color
    var surface: Color
    var border: Color
    var text: Color
    var dim: Color
    var accent: Color
    var green: Color
    var orange: Color
    var red: Color
    var cyan: Color
    var borderRadius: CGFloat
    var fontSize: CGFloat
    var spacing: CGFloat
    var isDark: Bool
    var headerFont: String
    var bodyFont: String

    /// Font for titles / headers
    func header(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(headerFont, size: size).weight(weight)
    }

    /// Font for body text / cards
    func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(bodyFont, size: size).weight(weight)
    }
}

struct ThemeColorHex {
    var bg, surface, border, text, dim, accent, green, orange, red, cyan: String
}

struct AppTheme: Identifiable {
    var id: String { name }
    var name: String
    var label: String
    var colors: ThemeColorHex
    var borderRadius: CGFloat
    var fontSize: CGFloat
    var spacing: CGFloat
    var isDark: Bool
    var headerFont: String
    var bodyFont: String

    func resolve(
        customColors cc: [String: String] = [:],
        customRadius: Double? = nil,
        customFontSize: Double? = nil,
        customHeaderFont: String? = nil,
        customBodyFont: String? = nil
    ) -> ThemeColors {
        let c = colors
        let resolvedBg: Color = Color(hex: cc["bg"] ?? c.bg)
        let resolvedSurface: Color = Color(hex: cc["surface"] ?? c.surface)
        let resolvedBorder: Color = Color(hex: cc["border"] ?? c.border)
        let resolvedText: Color = Color(hex: cc["text"] ?? c.text)
        let resolvedDim: Color = Color(hex: cc["dim"] ?? c.dim)
        let resolvedAccent: Color = Color(hex: cc["accent"] ?? c.accent)
        let resolvedGreen: Color = Color(hex: cc["green"] ?? c.green)
        let resolvedOrange: Color = Color(hex: cc["orange"] ?? c.orange)
        let resolvedRed: Color = Color(hex: cc["red"] ?? c.red)
        let resolvedCyan: Color = Color(hex: cc["cyan"] ?? c.cyan)
        let resolvedRadius: CGFloat = customRadius.map { CGFloat($0) } ?? borderRadius
        let resolvedFontSize: CGFloat = customFontSize.map { CGFloat($0) } ?? fontSize

        return ThemeColors(
            bg: resolvedBg, surface: resolvedSurface, border: resolvedBorder,
            text: resolvedText, dim: resolvedDim, accent: resolvedAccent,
            green: resolvedGreen, orange: resolvedOrange, red: resolvedRed, cyan: resolvedCyan,
            borderRadius: resolvedRadius, fontSize: resolvedFontSize,
            spacing: spacing, isDark: isDark,
            headerFont: customHeaderFont ?? headerFont,
            bodyFont: customBodyFont ?? bodyFont
        )
    }

    // MARK: - Built-in themes
    // Font mapping: web Google Fonts → closest iOS system font

    static let all: [AppTheme] = [midnight, sunrise, selva, kente, neon, cloud, terracotta, matcha, vinyl, oceano, sakura]

    static let midnight = AppTheme(
        name: "midnight", label: "Midnight",
        colors: .init(bg: "#0a0a0a", surface: "#141414", border: "#2a2a2a", text: "#e0e0e0", dim: "#666666", accent: "#60a5fa", green: "#4ade80", orange: "#fb923c", red: "#ef4444", cyan: "#22d3ee"),
        borderRadius: 12, fontSize: 15, spacing: 12, isDark: true,
        headerFont: "Menlo", bodyFont: "Menlo"                           // web: Fira Code
    )

    static let sunrise = AppTheme(
        name: "sunrise", label: "Sunrise",
        colors: .init(bg: "#fdf6ee", surface: "#ffffff", border: "#e8ddd0", text: "#3d2e1f", dim: "#a08b72", accent: "#d97706", green: "#65a30d", orange: "#ea580c", red: "#dc2626", cyan: "#0891b2"),
        borderRadius: 14, fontSize: 15, spacing: 16, isDark: false,
        headerFont: "Didot", bodyFont: "Georgia"                         // web: Playfair Display / Lora
    )

    static let selva = AppTheme(
        name: "selva", label: "Selva",
        colors: .init(bg: "#0f1a14", surface: "#162118", border: "#2d4a35", text: "#c8e6cf", dim: "#5e8a68", accent: "#34d399", green: "#4ade80", orange: "#fbbf24", red: "#f87171", cyan: "#67e8f9"),
        borderRadius: 12, fontSize: 15, spacing: 12, isDark: true,
        headerFont: "Futura", bodyFont: "Avenir Next"                    // web: Josefin Sans / Nunito
    )

    static let kente = AppTheme(
        name: "kente", label: "Kente",
        colors: .init(bg: "#1a1207", surface: "#2a1f10", border: "#4a3520", text: "#f5e6c8", dim: "#a08660", accent: "#f59e0b", green: "#84cc16", orange: "#f97316", red: "#ef4444", cyan: "#06b6d4"),
        borderRadius: 8, fontSize: 15, spacing: 10, isDark: true,
        headerFont: "DIN Condensed", bodyFont: "Helvetica Neue"          // web: Bebas Neue / Inter
    )

    static let neon = AppTheme(
        name: "neon", label: "Neon",
        colors: .init(bg: "#0d0015", surface: "#150022", border: "#2e0050", text: "#e0d0f0", dim: "#7a5ea0", accent: "#c084fc", green: "#a3e635", orange: "#fb923c", red: "#f43f5e", cyan: "#22d3ee"),
        borderRadius: 14, fontSize: 15, spacing: 12, isDark: true,
        headerFont: "Courier New", bodyFont: "Menlo"                     // web: Orbitron / JetBrains Mono
    )

    static let cloud = AppTheme(
        name: "cloud", label: "Cloud",
        colors: .init(bg: "#f0f4f8", surface: "#ffffff", border: "#d0dbe6", text: "#2d3748", dim: "#8896a6", accent: "#4299e1", green: "#48bb78", orange: "#ed8936", red: "#fc8181", cyan: "#38b2ac"),
        borderRadius: 16, fontSize: 15, spacing: 16, isDark: false,
        headerFont: "Avenir Next", bodyFont: "Avenir Next"               // web: Poppins
    )

    static let terracotta = AppTheme(
        name: "terracotta", label: "Terracotta",
        colors: .init(bg: "#1c1210", surface: "#271a16", border: "#3d2b24", text: "#e8d5ca", dim: "#967a6a", accent: "#c2704f", green: "#a3b18a", orange: "#dda15e", red: "#bc4749", cyan: "#89b0ae"),
        borderRadius: 12, fontSize: 15, spacing: 16, isDark: true,
        headerFont: "Baskerville", bodyFont: "Charter"                   // web: Cormorant Garamond / Source Serif 4
    )

    static let matcha = AppTheme(
        name: "matcha", label: "Matcha",
        colors: .init(bg: "#f4f7f0", surface: "#fafcf7", border: "#d4dcc8", text: "#2d3a25", dim: "#7d8a72", accent: "#6b8f4e", green: "#7cb342", orange: "#e0a030", red: "#c0503a", cyan: "#5d9b9b"),
        borderRadius: 18, fontSize: 15, spacing: 16, isDark: false,
        headerFont: "Gill Sans", bodyFont: "Gill Sans"                   // web: Quicksand
    )

    static let vinyl = AppTheme(
        name: "vinyl", label: "Vinyl",
        colors: .init(bg: "#121212", surface: "#1e1e1e", border: "#333333", text: "#d4d4d4", dim: "#737373", accent: "#e53e3e", green: "#68d391", orange: "#f6ad55", red: "#fc5c65", cyan: "#63b3ed"),
        borderRadius: 8, fontSize: 14, spacing: 10, isDark: true,
        headerFont: "Courier New", bodyFont: "Menlo"                     // web: Space Mono / IBM Plex Mono
    )

    static let oceano = AppTheme(
        name: "oceano", label: "Oc\u{00e9}ano",
        colors: .init(bg: "#0b1628", surface: "#0f2035", border: "#1a3554", text: "#c8ddf0", dim: "#5a7a9a", accent: "#38bdf8", green: "#34d399", orange: "#fbbf24", red: "#f87171", cyan: "#67e8f9"),
        borderRadius: 14, fontSize: 15, spacing: 12, isDark: true,
        headerFont: "Avenir", bodyFont: "Helvetica Neue"                 // web: Raleway / Open Sans
    )

    static let sakura = AppTheme(
        name: "sakura", label: "Sakura",
        colors: .init(bg: "#fef5f7", surface: "#ffffff", border: "#f0d4db", text: "#4a2c3a", dim: "#b08a98", accent: "#e8729a", green: "#7bc47f", orange: "#e8a87c", red: "#d94f6b", cyan: "#6cc0c0"),
        borderRadius: 20, fontSize: 15, spacing: 16, isDark: false,
        headerFont: "Hiragino Mincho ProN", bodyFont: "Hiragino Sans"    // web: Kaisei Tokumin / Noto Sans JP
    )
}

// MARK: - System font enumeration

enum SystemFonts {
    /// All font families available on this device, sorted alphabetically
    static var allFamilies: [String] {
        UIFont.familyNames.sorted()
    }

    /// Subset of families that work well for UI (Latin-script, readable)
    static let recommended: [String] = [
        "American Typewriter", "Avenir", "Avenir Next", "Avenir Next Condensed",
        "Baskerville", "Bodoni 72", "Charter", "Cochin", "Copperplate",
        "Courier", "Courier New", "DIN Alternate", "DIN Condensed",
        "Didot", "Futura", "Galvji", "Georgia", "Gill Sans",
        "Helvetica", "Helvetica Neue", "Hoefler Text", "Menlo",
        "Noteworthy", "Optima", "Palatino", "Rockwell",
        "Times New Roman", "Trebuchet MS", "Verdana",
        "Hiragino Mincho ProN", "Hiragino Sans",
    ]
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
