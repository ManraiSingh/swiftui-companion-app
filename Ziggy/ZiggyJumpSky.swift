//
//  ZiggyJumpSky.swift
//  Ziggy
//
//  The day that passes while you play.
//
//  One run cycles morning → midday → dusk → night → morning, and every colour
//  on screen is read from here rather than being a constant. Four keyframes
//  with everything blended between them, so nothing ever snaps.
//
//  The one rule that shapes the whole palette: the interface has to stay
//  readable at both ends of the cycle. Rather than flipping the text between
//  dark and light halfway round — which always catches you out somewhere in
//  the middle — every label sits on a dark translucent chip and stays pale
//  throughout. One decision, legible at noon and at midnight.
//

import SwiftUI

struct RGB {

    let r, g, b: Double

    var color: Color { Color(red: r, green: g, blue: b) }

    static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        RGB(r: a.r + (b.r - a.r) * t,
            g: a.g + (b.g - a.g) * t,
            b: a.b + (b.b - a.b) * t)
    }
}

struct Sky {

    var top: RGB
    var mid: RGB
    var low: RGB
    var hillFar: RGB
    var hillNear: RGB
    var ground: RGB
    var edge: RGB
    /// Sun or moon — the same disc, recoloured.
    var orb: RGB
    /// 0 at noon, 1 at midnight.
    var night: Double

    static func lerp(_ a: Sky, _ b: Sky, _ t: Double) -> Sky {
        Sky(
            top: .lerp(a.top, b.top, t),
            mid: .lerp(a.mid, b.mid, t),
            low: .lerp(a.low, b.low, t),
            hillFar: .lerp(a.hillFar, b.hillFar, t),
            hillNear: .lerp(a.hillNear, b.hillNear, t),
            ground: .lerp(a.ground, b.ground, t),
            edge: .lerp(a.edge, b.edge, t),
            orb: .lerp(a.orb, b.orb, t),
            night: a.night + (b.night - a.night) * t
        )
    }

    // MARK: Keyframes

    private static let morning = Sky(
        top:      RGB(r: 0.40, g: 0.52, b: 0.80),
        mid:      RGB(r: 0.82, g: 0.64, b: 0.68),
        low:      RGB(r: 0.99, g: 0.79, b: 0.58),
        hillFar:  RGB(r: 0.52, g: 0.47, b: 0.62),
        hillNear: RGB(r: 0.32, g: 0.29, b: 0.42),
        ground:   RGB(r: 0.22, g: 0.19, b: 0.28),
        edge:     RGB(r: 0.99, g: 0.82, b: 0.62),
        orb:      RGB(r: 1.00, g: 0.86, b: 0.58),
        night: 0.18
    )

    private static let midday = Sky(
        top:      RGB(r: 0.24, g: 0.55, b: 0.92),
        mid:      RGB(r: 0.51, g: 0.75, b: 0.97),
        low:      RGB(r: 0.80, g: 0.91, b: 0.99),
        hillFar:  RGB(r: 0.40, g: 0.61, b: 0.56),
        hillNear: RGB(r: 0.21, g: 0.41, b: 0.36),
        ground:   RGB(r: 0.14, g: 0.27, b: 0.25),
        edge:     RGB(r: 0.86, g: 0.96, b: 0.92),
        orb:      RGB(r: 1.00, g: 0.98, b: 0.82),
        night: 0.0
    )

    private static let dusk = Sky(
        top:      RGB(r: 0.20, g: 0.18, b: 0.44),
        mid:      RGB(r: 0.60, g: 0.32, b: 0.47),
        low:      RGB(r: 0.98, g: 0.55, b: 0.31),
        hillFar:  RGB(r: 0.31, g: 0.23, b: 0.41),
        hillNear: RGB(r: 0.16, g: 0.13, b: 0.25),
        ground:   RGB(r: 0.11, g: 0.09, b: 0.17),
        edge:     RGB(r: 0.99, g: 0.64, b: 0.41),
        orb:      RGB(r: 1.00, g: 0.71, b: 0.40),
        night: 0.45
    )

    private static let night = Sky(
        top:      RGB(r: 0.05, g: 0.06, b: 0.16),
        mid:      RGB(r: 0.11, g: 0.12, b: 0.28),
        low:      RGB(r: 0.33, g: 0.22, b: 0.42),
        hillFar:  RGB(r: 0.15, g: 0.15, b: 0.32),
        hillNear: RGB(r: 0.08, g: 0.08, b: 0.19),
        ground:   RGB(r: 0.06, g: 0.06, b: 0.14),
        edge:     RGB(r: 0.48, g: 0.40, b: 0.70),
        orb:      RGB(r: 1.00, g: 0.97, b: 0.88),
        night: 1.0
    )

    /// Stops around the loop. The last repeats the first so it closes.
    private static let stops: [(Double, Sky)] = [
        (0.00, morning),
        (0.30, midday),
        (0.56, dusk),
        (0.80, night),
        (1.00, morning)
    ]

    /// `t` wraps, so any distance travelled maps onto the cycle.
    static func at(_ t: Double) -> Sky {

        let p = t - t.rounded(.down)

        for index in 0..<(stops.count - 1) {
            let (a, skyA) = stops[index]
            let (b, skyB) = stops[index + 1]
            if p >= a, p <= b {
                let span = b - a
                // Smoothstep, so the light doesn't change at a constant
                // machine-like rate.
                let raw = span > 0 ? (p - a) / span : 0
                return .lerp(skyA, skyB, raw * raw * (3 - 2 * raw))
            }
        }
        return morning
    }

    /// Where the sun or moon sits. Fixed, on purpose.
    ///
    /// It used to travel an arc across the sky, but something that far away
    /// should not shift relative to the viewer at all while the ground rushes
    /// past — sliding it sideways read as the sun being close by, which is
    /// the wrong impression entirely. Only its colour turns with the day.
    static let orbPosition = CGPoint(x: 0.76, y: 0.17)
}
