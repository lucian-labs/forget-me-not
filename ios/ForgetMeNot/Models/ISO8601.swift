import Foundation

/// JSON coders matching the web app's format: ISO-8601 UTC with millisecond
/// precision and a trailing `Z`, exactly like JavaScript `Date.toISOString()`.
enum FMNJSON {
    // nonisolated(unsafe): formatter is write-once at init, never mutated after —
    // safe under Swift 6 strict concurrency without MainActor pinning.
    private nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(formatter.string(from: date))
        }
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            guard let date = formatter.date(from: s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath,
                    debugDescription: "Bad ISO-8601 date: \(s)"))
            }
            return date
        }
        return d
    }()
}
