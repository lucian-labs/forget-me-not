import Foundation

func formatTime(_ seconds: Double) -> String {
    let abs = abs(seconds)
    if abs < 60 { return "\(Int(abs))s" }
    if abs < 3600 { return "\(Int(abs / 60))m" }
    if abs < 86400 {
        let h = Int(abs / 3600)
        let m = Int(abs.truncatingRemainder(dividingBy: 3600) / 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    let d = Int(abs / 86400)
    let h = Int(abs.truncatingRemainder(dividingBy: 86400) / 3600)
    return h > 0 ? "\(d)d \(h)h" : "\(d)d"
}

func formatCadence(_ seconds: Double) -> String {
    let map: [Double: String] = [
        900: "15m", 1800: "30m", 3600: "1h", 5400: "1.5h",
        7200: "2h", 14400: "4h", 28800: "8h", 86400: "1d",
        172800: "2d", 604800: "1w",
    ]
    return map[seconds] ?? formatTime(seconds)
}

func timeAgo(_ date: Date) -> String {
    let diff = Date().timeIntervalSince(date)
    if diff < 60 { return "just now" }
    if diff < 3600 { return "\(Int(diff / 60))m ago" }
    if diff < 86400 { return "\(Int(diff / 3600))h ago" }
    return "\(Int(diff / 86400))d ago"
}

let cadenceOptions: [(label: String, value: Double)] = [
    ("15 min", 900), ("30 min", 1800), ("1 hour", 3600),
    ("1.5 hours", 5400), ("2 hours", 7200), ("4 hours", 14400),
    ("8 hours", 28800), ("1 day", 86400), ("2 days", 172800),
    ("1 week", 604800),
]
