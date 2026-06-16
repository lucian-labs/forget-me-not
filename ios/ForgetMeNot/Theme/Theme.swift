import Foundation

/// A palette + shape ported from the web (`src/themes.ts`), plus a Waveloop default.
/// Hex strings (mapped to Palette roles when applied) and a corner radius. Structure
/// stays waveloop (mono / LED meters); the theme swaps colors + radius.
struct Theme: Identifiable, Equatable {
    let name: String
    let label: String
    let bg, surface, border, text, dim, accent, green, orange, red, cyan: String
    let radius: CGFloat
    var id: String { name }

    static let waveloop = Theme(
        name: "waveloop", label: "Waveloop",
        bg: "#0e0e10", surface: "#18181b", border: "#2b2b30", text: "#eaecf2", dim: "#aaafbd",
        accent: "#2ec7b8", green: "#4dcc78", orange: "#ffa40a", red: "#eb404d", cyan: "#6be6e0",
        radius: 0
    )

    static let all: [Theme] = [
        waveloop,
        Theme(name: "midnight", label: "Midnight", bg: "#0a0a0a", surface: "#141414", border: "#2a2a2a", text: "#e0e0e0", dim: "#666666", accent: "#60a5fa", green: "#4ade80", orange: "#fb923c", red: "#ef4444", cyan: "#22d3ee", radius: 6),
        Theme(name: "sunrise", label: "Sunrise", bg: "#fdf6ee", surface: "#ffffff", border: "#e8ddd0", text: "#3d2e1f", dim: "#a08b72", accent: "#d97706", green: "#65a30d", orange: "#ea580c", red: "#dc2626", cyan: "#0891b2", radius: 12),
        Theme(name: "selva", label: "Selva", bg: "#0f1a14", surface: "#162118", border: "#2d4a35", text: "#c8e6cf", dim: "#5e8a68", accent: "#34d399", green: "#4ade80", orange: "#fbbf24", red: "#f87171", cyan: "#67e8f9", radius: 8),
        Theme(name: "kente", label: "Kente", bg: "#1a1207", surface: "#2a1f10", border: "#4a3520", text: "#f5e6c8", dim: "#a08660", accent: "#f59e0b", green: "#84cc16", orange: "#f97316", red: "#ef4444", cyan: "#06b6d4", radius: 4),
        Theme(name: "neon", label: "Neon", bg: "#0d0015", surface: "#150022", border: "#2e0050", text: "#e0d0f0", dim: "#7a5ea0", accent: "#c084fc", green: "#a3e635", orange: "#fb923c", red: "#f43f5e", cyan: "#22d3ee", radius: 10),
        Theme(name: "cloud", label: "Cloud", bg: "#f0f4f8", surface: "#ffffff", border: "#d0dbe6", text: "#2d3748", dim: "#8896a6", accent: "#4299e1", green: "#48bb78", orange: "#ed8936", red: "#fc8181", cyan: "#38b2ac", radius: 14),
        Theme(name: "terracotta", label: "Terracotta", bg: "#1c1210", surface: "#271a16", border: "#3d2b24", text: "#e8d5ca", dim: "#967a6a", accent: "#c2704f", green: "#a3b18a", orange: "#dda15e", red: "#bc4749", cyan: "#89b0ae", radius: 8),
        Theme(name: "matcha", label: "Matcha", bg: "#f4f7f0", surface: "#fafcf7", border: "#d4dcc8", text: "#2d3a25", dim: "#7d8a72", accent: "#6b8f4e", green: "#7cb342", orange: "#e0a030", red: "#c0503a", cyan: "#5d9b9b", radius: 16),
        Theme(name: "vinyl", label: "Vinyl", bg: "#121212", surface: "#1e1e1e", border: "#333333", text: "#d4d4d4", dim: "#737373", accent: "#e53e3e", green: "#68d391", orange: "#f6ad55", red: "#fc5c65", cyan: "#63b3ed", radius: 3),
        Theme(name: "oceano", label: "Océano", bg: "#0b1628", surface: "#0f2035", border: "#1a3554", text: "#c8ddf0", dim: "#5a7a9a", accent: "#38bdf8", green: "#34d399", orange: "#fbbf24", red: "#f87171", cyan: "#67e8f9", radius: 10),
        Theme(name: "sakura", label: "Sakura", bg: "#fef5f7", surface: "#ffffff", border: "#f0d4db", text: "#4a2c3a", dim: "#b08a98", accent: "#e8729a", green: "#7bc47f", orange: "#e8a87c", red: "#d94f6b", cyan: "#6cc0c0", radius: 18),
    ]

    static func named(_ n: String) -> Theme { all.first { $0.name == n } ?? waveloop }
}
