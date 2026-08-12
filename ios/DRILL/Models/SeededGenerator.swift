import Foundation

/// SplitMix64. Small, fast, and — the reason it is here — identical across runs
/// and OS versions, which `SystemRandomNumberGenerator` explicitly is not.
///
/// The plan must not reshuffle when he reopens the app mid-workout, so every
/// draw the generator makes has to come from a seed we control.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// Derives a stream seed from several values, so `(seed, week, day)` gives a
    /// stable per-day stream without one day's draws bleeding into the next.
    init(mixing values: UInt64...) {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for v in values {
            h = (h ^ v) &* 0x0000_0100_0000_01B3
            h ^= h >> 29
        }
        state = h
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
