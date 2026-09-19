//
//  ZiggyJumpRace.swift
//  Ziggy
//
//  The course two people race down, and the machinery that guarantees they
//  are racing down the *same* one.
//
//  Solo play spawns crates as it goes, which is fine when only one person is
//  watching. A race cannot work that way: two phones rolling their own dice
//  would produce two different courses, and whoever got the kinder one would
//  win. So one player picks a seed, it goes in the shared document, and both
//  sides build the entire course from it before the countdown finishes. Same
//  seed, same crates, in the same places, every time.
//
//  It is built up front rather than streamed for the same reason. A generator
//  that consumed randomness as you played would stay in step only while both
//  players hit exactly the same obstacles in the same order — and the moment
//  one of them stumbled, the courses would silently diverge.
//

import CoreGraphics

/// SplitMix64.
///
/// Swift's own generator cannot be seeded, and a race needs the sequence to
/// be reproducible on two devices from one number. Small, fast, and — the
/// part that matters here — identical on every machine, because it is plain
/// integer arithmetic with no floating point anywhere in it.
struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // A zero seed would make SplitMix64 return a fixed sequence starting
        // from the golden-ratio constant, which is fine, but being explicit
        // costs nothing.
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct RaceLevel {

    struct Crate {
        /// Distance from the start line, not a screen position.
        let x: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    let crates: [Crate]
    /// Where the finish line stands.
    let length: CGFloat
    let seed: UInt64

    /// Constant for the whole race.
    ///
    /// Solo play speeds up as you score, but two racers with different scores
    /// would then be running at different speeds down the same course, which
    /// makes a nonsense of the finish line. Holding it flat keeps the race
    /// about who gets hit rather than who accelerated.
    static let speed: CGFloat = 400

    static let obstacleCount = 20
    /// Clear ground before the first crate, so nobody is ambushed at the gun.
    private static let runUp: CGFloat = 900
    /// Clear ground after the last, so the finish is a sprint not a scramble.
    private static let runOut: CGFloat = 800

    /// The widest obstacle a single hop clears at race speed, keeping back the
    /// same reaction margin solo play uses.
    private static func clearable(over height: CGFloat) -> CGFloat {
        let g = ZiggyJumpEngine.Tuning.gravity
        let v = ZiggyJumpEngine.Tuning.jump
        let discriminant = v * v - 2 * g * height
        guard discriminant > 0 else { return 0 }
        let secondsAbove = 2 * (discriminant).squareRoot() / g
        return (secondsAbove - ZiggyJumpEngine.Tuning.reactionMargin) * speed
            - 2 * ZiggyJumpEngine.Tuning.hitHalfWidth
    }

    static func build(seed: UInt64) -> RaceLevel {

        var rng = SeededGenerator(seed: seed)
        var crates: [Crate] = []
        var x = runUp
        var recent: [Int] = []

        let width = ZiggyJumpEngine.Tuning.crateWidth
        let shortRoom = max(1, Int(clearable(over: ZiggyJumpEngine.Tuning.shortCrate) / width))
        let middleRoom = max(1, Int(clearable(over: ZiggyJumpEngine.Tuning.middleCrate) / width))

        for step in 0..<obstacleCount {

            // 0 short, 1 middle, 2 tall. Weighted, then filtered so the same
            // kind never lands three times running — true randomness produces
            // repeats that a player reads as a pattern.
            var pool = [0, 0, 0, 1, 1, 2, 2]
            // The first few are gentle, so nobody loses the race in the first
            // three seconds to a mechanic they haven't met yet.
            if step < 3 { pool = [0] }
            if recent.count >= 2, recent[0] == recent[1] {
                let filtered = pool.filter { $0 != recent[0] }
                if !filtered.isEmpty { pool = filtered }
            }
            let kind = pool[Int.random(in: 0..<pool.count, using: &rng)]
            recent.append(kind)
            if recent.count > 2 { recent.removeFirst() }

            switch kind {

            case 0:
                let count = Int.random(in: 1...min(3, shortRoom), using: &rng)
                for slot in 0..<count {
                    crates.append(Crate(
                        x: x + CGFloat(slot) * width,
                        width: width,
                        height: ZiggyJumpEngine.Tuning.shortCrate
                    ))
                }

            case 1:
                let count = middleRoom >= 2 && Bool.random(using: &rng) ? 2 : 1
                for slot in 0..<count {
                    crates.append(Crate(
                        x: x + CGFloat(slot) * width,
                        width: width,
                        height: ZiggyJumpEngine.Tuning.middleCrate
                    ))
                }

            default:
                crates.append(Crate(
                    x: x,
                    width: width + 4,
                    height: ZiggyJumpEngine.Tuning.tallCrate
                ))
            }

            // Quoted in seconds of travel, comfortably past what a boosted hop
            // needs to land in.
            let gap = Double.random(in: 1.25...2.1, using: &rng)
            x += speed * CGFloat(gap)
        }

        return RaceLevel(crates: crates, length: x + runOut, seed: seed)
    }
}
