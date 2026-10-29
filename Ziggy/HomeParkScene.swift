//
//  HomeParkScene.swift
//  Ziggy
//
//  Ziggy's card on the home screen, out in the park.
//
//  Behind Ziggy is Hanami Park — the same park you walk in — drawn as a
//  little scene: Fuji far off, a lily pond with a torii standing in it,
//  cherry trees, a path winding off into it, and a string of paper lanterns
//  overhead. On a light theme it is a sunny afternoon, petals drifting
//  down. On a dark theme it is golden evening: the sun setting beside Fuji,
//  pink clouds, the lanterns lit. When Ziggy is asleep it is night: stars
//  and a moon on the water, fireflies. When Ziggy is sad it rains.
//
//  When your partner is out walking in the park right now, they appear as a
//  little figure on the path, so you can see them there from home.
//
//  `ParkPresence` is what knows that: it listens to the same walkers your
//  phone writes to in the park.
//

import Combine
import FirebaseFirestore
import SwiftUI

// MARK: - The scene

enum ParkTime { case day, evening, night }

struct HomeParkScene: View {

    /// Sunny afternoon, golden evening, or night.
    let time: ParkTime
    /// Ziggy is sad: rain.
    var raining = false
    /// Your partner is walking in the park right now.
    var partnerWalking = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(&context, size, t: t)
            }
        }
    }

    private var night: Bool { time == .night }
    /// Evening and night both have the lanterns lit.
    private var lit: Bool { time != .day }

    /// One colour for each time of day.
    private func tone(_ day: UInt32, _ evening: UInt32, _ night: UInt32) -> Color {
        switch time {
        case .day: Color(hex: day)
        case .evening: Color(hex: evening)
        case .night: Color(hex: night)
        }
    }

    private var sky: [Color] {
        [tone(0x9FD4F5, 0x5E4E91, 0x1B1A4A), tone(0xCDE8F7, 0xD77A9E, 0x342F78), tone(0xFFE2C6, 0xFFB37A, 0x6B57A8)]
    }

    private func draw(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        let w = size.width, h = size.height
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * w, y: y * h) }
        let horizon = 0.58

        // Sky.
        c.fill(Path(CGRect(origin: .zero, size: size)),
               with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * horizon)))

        if night {
            // Stars, each at its own steady brightness.
            for i in 0..<34 {
                let x = Self.hash(i, 1), y = Self.hash(i, 2) * 0.45
                let r = 0.6 + Self.hash(i, 4) * 1.2
                c.fill(Path(ellipseIn: CGRect(x: x * w - r, y: y * h - r, width: r * 2, height: r * 2)),
                       with: .color(.white.opacity(0.45 + 0.45 * Self.hash(i, 3))))
            }
            // A crescent moon with a soft halo.
            let moon = p(0.84, 0.14), mr = w * 0.05
            c.fill(Path(ellipseIn: CGRect(x: moon.x - mr * 2.6, y: moon.y - mr * 2.6, width: mr * 5.2, height: mr * 5.2)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3C4).opacity(0.35), .clear]), center: moon, startRadius: 0, endRadius: mr * 2.6))
            // Cut out of the full moon, rather than painted over it, so no
            // dark disc shows against the lighter sky.
            let full = Path(ellipseIn: CGRect(x: moon.x - mr, y: moon.y - mr, width: mr * 2, height: mr * 2))
            let bite = Path(ellipseIn: CGRect(x: moon.x - mr * 0.45, y: moon.y - mr * 1.15, width: mr * 2, height: mr * 2))
            c.fill(full.subtracting(bite), with: .color(Color(hex: 0xFFF6D8)))
        } else if time == .evening {
            // The first faint stars, high up where the sky has gone purple.
            for i in 0..<10 {
                let x = Self.hash(i, 1), y = Self.hash(i, 2) * 0.16
                let r = 0.5 + Self.hash(i, 4) * 0.8
                c.fill(Path(ellipseIn: CGRect(x: x * w - r, y: y * h - r, width: r * 2, height: r * 2)),
                       with: .color(.white.opacity(0.35 + 0.3 * Self.hash(i, 3))))
            }
            // The sun, big and low, going down beside Fuji.
            let sun = p(0.86, 0.5), sr = w * 0.07
            c.fill(Path(ellipseIn: CGRect(x: sun.x - sr * 4, y: sun.y - sr * 4, width: sr * 8, height: sr * 8)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFB36B).opacity(0.8), Color(hex: 0xFF8F7A).opacity(0.25), .clear]), center: sun, startRadius: 0, endRadius: sr * 4))
            c.fill(Path(ellipseIn: CGRect(x: sun.x - sr, y: sun.y - sr, width: sr * 2, height: sr * 2)),
                   with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE7A8), Color(hex: 0xFFB45E)]), startPoint: CGPoint(x: sun.x, y: sun.y - sr), endPoint: CGPoint(x: sun.x, y: sun.y + sr)))
            // Clouds lit from below.
            for (i, base) in [(0.18, 0.13), (0.55, 0.08)].enumerated() {
                let drift = (t * 0.004 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1.3) - 0.15
                cloud(&c, center: p(base.0 + drift, base.1), size: w * 0.11, colour: Color(hex: 0xFFC3A6).opacity(0.9))
            }
        } else {
            // The sun, and a couple of slow clouds.
            let sun = p(0.84, 0.15), sr = w * 0.055
            c.fill(Path(ellipseIn: CGRect(x: sun.x - sr * 3, y: sun.y - sr * 3, width: sr * 6, height: sr * 6)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF1B8).opacity(0.75), .clear]), center: sun, startRadius: 0, endRadius: sr * 3))
            c.fill(Path(ellipseIn: CGRect(x: sun.x - sr, y: sun.y - sr, width: sr * 2, height: sr * 2)), with: .color(Color(hex: 0xFFF4C9)))
            for (i, base) in [(0.18, 0.13), (0.55, 0.08)].enumerated() {
                let drift = (t * 0.004 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1.3) - 0.15
                cloud(&c, center: p(base.0 + drift, base.1), size: w * 0.11)
            }
        }

        // Mount Fuji, far off — framed in the gap between the speech
        // bubble and the top of Ziggy's head.
        let fuji = Path { f in
            f.move(to: p(0.32, horizon))
            f.addQuadCurve(to: p(0.585, 0.37), control: p(0.5, 0.45))
            f.addQuadCurve(to: p(0.655, 0.37), control: p(0.62, 0.355))
            f.addQuadCurve(to: p(0.92, horizon), control: p(0.74, 0.45))
            f.closeSubpath()
        }
        c.fill(fuji, with: .linearGradient(Gradient(colors: [tone(0x9DB1E0, 0x9A74AE, 0x4A4C86), tone(0xB9C7EA, 0x7A5F98, 0x34386A)]),
                                           startPoint: p(0, 0.37), endPoint: p(0, horizon)))
        let snow = Path { f in
            f.move(to: p(0.545, 0.405))
            f.addQuadCurve(to: p(0.585, 0.37), control: p(0.565, 0.385))
            f.addQuadCurve(to: p(0.655, 0.37), control: p(0.62, 0.355))
            f.addQuadCurve(to: p(0.695, 0.405), control: p(0.675, 0.385))
            f.addQuadCurve(to: p(0.66, 0.4), control: p(0.68, 0.41))
            f.addQuadCurve(to: p(0.62, 0.415), control: p(0.64, 0.395))
            f.addQuadCurve(to: p(0.58, 0.4), control: p(0.6, 0.395))
            f.addQuadCurve(to: p(0.545, 0.405), control: p(0.56, 0.41))
            f.closeSubpath()
        }
        c.fill(snow, with: .color(tone(0xFFFFFF, 0xFFDCCB, 0xD3D6F0)))

        // Soft rolling hills, two layers.
        hill(&c, size, through: [(-0.05, 0.53), (0.14, 0.48), (0.34, 0.54), (0.5, 0.52), (0.76, 0.55), (0.95, 0.5), (1.05, 0.52)],
             color: tone(0xC3E6A6, 0x8A7F6A, 0x2B3B66))
        hill(&c, size, through: [(-0.05, 0.57), (0.2, 0.54), (0.44, 0.58), (0.7, 0.56), (0.9, 0.58), (1.05, 0.56)],
             color: tone(0xAEDB8F, 0x667F4C, 0x24453F))

        // Grass.
        c.fill(Path(CGRect(x: 0, y: h * horizon, width: w, height: h * (1 - horizon))),
               with: .linearGradient(Gradient(colors: [tone(0xA3D884, 0x77964F, 0x214A39), tone(0x86C566, 0x51703D, 0x17322A)]),
                                     startPoint: p(0, horizon), endPoint: p(0, 1)))

        // Tufts and little flowers scattered in the grass.
        for i in 0..<16 {
            let pt = p(Self.hash(i, 20), 0.62 + Self.hash(i, 21) * 0.34)
            var tuft = Path()
            tuft.move(to: CGPoint(x: pt.x - 3, y: pt.y - 4)); tuft.addLine(to: pt); tuft.addLine(to: CGPoint(x: pt.x + 3, y: pt.y - 4))
            tuft.move(to: pt); tuft.addLine(to: CGPoint(x: pt.x, y: pt.y - 5))
            c.stroke(tuft, with: .color(tone(0x74B556, 0x587A3F, 0x2D5A46)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        let petalsColours: [Color] = switch time {
        case .day: [.white, Color(hex: 0xFFB3CB), Color(hex: 0xFFE27A)]
        case .evening: [Color(hex: 0xFFE6C8), Color(hex: 0xFF9DB8), Color(hex: 0xFFD27A)]
        case .night: [Color(hex: 0x8C93C9), Color(hex: 0xB07FA8)]
        }
        for i in 0..<22 {
            let pt = p(Self.hash(i, 22), 0.63 + Self.hash(i, 23) * 0.34)
            let r = 1.8 + Self.hash(i, 24) * 1.2
            c.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                   with: .color(petalsColours[i % petalsColours.count].opacity(night ? 0.6 : 0.95)))
            c.fill(Path(ellipseIn: CGRect(x: pt.x - 0.7, y: pt.y - 0.7, width: 1.4, height: 1.4)),
                   with: .color(night ? Color(hex: 0xE8D9A0).opacity(0.6) : Color(hex: 0xF2B33D)))
        }

        // The path, winding in from the front corner and away behind Ziggy,
        // narrowing as it goes.
        let path = Path { f in
            f.move(to: p(1.1, 1.0)); f.addCurve(to: p(0.66, 0.6), control1: p(0.74, 0.95), control2: p(0.98, 0.68))
        }
        for k in 0..<12 {
            let u = Double(k) / 12
            let piece = path.trimmedPath(from: u, to: min(1, u + 1.0 / 12 + 0.01))
            let width = w * (0.09 - 0.055 * u)
            c.stroke(piece, with: .color(tone(0xE3CA9C, 0xB58A6C, 0x394057)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        for k in 0..<12 {
            let u = Double(k) / 12
            let piece = path.trimmedPath(from: u, to: min(1, u + 1.0 / 12 + 0.01))
            let width = w * (0.075 - 0.046 * u)
            c.stroke(piece, with: .color(tone(0xF7E8C8, 0xDDB08A, 0x4B526C)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        // The pond, with its torii standing in the water.
        pond(&c, center: p(0.88, 0.67), rx: w * 0.17, ry: h * 0.06, t: t)
        torii(&c, at: p(0.95, 0.655), size: w * 0.075)

        // Your partner, out walking on the path.
        if partnerWalking {
            let bob = abs(sin(t * 5)) * 2
            let at = p(0.84, 0.86)
            walker(&c, at: CGPoint(x: at.x, y: at.y - bob), size: w * 0.022)
        }

        // A big cherry tree framing the left.
        cherry(&c, at: p(0.05, 0.66), size: w * 0.15, t: t)

        // Paper lanterns strung across the top.
        lanternString(&c, size, t: t)

        // Falling petals by day, fireflies by night.
        if night {
            for i in 0..<10 {
                let bx = Self.hash(i, 7), by = 0.5 + Self.hash(i, 8) * 0.42
                let x = bx + sin(t * 0.3 + Double(i)) * 0.03, y = by + sin(t * 0.4 + Double(i) * 2) * 0.03
                let pt = p(x, y)
                c.fill(Path(ellipseIn: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)),
                       with: .radialGradient(Gradient(colors: [Color(hex: 0xEFFF9E).opacity(0.4), .clear]), center: pt, startRadius: 0, endRadius: 6))
                c.fill(Path(ellipseIn: CGRect(x: pt.x - 1.3, y: pt.y - 1.3, width: 2.6, height: 2.6)), with: .color(Color(hex: 0xF6FFC2).opacity(0.9)))
            }
        } else {
            for i in 0..<9 {
                let fall = (t * (0.035 + Self.hash(i, 9) * 0.02) + Self.hash(i, 10)).truncatingRemainder(dividingBy: 1)
                let x = Self.hash(i, 11) + sin(t * 0.8 + Double(i)) * 0.03
                let pt = p(x, 0.18 + fall * 0.8)
                var petal = c
                petal.translateBy(x: pt.x, y: pt.y)
                petal.rotate(by: .radians(t * 1.5 + Double(i)))
                petal.fill(Path(ellipseIn: CGRect(x: -3.5, y: -2, width: 7, height: 4)), with: .color(Color(hex: 0xFFC3D6).opacity(0.9)))
            }
        }

        if raining {
            for i in 0..<38 {
                let fall = (t * 0.9 + Self.hash(i, 12)).truncatingRemainder(dividingBy: 1)
                let pt = p(Self.hash(i, 13), fall * 1.1 - 0.05)
                var drop = Path()
                drop.move(to: pt); drop.addLine(to: CGPoint(x: pt.x - 3, y: pt.y + 10))
                c.stroke(drop, with: .color(.white.opacity(night ? 0.35 : 0.55)), lineWidth: 1.2)
            }
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x3A4A6B).opacity(0.18)))
        }
    }

    // MARK: Pieces

    private func cloud(_ c: inout GraphicsContext, center: CGPoint, size s: Double, colour: Color = .white.opacity(0.92)) {
        let puffs: [(Double, Double, Double)] = [(-0.9, 0.15, 0.55), (-0.35, -0.2, 0.75), (0.3, -0.1, 0.7), (0.85, 0.15, 0.5), (0, 0.25, 0.6)]
        for (dx, dy, r) in puffs {
            c.fill(Path(ellipseIn: CGRect(x: center.x + dx * s - r * s, y: center.y + dy * s - r * s, width: r * s * 2, height: r * s * 1.6)),
                   with: .color(colour))
        }
    }


    /// A soft hill, smoothed through the given (x, y) points.
    private func hill(_ c: inout GraphicsContext, _ size: CGSize, through points: [(Double, Double)], color: Color) {
        let w = size.width, h = size.height
        let pts = points.map { CGPoint(x: $0.0 * w, y: $0.1 * h) }
        let path = Path { f in
            f.move(to: pts[0])
            for i in 1..<pts.count - 1 {
                let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
                f.addQuadCurve(to: mid, control: pts[i])
            }
            f.addLine(to: pts[pts.count - 1])
            f.addLine(to: CGPoint(x: w * 1.05, y: h * 0.64)); f.addLine(to: CGPoint(x: -w * 0.05, y: h * 0.64)); f.closeSubpath()
        }
        c.fill(path, with: .color(color))
    }

    /// A round pond: a pebble rim, the water, lily pads and a flower, and
    /// the light lying on it — the sun's glint, or the moon's reflection.
    private func pond(_ c: inout GraphicsContext, center: CGPoint, rx: Double, ry: Double, t: Double) {
        let rim = CGRect(x: center.x - rx * 1.06, y: center.y - ry * 1.12, width: rx * 2.12, height: ry * 2.3)
        c.fill(Path(ellipseIn: rim), with: .color(tone(0xEBDDBF, 0xC9A58A, 0x4E5570)))
        let water = Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
        c.fill(water, with: .linearGradient(Gradient(colors: [tone(0x5FBCE3, 0x8C78B5, 0x1A3263), tone(0x9BDDF3, 0xE8998A, 0x28498A)]),
                                            startPoint: CGPoint(x: center.x, y: center.y - ry), endPoint: CGPoint(x: center.x, y: center.y + ry)))
        var inner = c
        inner.clip(to: water)
        if night {
            // The moon's reflection, a steady pale streak.
            for k in 0..<3 {
                let wdt = rx * (0.5 - Double(k) * 0.13)
                inner.fill(Path(roundedRect: CGRect(x: center.x + rx * 0.05 - wdt / 2, y: center.y - ry * 0.45 + Double(k) * ry * 0.32, width: wdt, height: 2), cornerRadius: 1),
                           with: .color(Color(hex: 0xFFF3C4).opacity(0.55 - Double(k) * 0.12)))
            }
        } else if time == .evening {
            for k in 0..<3 {
                let wdt = rx * (0.55 - Double(k) * 0.14)
                inner.fill(Path(roundedRect: CGRect(x: center.x + rx * 0.1 - wdt / 2, y: center.y - ry * 0.45 + Double(k) * ry * 0.32, width: wdt, height: 2), cornerRadius: 1),
                           with: .color(Color(hex: 0xFFD59A).opacity(0.75 - Double(k) * 0.15)))
            }
        } else {
            for k in 0..<3 {
                let shimmer = 0.5 + 0.5 * sin(t * 1.2 + Double(k) * 2)
                inner.fill(Path(roundedRect: CGRect(x: center.x - rx * 0.55 + Double(k) * rx * 0.35, y: center.y - ry * 0.5 + Double(k % 2) * ry * 0.35, width: rx * 0.2, height: 2), cornerRadius: 1),
                           with: .color(.white.opacity(0.4 + 0.4 * shimmer)))
            }
        }
        // Lily pads, each with a little notch cut out.
        let pad = tone(0x62BE78, 0x54894F, 0x2F6A55)
        for (dx, dy, r) in [(-0.55, 0.25, 0.13), (-0.15, 0.5, 0.1), (0.35, 0.3, 0.11)] {
            let pc = CGPoint(x: center.x + dx * rx, y: center.y + dy * ry)
            let pr = rx * r
            let leaf = Path(ellipseIn: CGRect(x: pc.x - pr, y: pc.y - pr * 0.55, width: pr * 2, height: pr * 1.1))
            let notch = Path { f in f.move(to: pc); f.addLine(to: CGPoint(x: pc.x + pr * 1.2, y: pc.y - pr * 0.5)); f.addLine(to: CGPoint(x: pc.x + pr * 1.2, y: pc.y)); f.closeSubpath() }
            inner.fill(leaf.subtracting(notch), with: .color(pad))
        }
        // A water lily on the first pad.
        let flower = CGPoint(x: center.x - 0.55 * rx, y: center.y + 0.25 * ry - 2)
        for k in 0..<5 {
            let a = Double(k) / 5 * 2 * .pi
            let pt = CGPoint(x: flower.x + cos(a) * 2.6, y: flower.y + sin(a) * 1.6)
            inner.fill(Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)), with: .color(tone(0xFF9EC2, 0xFF9EC2, 0xD99BC4)))
        }
        inner.fill(Path(ellipseIn: CGRect(x: flower.x - 1.3, y: flower.y - 1.3, width: 2.6, height: 2.6)), with: .color(Color(hex: 0xFFD45E)))
    }

    private func torii(_ c: inout GraphicsContext, at base: CGPoint, size s: Double) {
        let red = tone(0xE5482F, 0xD9432E, 0xC2392E)
        let black = Color(hex: 0x2B2523)
        for side in [-0.38, 0.38] {
            c.fill(Path(CGRect(x: base.x + side * s - s * 0.05, y: base.y - s * 0.9, width: s * 0.1, height: s * 0.9)), with: .color(red))
        }
        c.fill(Path(CGRect(x: base.x - s * 0.5, y: base.y - s * 0.72, width: s, height: s * 0.08)), with: .color(red))
        let top = Path { f in
            f.move(to: CGPoint(x: base.x - s * 0.66, y: base.y - s * 0.98))
            f.addQuadCurve(to: CGPoint(x: base.x + s * 0.66, y: base.y - s * 0.98), control: CGPoint(x: base.x, y: base.y - s * 0.86))
            f.addLine(to: CGPoint(x: base.x + s * 0.6, y: base.y - s * 0.88))
            f.addQuadCurve(to: CGPoint(x: base.x - s * 0.6, y: base.y - s * 0.88), control: CGPoint(x: base.x, y: base.y - s * 0.78))
            f.closeSubpath()
        }
        c.fill(top, with: .color(black))
    }


    private func cherry(_ c: inout GraphicsContext, at base: CGPoint, size s: Double, t: Double) {
        let bark = tone(0x6E4A3A, 0x5A3A32, 0x3E2C30)
        var trunk = Path()
        trunk.move(to: CGPoint(x: base.x - s * 0.08, y: base.y))
        trunk.addLine(to: CGPoint(x: base.x - s * 0.04, y: base.y - s * 0.9))
        trunk.addLine(to: CGPoint(x: base.x + s * 0.06, y: base.y - s * 0.9))
        trunk.addLine(to: CGPoint(x: base.x + s * 0.09, y: base.y))
        trunk.closeSubpath()
        c.fill(trunk, with: .color(bark))
        let pinks: [Color] = [tone(0xF7B3CA, 0xB8678A, 0x8F4D72), tone(0xFFD3E1, 0xC97C9C, 0xB0628B), tone(0xF29BB8, 0xA3587B, 0x7A3F62)]
        let puffs: [(Double, Double, Double)] = [(-0.45, -1.0, 0.42), (0.35, -1.05, 0.45), (-0.05, -1.35, 0.5), (0.6, -1.4, 0.35), (-0.6, -1.4, 0.33), (0.1, -0.85, 0.38)]
        for (i, (dx, dy, r)) in puffs.enumerated() {
            let sway = sin(t * 0.9 + Double(i)) * s * 0.01
            c.fill(Path(ellipseIn: CGRect(x: base.x + dx * s - r * s + sway, y: base.y + dy * s - r * s, width: r * s * 2, height: r * s * 1.8)),
                   with: .color(pinks[i % pinks.count]))
        }
    }


    private func lanternString(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let a = CGPoint(x: -w * 0.02, y: h * 0.06), b = CGPoint(x: w * 1.02, y: h * 0.09)
        func point(_ u: Double) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u + sin(u * .pi) * h * 0.09)
        }
        var rope = Path()
        rope.move(to: a)
        for k in 1...30 { rope.addLine(to: point(Double(k) / 30)) }
        c.stroke(rope, with: .color(tone(0x5A4134, 0x3A2A2E, 0x15142E)), lineWidth: 1)

        let count = 7
        for k in 0..<count {
            let u = (Double(k) + 0.5) / Double(count)
            let top = point(u)
            let swing = sin(t * 1.2 + Double(k)) * 1.5
            let centre = CGPoint(x: top.x + swing, y: top.y + h * 0.045)
            let lw = w * 0.032, lh = w * 0.044
            let cream = k % 3 == 1
            if lit {
                // Lit, and staying lit — a steady glow.
                let glowColour = cream ? Color(hex: 0xFFE9B0) : Color(hex: 0xFF9A4D)
                c.fill(Path(ellipseIn: CGRect(x: centre.x - lw * 2.6, y: centre.y - lw * 2.6, width: lw * 5.2, height: lw * 5.2)),
                       with: .radialGradient(Gradient(colors: [glowColour.opacity(0.5), .clear]), center: centre, startRadius: 0, endRadius: lw * 2.6))
            }
            let paper: Color = cream
                ? (lit ? Color(hex: 0xFFF0C9) : Color(hex: 0xFBEFD8))
                : (lit ? Color(hex: 0xFFA25E) : Color(hex: 0xE8574A))
            c.fill(Path(ellipseIn: CGRect(x: centre.x - lw / 2, y: centre.y - lh / 2, width: lw, height: lh)), with: .color(paper))
            let cap = Color(hex: 0x2B2523)
            c.fill(Path(roundedRect: CGRect(x: centre.x - lw * 0.32, y: centre.y - lh / 2 - 2, width: lw * 0.64, height: 3), cornerRadius: 1), with: .color(cap))
            c.fill(Path(roundedRect: CGRect(x: centre.x - lw * 0.32, y: centre.y + lh / 2 - 1, width: lw * 0.64, height: 3), cornerRadius: 1), with: .color(cap))
        }
    }

    /// A tiny person walking, seen from afar.
    private func walker(_ c: inout GraphicsContext, at feet: CGPoint, size s: Double) {
        let body = CGRect(x: feet.x - s * 0.7, y: feet.y - s * 2.6, width: s * 1.4, height: s * 1.9)
        c.fill(Path(roundedRect: body, cornerRadius: s * 0.5), with: .color(Color(hex: 0xF7A8C2)))
        c.fill(Path(ellipseIn: CGRect(x: feet.x - s * 0.75, y: feet.y - s * 4.0, width: s * 1.5, height: s * 1.5)), with: .color(Color(hex: 0xF5D3BD)))
        c.fill(Path(ellipseIn: CGRect(x: feet.x - s * 0.8, y: feet.y - s * 4.15, width: s * 1.6, height: s * 0.9)), with: .color(Color(hex: 0x4A2E22)))
        // A little heart above them.
        let heart = Self.heart(center: CGPoint(x: feet.x, y: feet.y - s * 5.2), width: s * 1.4, height: s * 1.3)
        c.fill(heart, with: .color(Color(hex: 0xFF5C8A)))
    }

    // MARK: Helpers

    /// A heart, from the heart curve.
    static func heart(center: CGPoint, width: Double, height: Double) -> Path {
        Path { f in
            for i in 0...72 {
                let a = Double(i) / 72 * 2 * .pi
                let s = sin(a)
                let x = 16 * s * s * s
                let y = 13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a)
                let point = CGPoint(x: center.x + x / 32 * width, y: center.y - (y + 2.5) / 29 * height)
                if i == 0 { f.move(to: point) } else { f.addLine(to: point) }
            }
            f.closeSubpath()
        }
    }

    /// A fixed pseudo-random number in 0..<1, the same every frame.
    private static func hash(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return v - floor(v)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Is your partner in the park?

/// Watches the park's walkers, so home knows when your partner is out
/// walking right now — and who.
@MainActor
final class ParkPresence: ObservableObject {

    @Published private(set) var partnerName: String?

    private var listener: ListenerRegistration?
    private var timer: Timer?
    private var walkers: [String: (name: String, sentAt: Double, here: Bool)] = [:]

    func start() {
        let code = RelationshipManager.shared.relationshipCode
        guard listener == nil, !code.isEmpty else { return }
        listener = Firestore.firestore()
            .collection("relationships").document(code)
            .collection("games").document("ziggyPark")
            .collection("walkers")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot else { return }
                var walkers: [String: (name: String, sentAt: Double, here: Bool)] = [:]
                for doc in snapshot.documents {
                    let data = doc.data()
                    let t = (data["t"] as? Double) ?? (data["t"] as? NSNumber)?.doubleValue ?? 0
                    walkers[doc.documentID] = (data["name"] as? String ?? "", t, data["here"] as? Bool == true)
                }
                Task { @MainActor in
                    self?.walkers = walkers
                    self?.evaluate()
                }
            }
        // Someone who stops reporting has left, even without saying so.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        timer?.invalidate()
        timer = nil
    }

    private func evaluate() {
        let me = FirestoreManager.shared.currentDeviceID
        let now = Date().timeIntervalSince1970
        let walking = walkers.first { id, w in id != me && w.here && now - w.sentAt < 20 }
        let name = walking.map { $0.value.name.isEmpty ? "Your love" : $0.value.name }
        if name != partnerName { partnerName = name }
    }
}
