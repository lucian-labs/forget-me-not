import Foundation

/// App version + build, read from the bundle (stamped at build time by run_mac.sh / deploy.sh).
/// `build` is the git commit count; `rev` is the short SHA (+ trailing "+" when the tree was
/// dirty). Shown in the list footer so both devices can be confirmed on the same build.
enum AppVersion {
    static var short: String { str("CFBundleShortVersionString") ?? "—" }
    static var build: String { str("CFBundleVersion") ?? "—" }

    /// nil unless a real revision was stamped (ignores the unresolved "$(…)" placeholder).
    static var rev: String? {
        guard let r = str("FMNBuildRev"), !r.isEmpty, !r.hasPrefix("$(") else { return nil }
        return r
    }

    /// e.g. "v2.0.0 · build 47 · a1b2c3d"
    static var footer: String {
        var s = "v\(short) · build \(build)"
        if let rev { s += " · \(rev)" }
        return s
    }

    private static func str(_ key: String) -> String? { Bundle.main.infoDictionary?[key] as? String }
}
