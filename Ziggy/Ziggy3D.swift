//
//  Ziggy3D.swift
//  Ziggy
//
//  Ziggy as something you can walk around, rather than a picture of him.
//
//  He is built entirely out of rounded shapes — no model file, no rig — so he
//  costs nothing to ship and every part of him can be moved by code. The
//  proportions follow `ziggy_happie`: a head far bigger than the body, ears
//  that hang rather than stand, stubby legs and a tail that is mostly fluff.
//
//  Movement is the same idea as the Jump game's trot, done in three
//  dimensions: nothing is keyframed, every frame is worked out from a phase
//  and a few sine waves. That is what lets walking blend into a trick and
//  back without a seam.
//

import RealityKit
import UIKit

// MARK: - Tricks

enum Ziggy3DTrick: CaseIterable {
    case spin, flip, sit, rollOver

    var title: String {
        switch self {
        case .spin:     return "Spin"
        case .flip:     return "Flip"
        case .sit:      return "Sit"
        case .rollOver: return "Roll over"
        }
    }

    var symbol: String {
        switch self {
        case .spin:     return "arrow.trianglehead.2.clockwise.rotate.90"
        case .flip:     return "arrow.up.and.down.and.sparkles"
        case .sit:      return "pawprint.fill"
        case .rollOver: return "arrow.clockwise"
        }
    }

    /// Seconds from start to finish, standing again at the end.
    var duration: Float {
        switch self {
        case .spin:     return 1.0
        case .flip:     return 1.1
        case .sit:      return 2.2
        case .rollOver: return 1.8
        }
    }
}

// MARK: - The model

/// Ziggy in 3D. Add `root` to a scene, move and turn `root` to walk him
/// around, and call `update` every frame so he moves like he means it.
///
/// He faces +Z and his feet are at y = 0. He is about one unit tall.
@available(iOS 18.0, *)
final class Ziggy3D {

    let root = Entity()

    /// Everything above the feet. Bounces, squashes and rolls; the root only
    /// ever moves and turns, so the world never has to know about a trick.
    private let body = Entity()
    private let head = Entity()
    private let tail = Entity()
    private var ears: [Entity] = []
    private var eyes: [Entity] = []

    /// Front-left, front-right, back-left, back-right.
    private var legs: [Entity] = []

    /// Where `body` sits when nothing is happening: the middle of his tummy.
    private let bodyRest = SIMD3<Float>(0, 0.30, 0)
    private let headRest = SIMD3<Float>(0, 0.16, 0.1)

    private var clock: Float = 0
    private var stride: Float = 0
    private var walking: Float = 0

    private var trick: Ziggy3DTrick?
    private var trickTime: Float = 0

    private var nextBlink: Float = 2.5

    var isDoingTrick: Bool { trick != nil }

    init() {
        root.addChild(body)
        body.position = bodyRest
        buildBody()
        buildHead()
    }

    // MARK: Palette

    /// Taken from his drawings: creamy white fur, warm tan ears and
    /// patches, deep brown eyes, pink cheeks with two white freckles.
    private enum Paint {
        static let cream   = UIColor(0xFFF8EC)
        static let tan     = UIColor(0xF0BF84)
        static let tanLight = UIColor(0xF7D3A2)
        static let tanDeep = UIColor(0xD99A5B)
        static let eye     = UIColor(0x3A2116)
        static let iris    = UIColor(0x8A5634)
        static let nose    = UIColor(0x2E1A14)
        static let cheek   = UIColor(0xF6A0A2)
        static let mouth   = UIColor(0x8E2B35)
        static let tongue  = UIColor(0xF7848F)
        static let bean    = UIColor(0xF7A7B0)
    }

    /// A squashed sphere, for the small parts.
    private func blob(
        _ radius: Float,
        _ color: UIColor,
        at position: SIMD3<Float>,
        scale: SIMD3<Float> = .one,
        gloss: Bool = false
    ) -> ModelEntity {
        let ball = ModelEntity(
            mesh: ParkMesh.sphere(radius),
            materials: [gloss ? ParkPaint.glossy(color) : ParkPaint.soft(color, sheen: 0.6)]
        )
        ball.position = position
        ball.scale = scale
        return ball
    }

    private func smooth(_ batch: MeshBatch, _ color: UIColor) -> ModelEntity? {
        batch.entity(ParkPaint.soft(color, sheen: 0.6))
    }

    // MARK: Building

    private func buildBody() {

        // A small, soft body — much smaller than his head — longer front to
        // back, with a tan patch over the hip like in his drawings.
        body.addChild(blob(0.22, Paint.cream, at: [0, 0, -0.01], scale: [0.95, 0.82, 1.2]))
        body.addChild(blob(0.14, Paint.cream, at: [0, 0.03, 0.15], scale: [1.0, 0.95, 0.85]))
        body.addChild(blob(0.13, Paint.tan, at: [0.085, 0.08, -0.12], scale: [0.85, 0.7, 0.95]))

        // Stubby legs with round paws, toes and pink beans underneath.
        let hips: [SIMD3<Float>] = [
            [-0.11, -0.1, 0.13], [0.11, -0.1, 0.13],
            [-0.11, -0.1, -0.14], [0.11, -0.1, -0.14],
        ]
        for hip in hips {
            let leg = Entity()
            leg.position = hip
            var shape = MeshBatch()
            shape.loft([([0, 0.04, 0], 0.07, 0.072), ([0, -0.05, 0], 0.062, 0.064), ([0, -0.11, 0.008], 0.058, 0.062)], segments: 16)
            if let mesh = smooth(shape, Paint.cream) { leg.addChild(mesh) }
            leg.addChild(blob(0.062, Paint.cream, at: [0, -0.14, 0.022], scale: [1.0, 0.72, 1.15]))
            for toe: Float in [-1, 0, 1] {
                leg.addChild(blob(0.02, Paint.cream, at: [0.024 * toe, -0.15, 0.078], scale: [1, 0.85, 0.8]))
            }
            leg.addChild(blob(0.03, Paint.bean, at: [0, -0.184, 0.02], scale: [1.1, 0.3, 1.0]))
            for toe: Float in [-1, 0, 1] {
                leg.addChild(blob(0.011, Paint.bean, at: [0.022 * toe, -0.183, 0.065], scale: [1, 0.35, 1]))
            }
            body.addChild(leg)
            legs.append(leg)
        }

        // A round white pom-pom of a tail, with a hint of tan underneath.
        tail.position = [0, 0.06, -0.27]
        tail.addChild(blob(0.1, Paint.cream, at: [0, 0.06, -0.04]))
        tail.addChild(blob(0.055, Paint.tanLight, at: [0, 0.0, -0.01], scale: [1, 0.8, 1]))
        body.addChild(tail)
    }

    /// The head, sculpted as one smooth shape: wide and round, a soft muzzle
    /// below the eyes, full cheeks, a flatter chin.
    private static func skull(_ v: Float, _ u: Float) -> SIMD3<Float> {
        func g(_ a: Float) -> Float { exp(-0.5 * a * a) }
        let unit = SIMD3<Float>(sin(v) * cos(u), cos(v), sin(v) * sin(u))
        var x = unit.x * 0.37, y = unit.y * 0.31, z = unit.z * 0.33
        let front = max(0, unit.z)
        x *= 1 + 0.06 * g((y + 0.08) / 0.08) * abs(unit.x)
        if unit.y < -0.55 { y *= 0.93 }
        z += 0.035 * g(x / 0.09) * g((y + 0.06) / 0.07) * front * front
        return [x, y, z]
    }

    private func buildHead() {

        head.position = headRest
        body.addChild(head)

        // Head centre is 0.28 above the neck.
        let centre = SIMD3<Float>(0, 0.28, 0.04)
        var skull = MeshBatch()
        let rows = 30, columns = 44
        let grid: [[SIMD3<Float>]] = (0...rows).map { i in
            let v = Float(i) / Float(rows) * .pi
            return (0..<columns).map { j in centre + Self.skull(v, Float(j) / Float(columns) * 2 * .pi) }
        }
        skull.sheet(grid, closed: true, centres: (0...rows).map { i in centre + [0, cos(Float(i) / Float(rows) * .pi) * 0.15, 0] })
        if let mesh = smooth(skull, Paint.cream) { head.addChild(mesh) }

        // A little tuft on top, and tan patches where the ears join.
        head.addChild(blob(0.05, Paint.cream, at: [0.02, 0.6, -0.02], scale: [0.8, 1.0, 0.7]))
        head.addChild(blob(0.04, Paint.cream, at: [-0.04, 0.585, 0.01], scale: [0.8, 1.0, 0.7]))
        for side: Float in [-1, 1] {
            head.addChild(blob(0.15, Paint.tan, at: [0.22 * side, 0.48, -0.02], scale: [1.0, 0.6, 0.95]))
        }

        // Big floppy ears: they leave the top corners of the head and hang
        // flat against its sides, down past the cheeks — wide front to back,
        // thin side to side — lighter at the top where the light catches.
        for side: Float in [-1, 1] {
            let ear = Entity()
            ear.position = [0.28 * side, 0.47, -0.03]
            var shape = MeshBatch()
            shape.loft([([0.0, 0.02, 0.0], 0.035, 0.075),
                        ([0.05 * side, -0.07, 0.01], 0.045, 0.125),
                        ([0.08 * side, -0.19, 0.02], 0.048, 0.14),
                        ([0.085 * side, -0.31, 0.03], 0.044, 0.12),
                        ([0.078 * side, -0.38, 0.035], 0.03, 0.07)], segments: 20)
            if let mesh = smooth(shape, Paint.tan) { ear.addChild(mesh) }
            ear.addChild(blob(0.07, Paint.tanLight, at: [0.075 * side, -0.1, 0.03], scale: [0.45, 1.1, 1.2]))
            head.addChild(ear)
            ears.append(ear)
        }

        // Eyes: large and dark, a warmer brown in the lower half, a big
        // catchlight up and to the side and a small one below.
        for side: Float in [-1, 1] {
            let eye = Entity()
            eye.position = centre + [0.138 * side, -0.055, 0.29]
            eye.addChild(blob(0.076, Paint.eye, at: .zero, scale: [0.9, 1.0, 0.55], gloss: true))
            eye.addChild(blob(0.048, Paint.iris, at: [0, -0.026, 0.016], scale: [0.9, 0.65, 0.55], gloss: true))
            eye.attach(ParkMesh.sphere(0.026), ParkPaint.glow(.white), at: [0.022, 0.03, 0.038])
            eye.attach(ParkMesh.sphere(0.011), ParkPaint.glow(.white), at: [-0.026, -0.028, 0.041])
            head.addChild(eye)
            eyes.append(eye)

            // Short tan brows.
            head.addChild(blob(0.024, Paint.tanDeep, at: centre + [0.13 * side, 0.075, 0.298], scale: [1.5, 0.5, 0.4]))

            // Pink cheeks with two white freckles.
            let cheek = Entity()
            cheek.position = centre + [0.205 * side, -0.13, 0.235]
            cheek.orientation = simd_quatf(angle: 0.62 * side, axis: [0, 1, 0])
            cheek.addChild(blob(0.056, Paint.cheek, at: .zero, scale: [1.0, 0.62, 0.3]))
            cheek.attach(ParkMesh.sphere(0.009), ParkPaint.glow(.white), at: [-0.016, 0.004, 0.016])
            cheek.attach(ParkMesh.sphere(0.009), ParkPaint.glow(.white), at: [0.016, 0.004, 0.016])
            head.addChild(cheek)
        }

        // Small dark nose, and an open, happy mouth with a pink tongue.
        head.addChild(blob(0.03, Paint.nose, at: centre + [0, -0.093, 0.344], scale: [1.3, 0.85, 0.7], gloss: true))
        head.attach(ParkMesh.sphere(0.008), ParkPaint.glow(.white), at: centre + [0.01, -0.083, 0.365])
        head.addChild(blob(0.05, Paint.mouth, at: centre + [0, -0.15, 0.298], scale: [1.15, 0.8, 0.45]))
        head.addChild(blob(0.033, Paint.tongue, at: centre + [0, -0.168, 0.314], scale: [1.0, 0.6, 0.6]))
    }

    // MARK: Moving

    /// Starts a trick, unless one is already going.
    func perform(_ next: Ziggy3DTrick) {
        guard trick == nil else { return }
        trick = next
        trickTime = 0
    }

    /// Call once a frame. `speed` is how fast the root is actually moving, in
    /// units a second — the legs keep pace with the ground rather than with
    /// the joystick, so he never moonwalks.
    func update(deltaTime dt: Float, speed: Float) {

        clock += dt
        // A walking gait: long, unhurried steps. A higher rate here is what
        // made him look like he was scampering to keep up.
        stride += dt * speed * 5.2
        walking += ((speed > 0.05 ? 1 : 0) - walking) * min(1, dt * 8)

        var lift: Float = 0
        var yaw: Float = 0
        var pitch: Float = 0
        var roll: Float = 0
        var squash: Float = 1
        var sit: Float = 0
        var excitement: Float = 0

        if let current = trick {
            trickTime += dt
            let t = min(trickTime / current.duration, 1)

            switch current {

            case .spin:
                lift = 0.25 * sin(.pi * t)
                yaw = 2 * .pi * ease(t)
                excitement = 1

            case .flip:
                // Crouch, launch, a full turn forward in the air, land soft.
                if t < 0.2 {
                    squash = 1 - 0.18 * sin(.pi * t / 0.2)
                } else if t < 0.8 {
                    let air = (t - 0.2) / 0.6
                    lift = 0.75 * sin(.pi * air)
                    pitch = 2 * .pi * ease(air)
                } else {
                    squash = 1 - 0.12 * sin(.pi * (t - 0.8) / 0.2)
                }
                excitement = 1

            case .sit:
                sit = envelope(t, in: 0.15, out: 0.85)
                excitement = sit

            case .rollOver:
                // Lie down, go all the way round, get back up.
                let down = envelope(t, in: 0.15, out: 0.85)
                lift = -0.1 * down
                let turn = max(0, min(1, (t - 0.15) / 0.7))
                roll = 2 * .pi * ease(turn)
                excitement = down
            }

            if t >= 1 { trick = nil }
        }

        // Body: a bob on every step, a slow breath when standing still.
        let step = abs(sin(stride)) * 0.022 * walking
        let breath = 1 + 0.015 * sin(clock * 2.2) * (1 - walking)

        body.position = bodyRest + [0, lift + step - 0.07 * sit, -0.04 * sit]
        body.orientation =
            simd_quatf(angle: yaw, axis: [0, 1, 0])
            * simd_quatf(angle: pitch - 0.45 * sit, axis: [1, 0, 0])
            * simd_quatf(angle: roll, axis: [0, 0, 1])
        body.scale = [1 / squash.squareRoot(), squash * breath, 1 / squash.squareRoot()]

        // Diagonal pairs move together, the way a dog trots. Sitting folds the
        // back legs forward under him and straightens the front ones.
        for (index, leg) in legs.enumerated() {
            let diagonal: Float = (index == 0 || index == 3) ? 0 : .pi
            let swing = sin(stride + diagonal) * 0.48 * walking
            let fold: Float = index >= 2 ? 1.1 * sit : 0.45 * sit
            leg.orientation = simd_quatf(angle: swing + fold, axis: [1, 0, 0])
        }

        // Head: a nod on each step, a look around when idle, chin up when
        // sitting so he is looking at you.
        let nod = sin(stride * 2) * 0.035 * walking
        let lookAround = sin(clock * 0.7) * 0.25 * (1 - walking) * (1 - sit)
        head.position = headRest
        head.orientation =
            simd_quatf(angle: lookAround, axis: [0, 1, 0])
            * simd_quatf(angle: nod + 0.35 * sit, axis: [1, 0, 0])
            * simd_quatf(angle: sin(clock * 1.3) * 0.06, axis: [0, 0, 1])

        // Ears lag behind the head, so they flop rather than move with it.
        for (index, ear) in ears.enumerated() {
            let side: Float = index == 0 ? -1 : 1
            let flop = sin(stride * 2 - 0.8) * 0.25 * walking + sin(clock * 9) * 0.12 * excitement
            ear.orientation = simd_quatf(angle: side * (0.03 + flop * 0.6), axis: [0, 0, 1])
        }

        // Tail never stops. Faster when walking, frantic during a trick.
        let wagRate: Float = 7 + 6 * walking + 10 * excitement
        tail.orientation =
            simd_quatf(angle: sin(clock * wagRate) * 0.6, axis: [0, 1, 0])
            * simd_quatf(angle: -0.3, axis: [1, 0, 0])

        // Blink every few seconds.
        if clock > nextBlink + 0.14 {
            nextBlink = clock + Float.random(in: 2.5...5)
        }
        let blinking = clock > nextBlink
        for eye in eyes {
            eye.scale = [1, blinking ? 0.12 : 1, 1]
        }
    }

    // MARK: Curves

    private func ease(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }

    /// 0 → 1 over the first `inEnd` of the trick, holds, 1 → 0 after `outStart`.
    private func envelope(_ t: Float, in inEnd: Float, out outStart: Float) -> Float {
        if t < inEnd { return ease(t / inEnd) }
        if t > outStart { return ease((1 - t) / (1 - outStart)) }
        return 1
    }
}
