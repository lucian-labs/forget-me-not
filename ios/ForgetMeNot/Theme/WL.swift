import SwiftUI

/// Design tokens adapted from ~/waveloop: dark indigo, monospaced + uppercase,
/// square (no rounded corners), 1pt translucent borders, teal accent, no shadows.
enum WL {
    // Surfaces
    static let bg      = Color(red: 0.063, green: 0.063, blue: 0.110)   // #10101c
    static let surface = Color(red: 0.082, green: 0.098, blue: 0.145)   // panel indigo
    static let border  = Color.white.opacity(0.10)
    static let line    = Color(red: 0.220, green: 0.235, blue: 0.290)   // #383c4a

    // Text
    static let text    = Color(red: 0.918, green: 0.925, blue: 0.949)   // #eaecf2
    static let muted   = Color(red: 0.667, green: 0.686, blue: 0.741)   // #aaafbd

    // Accents
    static let accent  = Color(red: 0.180, green: 0.780, blue: 0.722)   // teal #2ec7b8
    static let cyan    = Color(red: 0.420, green: 0.902, blue: 0.878)   // #6be6e0
    static let gold    = Color(red: 1.000, green: 0.643, blue: 0.039)   // #ffa40a
    static let green   = Color(red: 0.302, green: 0.800, blue: 0.471)   // mint #4dcc78
    static let red     = Color(red: 0.922, green: 0.251, blue: 0.302)   // #eb404d

    /// Monospaced is the waveloop signature. (Micro 5 bitmap font could be bundled
    /// later for the full look; system monospaced carries the aesthetic for now.)
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Urgency tier → palette color (calm green, soon gold, due/overdue red).
    static func urgencyColor(_ tier: UrgencyTier) -> Color {
        switch tier {
        case .calm: green
        case .soon: gold
        case .due, .overdue: red
        }
    }
}
