//
//  ZiggyParkFun.swift
//  Ziggy
//
//  Surprise me: little bits of magic to set off on the walk.
//
//  Tap the present and the park picks one — confetti, fireworks, a cloud of
//  bubbles, a rainbow, hearts drifting down, sky lanterns floating up, a
//  present for Ziggy to find, or Ziggy getting the zoomies and racing round
//  you in circles. Your partner's phone plays the same surprise in the same
//  spot, so you both see it together.
//
//  Everything here is drawn from a small pool of pieces made once and
//  switched off between surprises, so a surprise costs nothing when it is
//  not playing.
//

import RealityKit
import UIKit

enum ParkSurprise: String, CaseIterable {
    case confetti, fireworks, bubbles, rainbow, hearts, lanterns, present, zoomies

    var title: String {
        switch self {
        case .confetti:  return "Confetti!"
        case .fireworks: return "Fireworks!"
        case .bubbles:   return "Bubbles!"
        case .rainbow:   return "A rainbow!"
        case .hearts:    return "Raining hearts!"
        case .lanterns:  return "Sky lanterns!"
        case .present:   return "A present for Ziggy!"
        case .zoomies:   return "Ziggy has the zoomies!"
        }
    }

    var symbol: String {
        switch self {
        case .confetti:  return "party.popper.fill"
        case .fireworks: return "sparkles"
        case .bubbles:   return "bubbles.and.sparkles.fill"
        case .rainbow:   return "rainbow"
        case .hearts:    return "heart.fill"
        case .lanterns:  return "lamp.table.fill"
        case .present:   return "gift.fill"
        case .zoomies:   return "hare.fill"
        }
    }
}

@available(iOS 18.0, *)
final class ParkFun {

    let root = Entity()

    private enum Kind { case confetti, spark, bubble, heart, lantern }

    private struct Bit {
        let entity: ModelEntity
        let kind: Kind
        var velocity: SIMD3<Float> = .zero
        var spin: Float = 0
        var age: Float = 0
        var life: Float = 0
        var size: Float = 1
        var live = false
    }

    private struct Burst {
        var delay: Float
        let position: SIMD3<Float>
        let colours: [Int]
    }

    private var bits: [Bit] = []
    private var bursts: [Burst] = []
    private var rainbow: Entity?
    private var rainbowAge: Float = -1
    private var present: Entity?
    private var lid: Entity?
    private var presentAge: Float = -1
    private var bigHeartEntity: Entity?
    private var bigHeartAge: Float = -1
    private var bigHeartStart: SIMD3<Float> = .zero

    /// Called when the present pops open, so Ziggy can jump for joy.
    var onPresentOpened: (() -> Void)?

    private static let colours: [UInt32] = [0xFF5C7C, 0xFFD25A, 0x7FD1F0, 0xA6E07A, 0xC6A4F2, 0xFF9A5C, 0xFFFFFF]
    private lazy var glows = Self.colours.map { ParkPaint.glow(UIColor($0)) }

    var isPlaying: Bool { bits.contains { $0.live } || !bursts.isEmpty || rainbowAge >= 0 || presentAge >= 0 }

    // MARK: Setting one off

    /// Plays a surprise around `centre` (where whoever asked for it is
    /// standing), with `facing` the way they were looking.
    func play(_ surprise: ParkSurprise, at centre: SIMD3<Float>, facing: Float) {
        let ahead = SIMD3<Float>(-sin(facing), 0, -cos(facing))
        switch surprise {
        case .confetti:
            confetti(from: centre + [0, 2.6, 0], count: 90)
        case .fireworks:
            for k in 0..<5 {
                let side = SIMD3<Float>(ahead.z, 0, -ahead.x) * Float.random(in: -9...9)
                let spot = centre + ahead * Float.random(in: 16...24) + side + [0, Float.random(in: 11...17), 0]
                bursts.append(Burst(delay: Float(k) * 0.55, position: spot, colours: [Int.random(in: 0..<6), Int.random(in: 0..<7)]))
            }
        case .bubbles:
            for _ in 0..<34 {
                let a = Float.random(in: 0...(2 * .pi)), d = Float.random(in: 0.4...2.6)
                spawn(.bubble, at: centre + [cos(a) * d, Float.random(in: 0.2...1.2), sin(a) * d],
                      velocity: [Float.random(in: -0.1...0.1), Float.random(in: 0.35...0.7), Float.random(in: -0.1...0.1)],
                      life: Float.random(in: 3.5...6), size: Float.random(in: 0.6...1.4))
            }
        case .rainbow:
            showRainbow(at: centre + ahead * 34 - [0, 1, 0], facing: facing)
        case .hearts:
            for _ in 0..<44 {
                let a = Float.random(in: 0...(2 * .pi)), d = Float.random(in: 0...3.5)
                spawn(.heart, at: centre + [cos(a) * d, Float.random(in: 3...6), sin(a) * d],
                      velocity: [0, -Float.random(in: 0.45...0.8), 0], life: 6, size: Float.random(in: 0.7...1.3))
            }
        case .lanterns:
            for _ in 0..<16 {
                let a = Float.random(in: 0...(2 * .pi)), d = Float.random(in: 1...5)
                spawn(.lantern, at: centre + [cos(a) * d, Float.random(in: 0.3...1.5), sin(a) * d],
                      velocity: [Float.random(in: -0.1...0.1), Float.random(in: 0.5...0.9), Float.random(in: -0.1...0.1)],
                      life: Float.random(in: 14...18), size: Float.random(in: 0.8...1.2))
            }
        case .present:
            showPresent(at: centre + ahead * 1.6, facing: facing)
        case .zoomies:
            // Ziggy does this one himself; a little confetti to start him off.
            confetti(from: centre + [0, 1.2, 0], count: 24)
        }
    }

    /// A little puff of hearts, for saying hello to an animal.
    func hearts(at spot: SIMD3<Float>, count: Int) {
        for _ in 0..<count {
            spawn(.heart, at: spot + [Float.random(in: -0.1...0.1), 0, Float.random(in: -0.1...0.1)],
                  velocity: [Float.random(in: -0.25...0.25), Float.random(in: 0.5...0.9), Float.random(in: -0.25...0.25)],
                  life: 2.2, size: Float.random(in: 0.45...0.8))
        }
    }

    /// A perfect heart outline, flat like a sticker: traced from the heart
    /// curve itself rather than built out of balls, so its lobes are round,
    /// its dip is crisp and its point is sharp. Always turned to face you.
    private lazy var stickerHeart: MeshResource? = {
        var shape = MeshBatch()
        let scale: Float = 0.0075
        let middle = SIMD3<Float>(0, -1.5 * scale, 0)
        let count = 120
        var edge: [SIMD3<Float>] = []
        for i in 0..<count {
            let a = Float(i) / Float(count) * 2 * .pi
            let s = sin(a)
            let x = 16 * s * s * s
            let y = 13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a)
            edge.append(SIMD3<Float>(x, y + 2.5, 0) * scale)
        }
        for i in 0..<count { shape.blade(middle, edge[i], edge[(i + 1) % count]) }
        return shape.mesh()
    }()

    /// A big heart that pops up over someone's head, beats twice and
    /// floats away.
    func bigHeart(at spot: SIMD3<Float>) {
        if bigHeartEntity == nil, let stickerHeart {
            let heart = Entity()
            // A white border round a pink heart, and a little shine.
            heart.attach(stickerHeart, ParkPaint.glow(UIColor(0xFFFFFF)), at: [0, -0.004, -0.004], scale: [1.16, 1.16, 1])
            heart.attach(stickerHeart, ParkPaint.glow(UIColor(0xFF5C7C)))
            heart.attach(stickerHeart, ParkPaint.glow(UIColor(0xFF8FAB)), at: [0, 0.008, 0.002], scale: [0.78, 0.74, 1])
            heart.attach(ParkMesh.sphere(0.018), ParkPaint.glow(UIColor(0xFFE3EA)), at: [-0.05, 0.045, 0.004], scale: [1, 1.4, 0.1],
                         turn: spin(0.5, [0, 0, 1]))
            heart.components.set(BillboardComponent())
            root.addChild(heart)
            bigHeartEntity = heart
        }
        bigHeartEntity?.position = spot
        bigHeartEntity?.isEnabled = true
        bigHeartAge = 0
        bigHeartStart = spot
    }

    /// A little shower of confetti over someone's head.
    func sprinkle(at spot: SIMD3<Float>) {
        confetti(from: spot, count: 26)
    }

    /// Confetti and hearts together.
    func celebrate(at spot: SIMD3<Float>) {
        confetti(from: spot + [0, 0.6, 0], count: 50)
        hearts(at: spot, count: 10)
    }

    // MARK: Pieces

    private func spawn(_ kind: Kind, at position: SIMD3<Float>, velocity: SIMD3<Float>, life: Float, size: Float = 1, colour: Int? = nil) {
        var index = bits.firstIndex { !$0.live && $0.kind == kind }
        if index == nil {
            guard bits.count < 360, let entity = make(kind) else { return }
            root.addChild(entity)
            bits.append(Bit(entity: entity, kind: kind))
            index = bits.count - 1
        }
        guard let i = index else { return }
        bits[i].live = true
        bits[i].age = 0
        bits[i].life = life
        bits[i].size = size
        bits[i].velocity = velocity
        bits[i].spin = Float.random(in: -8...8)
        let entity = bits[i].entity
        entity.position = position
        entity.scale = .init(repeating: size)
        entity.orientation = spin(Float.random(in: 0...6), simd_normalize([Float.random(in: -1...1), 1, Float.random(in: -1...1)]))
        if kind == .confetti || kind == .spark {
            entity.model?.materials = [glows[colour ?? Int.random(in: 0..<glows.count)]]
        }
        entity.isEnabled = true
    }

    private func make(_ kind: Kind) -> ModelEntity? {
        switch kind {
        case .confetti:
            return ModelEntity(mesh: ParkMesh.box([0.07, 0.004, 0.04]), materials: [glows[0]])
        case .spark:
            return ModelEntity(mesh: ParkMesh.sphere(0.12), materials: [glows[0]])
        case .bubble:
            let bubble = ModelEntity(mesh: ParkMesh.sphere(0.13), materials: [ParkPaint.clear(UIColor(0xDDF3FF), opacity: 0.32)])
            bubble.attach(ParkMesh.sphere(0.03), ParkPaint.glow(.white), at: [-0.05, 0.06, 0.08])
            return bubble
        case .heart:
            // The same sticker heart as the big one, small, always facing you.
            guard let stickerHeart else { return nil }
            let heart = ModelEntity(mesh: stickerHeart, materials: [ParkPaint.glow(UIColor([0xFF5C7C, 0xFF8FAB, 0xFFB3C7].randomElement()!))])
            heart.attach(stickerHeart, ParkPaint.glow(.white), at: [0, -0.003, -0.003], scale: [1.18, 1.18, 1])
            heart.components.set(BillboardComponent())
            heart.scale = .init(repeating: 0.55)
            return heart
        case .lantern:
            var paper = MeshBatch()
            paper.tube(base: [0, 0, 0], height: 0.42, radius: 0.15, topRadius: 0.2, segments: 10)
            guard let mesh = paper.mesh() else { return nil }
            let lantern = ModelEntity(mesh: mesh, materials: [ParkPaint.glow(UIColor(0xFFB25C))])
            lantern.attach(ParkMesh.sphere(0.07), ParkPaint.glow(UIColor(0xFFF1B0)), at: [0, 0.06, 0])
            return lantern
        }
    }

    private func confetti(from top: SIMD3<Float>, count: Int) {
        for _ in 0..<count {
            let a = Float.random(in: 0...(2 * .pi)), out = Float.random(in: 0.6...2.6)
            spawn(.confetti, at: top, velocity: [cos(a) * out, Float.random(in: 1.5...4), sin(a) * out], life: Float.random(in: 3...4.5))
        }
    }

    private func showRainbow(at spot: SIMD3<Float>, facing: Float) {
        if rainbow == nil {
            let arc = Entity()
            let bands: [UInt32] = [0xFF6B6B, 0xFFA94D, 0xFFE066, 0x8CE99A, 0x74C0FC, 0xB197FC]
            for (k, colour) in bands.enumerated() {
                let r = 16 - Float(k) * 0.9
                var band = MeshBatch()
                var ring: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                for s in 0...48 {
                    let t = Float(s) / 48 * .pi
                    ring.append(([cos(t) * r, sin(t) * r, 0], 0.46, 0.08))
                }
                band.loft(ring, segments: 6, capped: false)
                if let e = band.entity(ParkPaint.clear(UIColor(colour), opacity: 0.75)) { arc.addChild(e) }
            }
            for side: Float in [-1, 1] {
                for _ in 0..<5 {
                    arc.attach(ParkMesh.sphere(1.0), ParkPaint.glow(UIColor(0xFFF4F7)),
                               at: [side * 13.7 + Float.random(in: -1.8...1.8), Float.random(in: 0...1.4), Float.random(in: -1...1)],
                               scale: [2.3, 1.4, 1.8])
                }
            }
            root.addChild(arc)
            rainbow = arc
        }
        rainbow?.position = spot
        rainbow?.orientation = spin(facing, [0, 1, 0])
        rainbow?.scale = .init(repeating: 0.001)
        rainbow?.isEnabled = true
        rainbowAge = 0
    }

    private func showPresent(at spot: SIMD3<Float>, facing: Float) {
        if present == nil {
            let box = Entity()
            box.attach(ParkMesh.box([0.42, 0.36, 0.42]), ParkPaint.soft(UIColor(0xFF7A93), sheen: 0.5), at: [0, 0.18, 0])
            box.attach(ParkMesh.box([0.44, 0.37, 0.08]), ParkPaint.soft(UIColor(0xFFE07A), sheen: 0.5), at: [0, 0.18, 0])
            box.attach(ParkMesh.box([0.08, 0.37, 0.44]), ParkPaint.soft(UIColor(0xFFE07A), sheen: 0.5), at: [0, 0.18, 0])
            let top = Entity()
            top.attach(ParkMesh.box([0.47, 0.1, 0.47]), ParkPaint.soft(UIColor(0xFF7A93), sheen: 0.5))
            top.attach(ParkMesh.sphere(0.07), ParkPaint.soft(UIColor(0xFFE07A), sheen: 0.5), at: [-0.07, 0.08, 0], scale: [1.3, 0.8, 0.6])
            top.attach(ParkMesh.sphere(0.07), ParkPaint.soft(UIColor(0xFFE07A), sheen: 0.5), at: [0.07, 0.08, 0], scale: [1.3, 0.8, 0.6])
            box.addChild(top)
            root.addChild(box)
            present = box
            lid = top
        }
        present?.position = spot
        present?.orientation = spin(facing, [0, 1, 0])
        present?.isEnabled = true
        lid?.position = [0, 0.41, 0]
        lid?.orientation = spin(0, [0, 1, 0])
        presentAge = 0
    }

    // MARK: Every frame

    func update(deltaTime dt: Float) {
        for i in bursts.indices.reversed() {
            bursts[i].delay -= dt
            guard bursts[i].delay <= 0 else { continue }
            let burst = bursts.remove(at: i)
            for k in 0..<44 {
                let dir = simd_normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)))
                spawn(.spark, at: burst.position, velocity: dir * Float.random(in: 4...6.5), life: Float.random(in: 1.3...1.9),
                      size: Float.random(in: 0.8...1.3), colour: burst.colours[k % burst.colours.count])
            }
        }

        for i in bits.indices where bits[i].live {
            bits[i].age += dt
            var b = bits[i]
            if b.age > b.life {
                bits[i].live = false
                b.entity.isEnabled = false
                continue
            }
            let t = b.age / b.life
            switch b.kind {
            case .confetti:
                b.velocity.y -= 3.2 * dt
                b.velocity *= 1 - min(1, dt * 1.6)
                b.velocity.y = max(b.velocity.y, -0.9)
                b.entity.position += b.velocity * dt + [sin(b.age * 7 + b.spin) * dt * 0.4, 0, 0]
                b.entity.orientation = b.entity.orientation * spin(b.spin * dt, [1, 0.3, 0])
                b.entity.scale = .init(repeating: b.size * min(1, (1 - t) * 4))
            case .spark:
                b.velocity *= 1 - min(1, dt * 1.4)
                b.velocity.y -= 2 * dt
                b.entity.position += b.velocity * dt
                b.entity.scale = .init(repeating: b.size * (1 - t))
            case .bubble:
                b.entity.position += (b.velocity + [sin(b.age * 2.5 + b.spin) * 0.15, 0, 0]) * dt
                // Pop: swell for a moment at the very end, then gone.
                let pop: Float = t > 0.94 ? 1 + (t - 0.94) * 8 : min(1, b.age * 3)
                b.entity.scale = .init(repeating: b.size * pop)
            case .heart:
                b.entity.position += (b.velocity + [sin(b.age * 2 + b.spin) * 0.3, 0, 0]) * dt
                if b.entity.position.y < 0.15 { b.velocity = .zero }
                b.entity.scale = .init(repeating: 0.55 * b.size * min(1, b.age * 3) * min(1, (1 - t) * 5))
            case .lantern:
                b.entity.position += (b.velocity + [sin(b.age * 0.7 + b.spin) * 0.12, 0, 0]) * dt
                b.entity.scale = .init(repeating: b.size * min(1, b.age * 2) * min(1, (1 - t) * 6))
            }
            bits[i] = b
        }

        if bigHeartAge >= 0, let heart = bigHeartEntity {
            bigHeartAge += dt
            let t = bigHeartAge
            // Pops in with a little overshoot, beats twice, drifts up and
            // shrinks away.
            let pop = t < 0.35 ? sin(t / 0.35 * .pi * 0.75) / sin(.pi * 0.75) * (1 + 0.15 * sin(t / 0.35 * .pi)) : 1
            let beat = t > 0.4 && t < 1.4 ? 1 + 0.12 * max(0, sin((t - 0.4) * 2 * .pi * 2)) : 1
            let fade = t > 2.0 ? max(0, 1 - (t - 2.0) / 0.4) : 1
            heart.scale = .init(repeating: max(0.001, 1.7 * pop * beat * fade))
            heart.position = bigHeartStart + [0, t * 0.18, 0]
            if t > 2.4 { heart.isEnabled = false; bigHeartAge = -1 }
        }

        if rainbowAge >= 0, let rainbow {
            rainbowAge += dt
            let grow = min(1, rainbowAge / 1.5)
            let shrink = rainbowAge > 8 ? max(0, 1 - (rainbowAge - 8) / 1.5) : 1
            rainbow.scale = .init(repeating: max(0.001, grow * grow * (3 - 2 * grow) * shrink))
            if rainbowAge > 9.5 { rainbow.isEnabled = false; rainbowAge = -1 }
        }

        if presentAge >= 0, let present, let lid {
            presentAge += dt
            // Drops in with a bounce, wiggles, then the lid flies off.
            let drop = min(1, presentAge / 0.5)
            present.scale = .init(repeating: drop < 1 ? drop * (1.2 - 0.2 * drop) : 1)
            if presentAge > 0.6 && presentAge < 1.6 {
                present.orientation = present.orientation * spin(sin(presentAge * 30) * dt * 2, [0, 0, 1])
            }
            if presentAge > 1.6 {
                let t = presentAge - 1.6
                if t - dt <= 0 {
                    confetti(from: present.position + [0, 0.5, 0], count: 70)
                    for _ in 0..<12 {
                        spawn(.heart, at: present.position + [0, 0.5, 0],
                              velocity: [Float.random(in: -0.5...0.5), Float.random(in: 0.6...1.2), Float.random(in: -0.5...0.5)], life: 3)
                    }
                    onPresentOpened?()
                }
                lid.position = [0, 0.41 + t * 2.4 - t * t * 2, t * 0.6]
                lid.orientation = spin(t * 5, [1, 0, 0])
            }
            if presentAge > 4.5 {
                let fade = max(0.001, 1 - (presentAge - 4.5) / 0.5)
                present.scale = .init(repeating: fade)
            }
            if presentAge > 5 { present.isEnabled = false; presentAge = -1 }
        }
    }
}
