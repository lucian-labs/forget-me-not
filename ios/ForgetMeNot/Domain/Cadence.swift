import Foundation

/// Deterministic, seedable PRNG (SplitMix64) — usable in tests and in app code.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Cadence {
    /// Uniform in [base - less, base + more]. Missing variance → base unchanged.
    static func randomized<R: RandomNumberGenerator>(
        base: Double, more: Double?, less: Double?, using rng: inout R
    ) -> Double {
        let lo = base - (less ?? 0)
        let hi = base + (more ?? 0)
        guard hi > lo else { return base }
        return Double.random(in: lo...hi, using: &rng).rounded()
    }
}
