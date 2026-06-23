import Foundation

/// Shared cadence presets for follow-up steps (used by the detail chain + the step editor).
enum CadenceOptions {
    static let all: [(label: String, value: Double)] = [
        ("15 min", 900), ("30 min", 1800), ("1 hour", 3600), ("1.5 hours", 5400),
        ("2 hours", 7200), ("4 hours", 14400), ("8 hours", 28800),
        ("1 day", 86400), ("2 days", 172800), ("1 week", 604800),
    ]

    static func label(_ v: Double) -> String { all.first { $0.value == v }?.label ?? Format.duration(v) }
}
