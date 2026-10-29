//
//  ZiggyParkHanami.swift
//  Ziggy
//
//  Hanami Park: the big Japanese stroll garden for a long, wandering walk.
//
//  Halfway along Sakura Canal a path turns off south into a tunnel of
//  vermilion torii gates, one after another, and comes out into a park well
//  over a hundred metres across. In the middle is a heart-shaped lake with
//  koi, lily pads and a little island shrine, and a stroll path runs right
//  round it. Off the path, each corner is its own little place:
//
//    • Koinobori Field — carp streamers flying over yellow rapeseed
//    • Sakura Grove   — big cherry trees, picnic blankets, paper lanterns
//    • Maple Valley   — red and orange maples over a dry stone stream
//    • Tea Pavilion   — a red parasol, a felt bench and a tea set
//    • Wisteria Tunnel — purple flowers hanging over a long trellis walk
//    • Fox Shrine     — a tiny shrine guarded by two fox statues
//    • Bamboo Path    — a path between tall bamboo
//    • Monkey Onsen   — a steaming hot spring among the rocks
//
//  You can walk anywhere inside the bamboo fence, not just on the paths:
//  the grass is for roaming. Animals live all over it (`ZiggyParkAnimals`).
//
//  Everything is placed from a fixed seed so both phones see the same park.
//  Each corner is built as its own group of batches, so whatever is behind
//  the camera or far away is skipped when drawing.
//

import RealityKit
import UIKit

// MARK: - Batches by colour and finish

private enum Finish: Hashable { case soft, flat, glow, glossy, clear, water }

private struct Layer: Hashable {
    let colour: UInt32
    let finish: Finish
}

/// A group of batches, one per colour and finish, that becomes one entity.
private struct Sculpture {

    var batches: [Layer: MeshBatch] = [:]

    mutating func with(_ colour: UInt32, _ finish: Finish = .soft, _ draw: (inout MeshBatch) -> Void) {
        draw(&batches[Layer(colour: colour, finish: finish), default: MeshBatch()])
    }

    func entity() -> Entity {
        let group = Entity()
        for (layer, batch) in batches {
            guard let mesh = batch.mesh() else { continue }
            let colour = UIColor(layer.colour)
            let material: any RealityKit.Material
            switch layer.finish {
            case .soft: material = ParkPaint.soft(colour, sheen: 0.35)
            case .flat: material = ParkPaint.flat(colour)
            case .glow: material = ParkPaint.glow(colour)
            case .glossy: material = ParkPaint.glossy(colour, roughness: 0.05)
            case .clear: material = ParkPaint.clear(colour, opacity: 0.45)
            case .water:
                // Clear blue rather than a mirror: shiny water only shows
                // the sky, and at golden hour that reads as grey stone.
                var water = ParkPaint.soft(colour, sheen: 0.9)
                water.roughness = .init(floatLiteral: 0.18)
                water.metallic = .init(floatLiteral: 0)
                material = water
            }
            group.addChild(ModelEntity(mesh: mesh, materials: [material]))
        }
        return group
    }
}

// MARK: - The park

@available(iOS 18.0, *)
final class ParkHanami {

    let root = Entity()

    /// Things to walk around rather than through, as (x, z, radius).
    private(set) var obstacles: [SIMD3<Float>] = []
    private(set) var blocks: [ParkBlock] = []
    private(set) var lightSpots: [SIMD3<Float>] = []
    /// Where cherry blossom and maple leaves hang, for petals and leaves to
    /// fall from.
    private(set) var blossomCrowns: [SIMD3<Float>] = []
    private(set) var mapleCrowns: [SIMD3<Float>] = []
    /// Lily pads frogs can sit on.
    private(set) var lilyPads: [SIMD3<Float>] = []
    /// Spots in the shallows, for cranes to stand.
    private(set) var shallows: [SIMD3<Float>] = []

    struct Zone {
        let name: String
        let centre: SIMD2<Float>
        let radius: Float
    }

    static let centre = SIMD2<Float>(75, 80)
    static let size = SIMD2<Float>(60, 52)
    static let gateX: Float = 48.5
    /// Where the torii tunnel comes out into the park.
    static let gateZ: Float = centre.y - size.y * (1 - pow((gateX - centre.x) / size.x, 2)).squareRoot()
    /// Where the tunnel starts, just off the canal promenade.
    static let tunnelStart: Float = 8

    static func at(_ u: Float, _ v: Float) -> SIMD2<Float> { centre + [u, v] }

    static let zones: [Zone] = [
        Zone(name: "Koinobori Field", centre: at(-40, -27), radius: 9),
        Zone(name: "Sakura Grove", centre: at(28, -30), radius: 13),
        Zone(name: "Maple Valley", centre: at(45, 6), radius: 11),
        Zone(name: "Tea Pavilion", centre: at(30, 33), radius: 7),
        Zone(name: "Wisteria Tunnel", centre: at(0, 34), radius: 9),
        Zone(name: "Fox Shrine", centre: at(-24, 40), radius: 6),
        Zone(name: "Bamboo Path", centre: at(-36, 20), radius: 9),
        Zone(name: "Monkey Onsen", centre: at(-44, -4), radius: 6),
    ]

    static let onsen = at(-45, -4)
    static let onsenRadius: Float = 2.4
    static let island = at(0, 2)
    static let islandRadius: Float = 2.6

    // MARK: The heart-shaped lake

    private static let lakeScale: Float = 1.2

    /// The lake's edge, all the way round: a heart, its point towards the
    /// way in and its two lobes beyond.
    static let lake: [SIMD2<Float>] = (0..<144).map { i in
        let a = Float(i) / 144 * 2 * .pi
        let s = sin(a)
        let hx = 16 * s * s * s
        let hy = 13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a)
        return centre + SIMD2(hx, hy + 2.5) * lakeScale
    }

    static let lakeCentre: SIMD2<Float> = lake.reduce(.zero, +) / Float(lake.count)
    private static let lakeMin: SIMD2<Float> = lake.reduce(SIMD2(repeating: .greatestFiniteMagnitude)) { simd_min($0, $1) }
    private static let lakeMax: SIMD2<Float> = lake.reduce(SIMD2(repeating: -.greatestFiniteMagnitude)) { simd_max($0, $1) }

    /// The stroll path: the heart again, further out and softened, so it
    /// is a heart-shaped walk all the way round the water.
    static let loop: [SIMD2<Float>] = {
        let n = lake.count
        var points = lake.indices.map { i -> SIMD2<Float> in
            let along = lake[(i + 1) % n] - lake[(i - 1 + n) % n]
            var normal = simd_normalize(SIMD2(along.y, -along.x))
            if simd_dot(normal, lake[i] - lakeCentre) < 0 { normal = -normal }
            return lake[i] + normal * 6
        }
        for _ in 0..<14 {
            points = points.indices.map { i in
                points[i] * 0.5 + (points[(i - 1 + n) % n] + points[(i + 1) % n]) * 0.25
            }
        }
        // Never closer to the water than a few steps.
        return points.map { p in
            let edge = nearestOnLake(p)
            if edge.inside || edge.distance < 4.5 {
                let out = edge.inside ? simd_normalize(edge.point - p) : simd_normalize(p - edge.point)
                return edge.point + out * 4.5
            }
            return p
        }
    }()

    static func inLake(_ p: SIMD2<Float>) -> Bool {
        guard p.x > lakeMin.x, p.x < lakeMax.x, p.y > lakeMin.y, p.y < lakeMax.y else { return false }
        var inside = false
        var j = lake.count - 1
        for i in lake.indices {
            let a = lake[i], b = lake[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    static func nearestOnLake(_ p: SIMD2<Float>) -> (point: SIMD2<Float>, distance: Float, inside: Bool) {
        var best = lake[0], bestDistance = Float.greatestFiniteMagnitude
        for i in lake.indices {
            let a = lake[i], b = lake[(i + 1) % lake.count]
            let ab = b - a
            let t = min(1, max(0, simd_dot(p - a, ab) / simd_length_squared(ab)))
            let q = a + ab * t
            let d = simd_distance(p, q)
            if d < bestDistance { bestDistance = d; best = q }
        }
        return (best, bestDistance, inLake(p))
    }

    /// Water anywhere in the park: the lake or the hot spring.
    static func isWater(_ p: SIMD2<Float>, margin: Float = 0) -> Bool {
        if simd_distance(p, onsen) < onsenRadius + margin { return true }
        guard p.x > lakeMin.x - margin, p.x < lakeMax.x + margin, p.y > lakeMin.y - margin, p.y < lakeMax.y + margin else { return false }
        if inLake(p) { return true }
        return margin > 0 && nearestOnLake(p).distance < margin
    }

    /// Slides anyone who walks into the water back out along its edge.
    static func keepOutOfWater(_ p: SIMD2<Float>, radius: Float) -> SIMD2<Float> {
        var p = p
        let pool = p - onsen
        let poolReach = onsenRadius + 0.4 + radius
        if simd_length(pool) < poolReach, simd_length(pool) > 0.0001 { p = onsen + simd_normalize(pool) * poolReach }

        let margin = radius + 0.35
        guard p.x > lakeMin.x - margin, p.x < lakeMax.x + margin, p.y > lakeMin.y - margin, p.y < lakeMax.y + margin else { return p }
        let edge = nearestOnLake(p)
        if edge.inside {
            let out = simd_length(edge.point - p) > 0.0001 ? simd_normalize(edge.point - p) : simd_normalize(edge.point - lakeCentre)
            return edge.point + out * margin
        }
        if edge.distance < margin, edge.distance > 0.0001 {
            return edge.point + simd_normalize(p - edge.point) * margin
        }
        return p
    }

    // MARK: Where you can walk

    static func contains(_ p: SIMD2<Float>) -> Bool {
        simd_length((p - centre) / size) < 1 || inTunnel(p)
    }

    static func inTunnel(_ p: SIMD2<Float>) -> Bool {
        abs(p.x - gateX) < 1.6 && p.y > tunnelStart && p.y < gateZ + 0.5
    }

    /// The name of the part of the park you are in, if you are in it.
    static func area(at p: SIMD2<Float>) -> String? {
        if inTunnel(p) { return "Senbon Torii" }
        guard simd_length((p - centre) / size) < 1 else { return nil }
        for zone in zones where simd_distance(p, zone.centre) < zone.radius { return zone.name }
        if simd_length((p - lakeCentre) / SIMD2(26, 25)) < 1 { return "Heart Lake" }
        return "Hanami Park"
    }

    /// For `ParkCity.keepOnFoot` to choose between: the torii tunnel, and
    /// the whole park inside its fence.
    static func walkable(_ p: SIMD2<Float>, radius: Float) -> [SIMD2<Float>] {
        let tunnel = SIMD2<Float>(min(max(p.x, gateX - 1.0 + radius), gateX + 1.0 - radius),
                                  min(max(p.y, 3.5), gateZ + 2))
        let inside = size - 1.4 - radius
        let q = (p - centre) / inside
        let length = simd_length(q)
        let park = length <= 1 || length < 0.0001 ? p : centre + q / length * inside
        return [tunnel, park]
    }

    /// Somewhere on the grass near `spot`: not in the water, not on top of
    /// a tree. For animals deciding where to wander next.
    func randomGround(near spot: SIMD2<Float>, radius: Float, rng: inout ParkRandom) -> SIMD2<Float> {
        for _ in 0..<24 {
            let a = rng.range(0, 2 * .pi), d = sqrt(rng.unit()) * radius
            let p = spot + SIMD2(cos(a), sin(a)) * d
            if simd_length((p - Self.centre) / (Self.size - 3)) > 1 { continue }
            if Self.isWater(p, margin: 0.8) { continue }
            if obstacles.contains(where: { simd_distance(SIMD2($0.x, $0.y), p) < $0.z + 0.4 }) { continue }
            return p
        }
        return spot
    }

    // MARK: Building

    private var paths: [[SIMD2<Float>]] = []
    private var groups: [(entity: Entity, centre: SIMD2<Float>, reach: Float)] = []
    private var streamers: [(entity: Entity, phase: Float)] = []
    private var steam: [(entity: Entity, phase: Float)] = []
    private var fireflies: [(entity: Entity, home: SIMD3<Float>, phase: Float)] = []
    private var clock: Float = 0
    private var nextCull: Float = 0

    init() {}

    func build(step: () async -> Void) async {
        var rng = ParkRandom(seed: 0x4A4A41)
        layOutPaths()
        buildTunnel(); await step()
        buildLakeAndPaths(&rng); await step()
        buildLanterns(&rng); await step()
        buildKoinobori(&rng); await step()
        buildSakuraGrove(&rng); await step()
        buildMapleValley(&rng); await step()
        buildTeaPavilion(); await step()
        buildWisteria(&rng); await step()
        buildFoxShrine(); await step()
        buildBamboo(&rng); await step()
        buildOnsen(&rng); await step()
        buildTrees(&rng); await step()
        buildEdges(&rng); await step()
        buildFireflies(&rng)
    }

    private func place(_ sculpture: Sculpture, centre: SIMD2<Float>, reach: Float) {
        let entity = sculpture.entity()
        root.addChild(entity)
        groups.append((entity, centre, reach))
    }

    // MARK: Paths

    private static func nearestOnLoop(_ p: SIMD2<Float>) -> SIMD2<Float> {
        loop.min { simd_distance_squared($0, p) < simd_distance_squared($1, p) } ?? p
    }

    private func layOutPaths() {
        let entrance = [SIMD2(Self.gateX, Self.gateZ - 0.5), Self.at(-24, -40), Self.at(-15, -32), Self.nearestOnLoop(Self.at(-6, -26))]
        paths.append(entrance)
        for target in [Self.at(26, -28), Self.at(42, 6), Self.at(28, 30), Self.at(0, 24), Self.at(-41, -4)] {
            paths.append([Self.nearestOnLoop(target), target])
        }
        // Through the bamboo to the fox shrine.
        paths.append([Self.nearestOnLoop(Self.at(-38, 12)), Self.at(-38, 12), Self.at(-33, 26), Self.at(-24, 37)])
        // Through the wisteria, out the far end.
        paths.append([Self.at(0, 24), Self.at(0, 46)])
        // Off the field to the koinobori.
        paths.append([Self.at(-24, -40), Self.at(-36, -28)])
    }

    private static func sample(_ line: [SIMD2<Float>], every step: Float) -> [SIMD2<Float>] {
        var out: [SIMD2<Float>] = []
        for i in 0..<(line.count - 1) {
            let a = line[i], b = line[i + 1]
            let count = max(1, Int(simd_distance(a, b) / step))
            for k in 0..<count { out.append(a + (b - a) * (Float(k) / Float(count))) }
        }
        out.append(line[line.count - 1])
        return out
    }

    private func distanceToPaths(_ p: SIMD2<Float>, includingLoop: Bool = true) -> Float {
        var best = Float.greatestFiniteMagnitude
        for line in includingLoop ? paths + [Self.loop + [Self.loop[0]]] : paths {
            for i in 0..<(line.count - 1) {
                let a = line[i], b = line[i + 1]
                let ab = b - a
                let t = min(1, max(0, simd_dot(p - a, ab) / max(0.0001, simd_length_squared(ab))))
                best = min(best, simd_distance(p, a + ab * t))
            }
        }
        return best
    }

    /// Free ground for planting: in the park, off the paths, out of the
    /// water and every corner's own space, and clear of what is already there.
    private func isFree(_ p: SIMD2<Float>, radius: Float, pathGap: Float = 2.6) -> Bool {
        if simd_length((p - Self.centre) / (Self.size - 2.5 - radius)) > 1 { return false }
        if Self.isWater(p, margin: 2.5 + radius) { return false }
        if abs(p.x - Self.gateX) < 4 + radius && p.y < Self.gateZ + 7 { return false }
        for zone in Self.zones where simd_distance(p, zone.centre) < zone.radius + radius { return false }
        if distanceToPaths(p) < pathGap + radius { return false }
        for o in obstacles where simd_distance(SIMD2(o.x, o.y), p) < o.z + radius + 0.5 { return false }
        return true
    }

    // MARK: Torii tunnel

    private func buildTunnel() {
        var s = Sculpture()
        let x = Self.gateX
        var z = Self.tunnelStart + 1
        var k = 0
        while z < Self.gateZ - 0.5 {
            let big = k == 0
            let half: Float = big ? 1.55 : 1.25
            let height: Float = big ? 3.3 : 2.75
            for side: Float in [-1, 1] {
                s.with(0x2B2523, .flat) { $0.tube(base: [x + side * half, 0, z], height: 0.28, radius: 0.15, topRadius: 0.13, segments: 10) }
                s.with(0xE8452E) { $0.tube(base: [x + side * half, 0.25, z], height: height - 0.25, radius: 0.11, topRadius: 0.1, segments: 10) }
                obstacles.append([x + side * half, z, 0.14])
            }
            s.with(0xE8452E) { $0.box([x, height - 0.45, z], [half * 2 + 0.3, 0.14, 0.12]) }
            s.with(0xE8452E) { $0.box([x, height + 0.02, z], [half * 2 + 0.7, 0.16, 0.18]) }
            s.with(0x2B2523, .flat) { $0.box([x, height + 0.15, z], [half * 2 + 0.85, 0.1, 0.22]) }
            if big {
                s.with(0x2B2523, .flat) { $0.box([x, height - 0.2, z - 0.07], [0.5, 0.42, 0.04]) }
                s.with(0xF2C14E, .soft) { $0.box([x, height - 0.2, z - 0.09], [0.42, 0.34, 0.02]) }
            }
            // A pair of paper lanterns every few gates, hung by the posts
            // either side so the way ahead stays clear, lit in the evening.
            if k % 4 == 2 {
                for side: Float in [-1, 1] {
                    let p = SIMD3<Float>(x + side * (half - 0.3), height - 0.75, z)
                    s.with(0x2B2523, .flat) {
                        $0.tube(base: p + [0, 0.18, 0], height: 0.4, radius: 0.008, segments: 4)
                        $0.tube(base: p + [0, 0.15, 0], height: 0.05, radius: 0.065, segments: 8)
                        $0.tube(base: p - [0, 0.2, 0], height: 0.05, radius: 0.065, segments: 8)
                    }
                    s.with(0xFF8A5B, .glow) { $0.blob(p, [0.12, 0.17, 0.12], rings: 6, segments: 10) }
                    lightSpots.append(p)
                }
            }
            z += big ? 1.8 : 1.3
            k += 1
        }
        // Gravel underfoot.
        let floor = Self.sample([[x, Self.tunnelStart - 3.5], [x, Self.gateZ + 0.5]], every: 0.5).map { SIMD3<Float>($0.x, 0.014, $0.y) }
        s.with(0xC9B996, .flat) { $0.ribbon(floor.map { $0 - [0, 0.004, 0] }, width: 2.9, closed: false) }
        s.with(0xEDE0C4, .flat) { $0.ribbon(floor, width: 2.5, closed: false) }
        place(s, centre: [x, (Self.tunnelStart + Self.gateZ) / 2], reach: 20)
    }

    // MARK: Lake, island and paths

    private func buildLakeAndPaths(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let middle = SIMD3<Float>(Self.lakeCentre.x, 0.03, Self.lakeCentre.y)
        let n = Self.lake.count
        for i in 0..<n {
            let a = Self.lake[i], b = Self.lake[(i + 1) % n]
            s.with(0x5CC0DE, .water) { $0.blade(middle, [b.x, 0.03, b.y], [a.x, 0.03, a.y]) }
        }
        // A sandy bank and stones round the edge.
        let bank = Self.lake.map { SIMD3<Float>($0.x, 0.016, $0.y) }
        s.with(0xD9CBA8, .flat) { $0.ribbon(bank, width: 1.4, closed: true) }
        for i in stride(from: 0, to: n, by: 1) where i % 2 == 0 {
            let p = Self.lake[i]
            let r = rng.range(0.25, 0.42)
            s.with(0xA9A39A, .flat) { $0.blob([p.x, 0.05, p.y], [r * 1.3, r * 0.5, r], turn: spin(rng.range(0, 3), [0, 1, 0]), rings: 3, segments: 6) }
        }

        // The little island, with a red shrine and a pine, and turtles'
        // sunning rocks.
        let isle = SIMD3<Float>(Self.island.x, 0, Self.island.y)
        s.with(0x8FB76A) { $0.blob(isle, [Self.islandRadius, 0.35, Self.islandRadius * 0.85], rings: 5, segments: 18) }
        s.with(0xE8452E) { $0.box(isle + [0, 0.6, 0], [0.7, 0.55, 0.6]) }
        s.with(0x3E3A3A, .flat) { $0.tube(base: isle + [0, 0.86, 0], height: 0.4, radius: 0.62, topRadius: 0, segments: 4) }
        s.with(0x5E4535, .flat) { $0.loft([(isle + [1.1, 0.2, 0.2], 0.1, 0.1), (isle + [1.3, 1.2, 0.4], 0.07, 0.07), (isle + [0.9, 1.8, 0.1], 0.05, 0.05)], segments: 6) }
        s.with(0x3F7A4A) { $0.blob(isle + [0.95, 1.85, 0.15], [0.8, 0.28, 0.65], rings: 5, segments: 10) }
        s.with(0x3F7A4A) { $0.blob(isle + [1.4, 1.35, 0.5], [0.55, 0.2, 0.45], rings: 5, segments: 10) }
        for k in 0..<4 {
            let a = Float(k) * 1.6 + 0.4
            s.with(0x9C968C, .flat) { $0.blob(isle + [cos(a) * 3.1, 0.06, sin(a) * 2.6], [0.45, 0.2, 0.35], rings: 4, segments: 8) }
        }

        // Lily pads, some with a pink lotus; frogs sit on these.
        for _ in 0..<26 {
            let a = rng.range(0, 2 * .pi), d = rng.range(5, 14)
            let p = Self.lakeCentre + SIMD2(cos(a), sin(a)) * d
            guard Self.inLake(p), Self.nearestOnLake(p).distance > 1.2, simd_distance(p, Self.island) > Self.islandRadius + 1 else { continue }
            let pad = SIMD3<Float>(p.x, 0.045, p.y)
            s.with(0x5FA05A) { $0.tube(base: pad, height: 0.01, radius: rng.range(0.28, 0.4), segments: 10) }
            if rng.unit() < 0.35 {
                s.with(0xFFB6CE) { $0.blob(pad + [0.08, 0.07, 0.05], [0.09, 0.07, 0.09], rings: 3, segments: 7) }
            } else {
                lilyPads.append(pad + [0, 0.01, 0])
            }
        }
        // Irises standing in the shallows along the west bank, and spots
        // where cranes wade.
        for i in 0..<n {
            let p = Self.lake[i]
            let inward = simd_normalize(Self.lakeCentre - p)
            if p.x < Self.lakeCentre.x - 6 && i % 3 == 0 {
                let q = p + inward * rng.range(0.6, 1.3)
                let base = SIMD3<Float>(q.x, 0.02, q.y)
                for k in 0..<3 {
                    let lean = SIMD3<Float>(rng.range(-0.08, 0.08), 0, rng.range(-0.08, 0.08))
                    s.with(0x4E8F3E) { $0.blade(base + [Float(k) * 0.05, 0, 0], base + [Float(k) * 0.05 + 0.04, 0, 0], base + lean + [0, 0.7, 0]) }
                }
                s.with(0x8E6AD8) { $0.blob(base + [0.04, 0.62, 0], [0.07, 0.09, 0.07], rings: 3, segments: 6) }
                s.with(0xFFD84D) { $0.blob(base + [0.04, 0.58, 0.05], [0.025, 0.025, 0.025], rings: 2, segments: 4) }
            }
            if i % 24 == 6 { shallows.append([p.x + inward.x * 1.4, 0.03, p.y + inward.y * 1.4]) }
        }

        // The paths: the heart-shaped walk round the water, and every way
        // off it.
        let ring = Self.loop.map { SIMD3<Float>($0.x, 0.013, $0.y) }
        s.with(0xC9B996, .flat) { $0.ribbon(ring.map { $0 - [0, 0.004, 0] }, width: 3.2, closed: true) }
        s.with(0xEDE0C4, .flat) { $0.ribbon(ring, width: 2.8, closed: true) }
        for line in paths {
            let points = Self.sample(line, every: 0.5).map { SIMD3<Float>($0.x, 0.014, $0.y) }
            s.with(0xC9B996, .flat) { $0.ribbon(points.map { $0 - [0, 0.004, 0] }, width: 2.35, closed: false) }
            s.with(0xEDE0C4, .flat) { $0.ribbon(points, width: 2.0, closed: false) }
        }
        // Stepping stones set into the grass here and there off the loop.
        for _ in 0..<40 {
            let i = Int(rng.range(0, Float(Self.loop.count - 1)))
            let p = Self.loop[i], next = Self.loop[(i + 1) % Self.loop.count]
            let side = simd_normalize(SIMD2((next - p).y, -(next - p).x)) * rng.range(2.2, 3.2) * (rng.unit() < 0.5 ? 1 : -1)
            let q = p + side
            guard !Self.isWater(q, margin: 0.8) else { continue }
            s.with(0xB8B1A6, .flat) { $0.tube(base: [q.x, 0.0, q.y], height: 0.03, radius: rng.range(0.22, 0.32), segments: 9) }
        }

        // Benches looking out over the water.
        for i in stride(from: 4, to: Self.loop.count, by: 21) {
            let p = Self.loop[i]
            let out = simd_normalize(p - Self.lakeCentre)
            let b = p + out * 2.4
            guard distanceToPaths(b, includingLoop: false) > 2.6 else { continue }
            let yaw = atan2(-out.x, -out.y)
            let turn = spin(yaw, [0, 1, 0])
            let base = SIMD3<Float>(b.x, 0, b.y)
            for k in 0..<4 { s.with(0xA27552, .flat) { $0.box(base + turn.act([0, 0.45, Float(k) * 0.11 - 0.17]), [1.5, 0.05, 0.09], yaw: yaw) } }
            for side: Float in [-0.6, 0.6] { s.with(0x5A3A2C, .flat) { $0.box(base + turn.act([side, 0.22, 0]), [0.08, 0.44, 0.42], yaw: yaw) } }
            obstacles.append([b.x, b.y, 0.75])
        }
        place(s, centre: Self.lakeCentre, reach: 40)
    }

    // MARK: Lanterns

    /// Stone lanterns round the lake, and paper lanterns strung along the
    /// walks on bamboo poles, the way the garden has them.
    private func buildLanterns(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let n = Self.loop.count

        // Kasuga lanterns on the outside of the heart-shaped walk.
        for i in stride(from: 3, to: n, by: 12) {
            let p = Self.loop[i]
            let out = simd_normalize(p - Self.lakeCentre)
            let l = p + out * 2.3
            guard distanceToPaths(l, includingLoop: false) > 2.6 else { continue }
            kasugaLantern(at: [l.x, 0, l.y], into: &s)
            obstacles.append([l.x, l.y, 0.36])
        }
        // Wide-roofed snow-viewing lanterns down on the bank, by the water.
        for i in stride(from: 10, to: n, by: 36) {
            let edge = Self.lake[i]
            let out = simd_normalize(edge - Self.lakeCentre)
            let l = edge + out * 1.1
            yukimiLantern(at: [l.x, 0, l.y], into: &s)
            obstacles.append([l.x, l.y, 0.5])
        }

        // Paper lanterns hung from a rope between bamboo poles, all along the
        // inside of the walk, dipping between each pair.
        var poles: [(top: SIMD3<Float>, index: Int)] = []
        for i in stride(from: 0, to: n, by: 7) {
            let p = Self.loop[i]
            let inward = simd_normalize(Self.lakeCentre - p)
            let base = p + inward * 1.9
            guard !Self.isWater(base, margin: 0.6) else { continue }
            s.with(0x9FB35C) { $0.tube(base: [base.x, 0, base.y], height: 2.65, radius: 0.045, topRadius: 0.038, segments: 8) }
            s.with(0x7E9147) { $0.tube(base: [base.x, 1.3, base.y], height: 0.03, radius: 0.05, segments: 8) }
            obstacles.append([base.x, base.y, 0.12])
            poles.append(([base.x, 2.6, base.y], i))
        }
        for k in 0..<poles.count {
            let a = poles[k], b = poles[(k + 1) % poles.count]
            // Not across a gap where a pole was left out, and not across
            // a path joining the walk.
            guard (b.index - a.index + n) % n <= 7 else { continue }
            let middle = (SIMD2(a.top.x, a.top.z) + SIMD2(b.top.x, b.top.z)) / 2
            guard distanceToPaths(middle, includingLoop: false) > 2.5 else { continue }
            hangLanterns(from: a.top, to: b.top, count: 3, k: k, into: &s)
        }

        // And strung right across the way in, from the tunnel to the lake.
        let entrance = Self.sample(paths[0], every: 6.5)
        for (k, p) in entrance.enumerated() where k > 0 && k < entrance.count - 1 {
            let next = entrance[k + 1]
            let side = simd_normalize(SIMD2((next - p).y, -(next - p).x)) * 2.1
            let a = SIMD3<Float>(p.x + side.x, 3.2, p.y + side.y), b = SIMD3<Float>(p.x - side.x, 3.2, p.y - side.y)
            for top in [a, b] {
                s.with(0x9FB35C) { $0.tube(base: [top.x, 0, top.z], height: 3.25, radius: 0.045, segments: 8) }
                obstacles.append([top.x, top.z, 0.12])
            }
            hangLanterns(from: a, to: b, count: 5, k: k, into: &s)
        }
        place(s, centre: Self.lakeCentre, reach: 60)
    }

    private func hangLanterns(from a: SIMD3<Float>, to b: SIMD3<Float>, count: Int, k: Int, into s: inout Sculpture) {
        var rope: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
        let sag: Float = 0.5
        for step in 0...20 {
            let t = Float(step) / 20
            rope.append((a + (b - a) * t - [0, sag * sin(t * .pi), 0], 0.008, 0.008))
        }
        s.with(0x3E342C, .flat) { $0.loft(rope, segments: 4, capped: false) }
        for j in 0..<count {
            let t = (Float(j) + 0.5) / Float(count)
            let p = a + (b - a) * t - [0, sag * sin(t * .pi) + 0.27, 0]
            // Mostly red, with a cream one now and then.
            let paper: UInt32 = (j + k) % 3 == 1 ? 0xFFE3B8 : 0xFF6B4F
            s.with(paper, .glow) { $0.blob(p, [0.14, 0.18, 0.14], rings: 7, segments: 10) }
            s.with(0x2B2523, .flat) {
                $0.tube(base: p + [0, 0.15, 0], height: 0.05, radius: 0.075, segments: 8)
                $0.tube(base: p - [0, 0.21, 0], height: 0.05, radius: 0.075, segments: 8)
                $0.tube(base: p + [0, 0.2, 0], height: 0.07, radius: 0.01, segments: 4)
            }
            // A little tassel underneath.
            s.with(0xE8452E) { $0.tube(base: p - [0, 0.36, 0], height: 0.15, radius: 0.012, topRadius: 0.02, segments: 5) }
            lightSpots.append(p)
        }
    }

    /// A Kasuga lantern: the classic tall stone lantern — a six-sided base,
    /// a slim pillar, a flared platform, a lit firebox with open windows, a
    /// roof with curled-up corners, and a jewel on top.
    private func kasugaLantern(at l: SIMD3<Float>, into s: inout Sculpture) {
        let stone: UInt32 = 0xA9A59D, dark: UInt32 = 0x8F8A82
        s.with(stone, .flat) {
            $0.tube(base: l, height: 0.1, radius: 0.36, topRadius: 0.34, segments: 6)
            $0.tube(base: l + [0, 0.1, 0], height: 0.1, radius: 0.26, topRadius: 0.13, segments: 6)
            $0.tube(base: l + [0, 0.2, 0], height: 0.72, radius: 0.09, topRadius: 0.085, segments: 8)
            $0.tube(base: l + [0, 0.92, 0], height: 0.12, radius: 0.12, topRadius: 0.3, segments: 6)
            $0.tube(base: l + [0, 1.04, 0], height: 0.05, radius: 0.3, segments: 6)
        }
        s.with(dark, .flat) { $0.tube(base: l + [0, 0.52, 0], height: 0.05, radius: 0.11, segments: 8) }
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi
            s.with(stone, .flat) { $0.box(l + [cos(a) * 0.19, 1.24, sin(a) * 0.19], [0.06, 0.34, 0.06], yaw: -a) }
        }
        s.with(0xFFD38A, .glow) { $0.tube(base: l + [0, 1.09, 0], height: 0.3, radius: 0.16, segments: 6) }
        lightSpots.append(l + [0, 1.24, 0])
        s.with(stone, .flat) {
            $0.tube(base: l + [0, 1.41, 0], height: 0.06, radius: 0.24, segments: 6)
            $0.tube(base: l + [0, 1.45, 0], height: 0.24, radius: 0.46, topRadius: 0.1, segments: 6)
            $0.tube(base: l + [0, 1.69, 0], height: 0.06, radius: 0.1, topRadius: 0.08, segments: 8)
        }
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi
            s.with(stone, .flat) { $0.blob(l + [cos(a) * 0.45, 1.5, sin(a) * 0.45], [0.05, 0.07, 0.05], rings: 3, segments: 6) }
        }
        s.with(stone, .flat) { $0.blob(l + [0, 1.8, 0], [0.07, 0.09, 0.07], rings: 5, segments: 8) }
        s.with(stone, .flat) { $0.tube(base: l + [0, 1.87, 0], height: 0.07, radius: 0.025, topRadius: 0, segments: 6) }
    }

    /// A Yukimi lantern, for snow viewing: low, on curving legs, under a
    /// wide umbrella of a roof — made to sit by water.
    private func yukimiLantern(at l: SIMD3<Float>, into s: inout Sculpture) {
        let stone: UInt32 = 0xA9A59D
        for k in 0..<3 {
            let a = Float(k) / 3 * 2 * .pi
            let foot = l + [cos(a) * 0.42, 0, sin(a) * 0.42]
            s.with(stone, .flat) {
                $0.loft([(foot, 0.05, 0.05), (l + [cos(a) * 0.36, 0.3, sin(a) * 0.36], 0.045, 0.045), (l + [cos(a) * 0.22, 0.5, sin(a) * 0.22], 0.045, 0.045)], segments: 6)
            }
        }
        s.with(stone, .flat) { $0.tube(base: l + [0, 0.48, 0], height: 0.06, radius: 0.3, segments: 6) }
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi
            s.with(stone, .flat) { $0.box(l + [cos(a) * 0.17, 0.67, sin(a) * 0.17], [0.05, 0.3, 0.05], yaw: -a) }
        }
        s.with(0xFFD38A, .glow) { $0.tube(base: l + [0, 0.54, 0], height: 0.26, radius: 0.14, segments: 6) }
        lightSpots.append(l + [0, 0.67, 0])
        s.with(stone, .flat) {
            $0.tube(base: l + [0, 0.82, 0], height: 0.2, radius: 0.72, topRadius: 0.08, segments: 6)
            $0.blob(l + [0, 1.05, 0], [0.06, 0.08, 0.06], rings: 4, segments: 7)
        }
    }

    // MARK: Koinobori Field

    private func buildKoinobori(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let zone = Self.zones[0]
        // Rapeseed in flower, yellow over green.
        for _ in 0..<26 {
            let a = rng.range(0, 2 * .pi), d = sqrt(rng.unit()) * (zone.radius - 1)
            let p = zone.centre + SIMD2(cos(a), sin(a)) * d
            guard distanceToPaths(p) > 1.6 else { continue }
            let base = SIMD3<Float>(p.x, 0, p.y)
            s.with(0x6FA052) { $0.blob(base + [0, 0.18, 0], [0.55, 0.3, 0.5], rings: 4, segments: 8) }
            for _ in 0..<10 {
                let q = base + [rng.range(-0.5, 0.5), rng.range(0.35, 0.55), rng.range(-0.45, 0.45)]
                s.with(0xFFD93D) { $0.blob(q, [0.06, 0.05, 0.06], rings: 2, segments: 5) }
            }
        }
        // Three poles flying carp: black father, red mother, blue child.
        for (k, offset) in [SIMD2<Float>(-3, -1), SIMD2<Float>(1.5, 2.5), SIMD2<Float>(3.5, -3)].enumerated() {
            let p = zone.centre + offset
            let base = SIMD3<Float>(p.x, 0, p.y)
            let height: Float = 7.5 - Float(k) * 0.6
            s.with(0xE9E2D2) { $0.tube(base: base, height: height, radius: 0.08, topRadius: 0.05, segments: 8) }
            s.with(0xF2C14E, .soft) { $0.blob(base + [0, height + 0.12, 0], [0.16, 0.16, 0.16], rings: 5, segments: 8) }
            obstacles.append([p.x, p.y, 0.15])
            let colours: [(UInt32, UInt32)] = [(0x2E3E5C, 0xF2C14E), (0xE24A5B, 0xFFE3E8), (0x4AA3DF, 0xFFFFFF)]
            for (j, colour) in colours.enumerated() {
                let carp = Entity()
                var body = MeshBatch(), belly = MeshBatch(), eye = MeshBatch(), white = MeshBatch()
                let length: Float = 2.0 - Float(j) * 0.35
                var rings: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                for s in 0...10 {
                    let t = Float(s) / 10
                    let r = (0.32 - Float(j) * 0.05) * (1 - t * 0.55) * (t < 0.1 ? 0.9 : 1)
                    rings.append(([t * length, -t * 0.25, 0], r * 0.85, r))
                }
                body.loft(rings, segments: 12, capped: false)
                belly.loft(rings.map { ($0.centre - [0, 0.04, 0], $0.rx * 0.95, $0.rz * 0.6) }, segments: 10, capped: false)
                white.blob([0.16, 0.06, 0.2], [0.09, 0.09, 0.05], rings: 4, segments: 8)
                white.blob([0.16, 0.06, -0.2], [0.09, 0.09, 0.05], rings: 4, segments: 8)
                eye.blob([0.14, 0.06, 0.25], [0.045, 0.045, 0.03], rings: 3, segments: 6)
                eye.blob([0.14, 0.06, -0.25], [0.045, 0.045, 0.03], rings: 3, segments: 6)
                if let e = body.entity(ParkPaint.soft(UIColor(colour.0), sheen: 0.4)) { carp.addChild(e) }
                if let e = belly.entity(ParkPaint.soft(UIColor(colour.1), sheen: 0.4)) { carp.addChild(e) }
                if let e = white.entity(ParkPaint.soft(.white, sheen: 0.4)) { carp.addChild(e) }
                if let e = eye.entity(ParkPaint.flat(UIColor(0x1E1E1E))) { carp.addChild(e) }
                carp.position = base + [0, height - 0.6 - Float(j) * 1.05, 0]
                root.addChild(carp)
                streamers.append((carp, Float(k) * 1.3 + Float(j) * 0.7))
            }
        }
        place(s, centre: zone.centre, reach: 30)
    }

    // MARK: Sakura Grove

    private func buildSakuraGrove(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let zone = Self.zones[1]
        var bark = MeshBatch()
        var blossom = [MeshBatch(), MeshBatch(), MeshBatch()]
        let spots: [SIMD2<Float>] = [[-8, -5], [6, -8], [9, 5], [-4, 8], [-11, 4], [2, -1]]
        for (k, offset) in spots.enumerated() {
            let p = zone.centre + offset * 0.95
            let base = SIMD3<Float>(p.x, 0, p.y)
            let crown = JapaneseTree.grow(.sakura, at: base, size: k == spots.count - 1 ? 1.55 : rng.range(1.2, 1.4),
                                          rng: &rng, bark: &bark, crowns: &blossom)
            blossomCrowns.append(crown)
            obstacles.append([p.x, p.y, 0.4])
            for _ in 0..<50 {
                let t = rng.range(0, 2 * .pi), d = rng.range(0.4, 2.8)
                let q = base + [cos(t) * d, 0.02, sin(t) * d]
                let r = rng.range(0, 3)
                s.with(0xFFC3D6) { $0.blade(q + [cos(r) * 0.05, 0, sin(r) * 0.05], q + [cos(r + 2.2) * 0.05, 0.005, sin(r + 2.2) * 0.05], q + [cos(r + 4.2) * 0.05, 0, sin(r + 4.2) * 0.05]) }
            }
        }
        s.with(0x5A4134, .flat) { $0.append(bark) }
        let shades: [UInt32] = [0xFFC6D8, 0xF7A6C0, 0xFFE4EC]
        for (i, batch) in blossom.enumerated() { s.with(shades[i]) { $0.append(batch) } }

        // Picnic blankets under the trees, with bento boxes and cups.
        for (k, offset) in [SIMD2<Float>(-2, -3), SIMD2<Float>(5, 1), SIMD2<Float>(-6, 3)].enumerated() {
            let c = zone.centre + offset
            let yaw = Float(k) * 0.7 + 0.3
            let turn = spin(yaw, [0, 1, 0])
            let base = SIMD3<Float>(c.x, 0, c.y)
            let colours: [(UInt32, UInt32)] = [(0xF26B7F, 0xFFFFFF), (0x7FB8E8, 0xFFFFFF), (0xF7C948, 0xFFFFFF)]
            for i in 0..<5 {
                for j in 0..<5 {
                    let tile = (i + j) % 2 == 0 ? colours[k].0 : colours[k].1
                    s.with(tile) { $0.box(base + turn.act([Float(i) * 0.4 - 0.8, 0.02, Float(j) * 0.4 - 0.8]), [0.4, 0.02, 0.4], yaw: yaw) }
                }
            }
            let bento = base + turn.act([0.3, 0.07, -0.2])
            s.with(0x2B2523, .flat) { $0.box(bento, [0.34, 0.1, 0.24], yaw: yaw) }
            s.with(0xE24A5B) { $0.box(bento + [0, 0.055, 0], [0.36, 0.02, 0.26], yaw: yaw) }
            for cup in 0..<2 {
                s.with(0xFFFFFF) { $0.tube(base: base + turn.act([-0.3 + Float(cup) * 0.15, 0.03, 0.35]), height: 0.08, radius: 0.04, segments: 8) }
            }
        }

        // Paper lanterns strung between bamboo poles across the grove.
        for (a, b) in [(SIMD2<Float>(-12, -9), SIMD2<Float>(0, -11)), (SIMD2<Float>(0, -11), SIMD2<Float>(12, -6)), (SIMD2<Float>(-12, 9), SIMD2<Float>(3, 11))] {
            let pa = zone.centre + a, pb = zone.centre + b
            let top: Float = 3.2
            for p in [pa, pb] {
                s.with(0x9FB35C) { $0.tube(base: [p.x, 0, p.y], height: top + 0.05, radius: 0.045, segments: 8) }
                obstacles.append([p.x, p.y, 0.1])
            }
            var line: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for k in 0...20 {
                let t = Float(k) / 20
                let q = pa + (pb - pa) * t
                line.append(([q.x, top - 0.5 * sin(t * .pi), q.y], 0.008, 0.008))
            }
            s.with(0x3E342C, .flat) { $0.loft(line, segments: 4, capped: false) }
            for k in stride(from: 2, to: 19, by: 3) {
                let p = line[k].centre - [0, 0.24, 0]
                s.with(k % 2 == 0 ? 0xFF6B4F : 0xFFB0C4, .glow) { $0.blob(p, [0.14, 0.18, 0.14], rings: 6, segments: 10) }
                s.with(0x2B2523, .flat) { $0.tube(base: p + [0, 0.16, 0], height: 0.05, radius: 0.07, segments: 8) }
                lightSpots.append(p)
            }
        }
        place(s, centre: zone.centre, reach: 38)
    }

    // MARK: Maple Valley

    private func buildMapleValley(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let zone = Self.zones[2]
        var bark = MeshBatch()
        var leaves = [MeshBatch(), MeshBatch(), MeshBatch()]
        for offset: SIMD2<Float> in [[-6, -6], [5, -7], [7, 4], [-5, 6], [0, 0]] {
            let p = zone.centre + offset
            guard distanceToPaths(p) > 2.2 || offset == .zero else { continue }
            let c = JapaneseTree.grow(.maple, at: [p.x, 0, p.y], size: rng.range(1.0, 1.2), rng: &rng, bark: &bark, crowns: &leaves)
            mapleCrowns.append(c)
            obstacles.append([p.x, p.y, 0.4])
        }
        s.with(0x5A4134, .flat) { $0.append(bark) }
        let shades: [UInt32] = [0xE0492E, 0xF2763A, 0xBF3426]
        for (i, batch) in leaves.enumerated() { s.with(shades[i]) { $0.append(batch) } }

        // A dry stream of raked white pebbles winding through, with a stone
        // slab across it where the path goes over.
        var stream: [SIMD3<Float>] = []
        for k in 0...30 {
            let t = Float(k) / 30
            let p = zone.centre + SIMD2(-10 + t * 20, sin(t * 5) * 2.5 + 2)
            stream.append([p.x, 0.012, p.y])
        }
        s.with(0xF4F1EA, .flat) { $0.ribbon(stream, width: 1.6, closed: false) }
        for (k, p) in stream.enumerated() where k % 2 == 0 {
            for side: Float in [-0.9, 0.9] {
                s.with(0x9C968C, .flat) { $0.blob(p + [rng.range(-0.2, 0.2), 0.04, side + rng.range(-0.1, 0.1)], [0.22, 0.12, 0.18], rings: 3, segments: 6) }
            }
        }
        // Fallen leaves on the grass.
        for _ in 0..<160 {
            let a = rng.range(0, 2 * .pi), d = sqrt(rng.unit()) * zone.radius
            let p = zone.centre + SIMD2(cos(a), sin(a)) * d
            let q = SIMD3<Float>(p.x, 0.02, p.y)
            let r = rng.range(0, 3)
            s.with(rng.unit() < 0.5 ? 0xE0492E : 0xF2A03A) {
                $0.blade(q + [cos(r) * 0.06, 0, sin(r) * 0.06], q + [cos(r + 2.1) * 0.06, 0.004, sin(r + 2.1) * 0.06], q + [cos(r + 4.2) * 0.06, 0, sin(r + 4.2) * 0.06])
            }
        }
        place(s, centre: zone.centre, reach: 30)
    }

    // MARK: Tea Pavilion

    private func buildTeaPavilion() {
        var s = Sculpture()
        let zone = Self.zones[3]
        let c = SIMD3<Float>(zone.centre.x, 0, zone.centre.y)
        // An open pavilion: a raised wooden floor, four posts, a dark roof.
        s.with(0xB08A62, .flat) { $0.box(c + [0, 0.12, 0], [4.2, 0.24, 4.2]) }
        for x: Float in [-1.9, 1.9] {
            for z: Float in [-1.9, 1.9] {
                s.with(0x6B4A33, .flat) { $0.tube(base: c + [x, 0.24, z], height: 2.3, radius: 0.09, segments: 8) }
                obstacles.append([c.x + x, c.z + z, 0.14])
            }
        }
        s.with(0x3E3A3A, .flat) { $0.tube(base: c + [0, 2.5, 0], height: 1.4, radius: 3.4, topRadius: 0.1, segments: 4) }
        s.with(0x6B4A33, .flat) { $0.box(c + [0, 2.5, 0], [4.4, 0.12, 4.4]) }
        // Red felt bench and a tea set on a tray.
        s.with(0xD8402E) { $0.box(c + [0, 0.48, 0.9], [2.6, 0.08, 0.8]) }
        s.with(0x6B4A33, .flat) { $0.box(c + [0, 0.36, 0.9], [2.4, 0.18, 0.6]) }
        s.with(0x2B2523, .flat) { $0.box(c + [0.4, 0.54, 0.9], [0.5, 0.03, 0.32]) }
        s.with(0x4E7A4E) { $0.blob(c + [0.3, 0.62, 0.9], [0.09, 0.08, 0.09], rings: 5, segments: 8) }
        for k in 0..<2 { s.with(0xF4EFE6) { $0.tube(base: c + [0.5 + Float(k) * 0.1, 0.56, 0.95], height: 0.06, radius: 0.035, segments: 8) } }
        // The big red parasol beside it.
        let u = c + [3.2, 0, -1.2]
        s.with(0x6B4A33, .flat) { $0.tube(base: u, height: 2.6, radius: 0.04, segments: 6) }
        s.with(0xE24A3B) {
            $0.tube(base: u + [0, 2.35, 0], height: 0.55, radius: 2.0, topRadius: 0.05, segments: 20)
            $0.blob(u + [0, 2.35, 0], [2.0, 0.08, 2.0], rings: 3, segments: 20)
        }
        obstacles.append([u.x, u.z, 0.1])
        blocks.append(ParkBlock(centre: zone.centre, half: [2.0, 2.0], height: 0.25))
        // Stepping stones up to it.
        for k in 0..<5 {
            s.with(0xB8B1A6, .flat) { $0.tube(base: c + [-2.4 - Float(k) * 0.7, 0, -2.4 - Float(k) * 0.5], height: 0.04, radius: 0.28, segments: 9) }
        }
        lightSpots.append(c + [0, 2.2, 0])
        place(s, centre: zone.centre, reach: 26)
    }

    // MARK: Wisteria Tunnel

    private func buildWisteria(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let x = Self.centre.x
        let purples: [UInt32] = [0xB79CF5, 0x9C7FE0, 0xD9C8FF, 0xFFFFFF]
        var z = Self.centre.y + 25
        while z < Self.centre.y + 45 {
            for side: Float in [-1.7, 1.7] {
                s.with(0x7A5640, .flat) { $0.tube(base: [x + side, 0, z], height: 2.7, radius: 0.08, segments: 8) }
                obstacles.append([x + side, z, 0.12])
            }
            var arch: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for k in 0...14 {
                let t = Float(k) / 14 * .pi
                arch.append(([x + cos(t) * 1.7, 2.7 + sin(t) * 0.7, z], 0.06, 0.06))
            }
            s.with(0x7A5640, .flat) { $0.loft(arch, segments: 6) }
            // Leaves along the top, and flowers hanging down in long trails.
            for k in 0..<10 {
                let t = Float(k) / 9 * .pi
                let top = SIMD3<Float>(x + cos(t) * 1.75, 2.75 + sin(t) * 0.7, z + rng.range(-0.6, 0.6))
                s.with(0x6FA052) { $0.blob(top + [0, 0.1, 0], [0.38, 0.2, 0.5], rings: 4, segments: 7) }
                // A trail of blossom hanging down like a bunch of grapes,
                // fat at the top and tapering away.
                let length = rng.range(0.5, 0.95)
                let shade = purples[Int(rng.range(0, 3.99))]
                for k in 0..<5 {
                    let t = Float(k) / 4
                    let r = 0.12 * (1 - t * 0.65)
                    let p = top - [0, 0.05 + t * length, 0] + [rng.range(-0.02, 0.02), 0, rng.range(-0.02, 0.02)]
                    s.with(shade) { $0.blob(p, [r, r * 1.1, r], rings: 3, segments: 6) }
                }
            }
            z += 2.2
        }
        // Hydrangeas either side.
        for _ in 0..<22 {
            let side: Float = rng.unit() < 0.5 ? -1 : 1
            let p = SIMD3<Float>(x + side * rng.range(3, 5.5), 0, Self.centre.y + rng.range(25, 44))
            s.with(0x5E9548) { $0.blob(p + [0, 0.3, 0], [0.55, 0.4, 0.55], rings: 4, segments: 8) }
            let shade: UInt32 = [0x8FB8F2, 0xC6A4F2, 0xF7A8C8][Int(rng.range(0, 2.99))]
            for _ in 0..<5 {
                let q = p + [rng.range(-0.4, 0.4), rng.range(0.5, 0.72), rng.range(-0.4, 0.4)]
                s.with(shade) { $0.blob(q, [0.16, 0.13, 0.16], rings: 3, segments: 6) }
            }
            obstacles.append([p.x, p.z, 0.5])
        }
        place(s, centre: [x, Self.centre.y + 35], reach: 30)
    }

    // MARK: Fox Shrine

    private func buildFoxShrine() {
        var s = Sculpture()
        let zone = Self.zones[5]
        let c = SIMD3<Float>(zone.centre.x, 0, zone.centre.y)
        // A small torii, then the shrine on a stone base.
        let gate = c + [0, 0, -3]
        for side: Float in [-1.0, 1.0] {
            s.with(0xE8452E) { $0.tube(base: gate + [side, 0, 0], height: 2.2, radius: 0.09, segments: 8) }
            obstacles.append([gate.x + side, gate.z, 0.12])
        }
        s.with(0xE8452E) { $0.box(gate + [0, 1.85, 0], [2.4, 0.1, 0.1]) }
        s.with(0x2B2523, .flat) { $0.box(gate + [0, 2.25, 0], [2.8, 0.12, 0.16]) }
        s.with(0xA9A59D, .flat) { $0.box(c + [0, 0.2, 1], [2.2, 0.4, 1.8]) }
        s.with(0xF4EFE6) { $0.box(c + [0, 0.85, 1], [1.4, 0.9, 1.1]) }
        s.with(0xE8452E) { $0.box(c + [0, 0.85, 0.42], [1.42, 0.92, 0.06]) }
        s.with(0x3E3A3A, .flat) { $0.tube(base: c + [0, 1.3, 1], height: 0.8, radius: 1.3, topRadius: 0.05, segments: 4) }
        blocks.append(ParkBlock(centre: [c.x, c.z + 1], half: [1.1, 0.9], height: 2.1))
        // Two white fox statues with red bibs, one each side.
        for side: Float in [-1.6, 1.6] {
            let f = c + [side, 0, -0.4]
            s.with(0xA9A59D, .flat) { $0.box(f + [0, 0.25, 0], [0.6, 0.5, 0.6]) }
            s.with(0xF7F4EE) {
                $0.blob(f + [0, 0.75, 0], [0.18, 0.28, 0.2], rings: 6, segments: 10)
                $0.blob(f + [0, 1.08, -0.05], [0.14, 0.13, 0.15], rings: 6, segments: 10)
                $0.tube(base: f + [0, 1.08, -0.15], height: 0.14, radius: 0.07, topRadius: 0.02, lean: spin(-.pi / 2, [1, 0, 0]), segments: 6)
                $0.tube(base: f + [-0.07, 1.16, -0.03], height: 0.13, radius: 0.04, topRadius: 0, segments: 5)
                $0.tube(base: f + [0.07, 1.16, -0.03], height: 0.13, radius: 0.04, topRadius: 0, segments: 5)
                $0.blob(f + [side * 0.12, 0.7, 0.18], [0.07, 0.22, 0.07], turn: spin(side * 0.5, [0, 0, 1]), rings: 4, segments: 6)
            }
            s.with(0xE24A3B) { $0.blob(f + [0, 0.88, -0.12], [0.15, 0.08, 0.06], rings: 3, segments: 8) }
            obstacles.append([f.x, f.z, 0.4])
        }
        kasugaLantern(at: c + [-2.6, 0, 1.4], into: &s)
        kasugaLantern(at: c + [2.6, 0, 1.4], into: &s)
        obstacles += [[c.x - 2.6, c.z + 1.4, 0.3], [c.x + 2.6, c.z + 1.4, 0.3]]
        place(s, centre: zone.centre, reach: 24)
    }

    // MARK: Bamboo Path

    private func buildBamboo(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let zone = Self.zones[6]
        let corridor = Self.sample([Self.at(-38, 12), Self.at(-33, 26), Self.at(-24, 37)], every: 0.6)
        var placed = 0, tries = 0
        while placed < 150 && tries < 3000 {
            tries += 1
            let k = Int(rng.range(0, Float(corridor.count - 1)))
            let p = corridor[k], next = corridor[min(k + 1, corridor.count - 1)]
            let along = next - p
            guard simd_length(along) > 0.01 else { continue }
            let side = simd_normalize(SIMD2(along.y, -along.x)) * (rng.unit() < 0.5 ? 1 : -1)
            let q = p + side * rng.range(1.8, 6)
            if Self.isWater(q, margin: 1) { continue }
            let base = SIMD3<Float>(q.x, 0, q.y)
            let height = rng.range(5, 8)
            let radius = rng.range(0.045, 0.07)
            let lean = spin(rng.range(-0.06, 0.06), [1, 0, 0]) * spin(rng.range(-0.06, 0.06), [0, 0, 1])
            s.with(0x8DB04F) { $0.tube(base: base, height: height, radius: radius, topRadius: radius * 0.75, lean: lean, segments: 6) }
            var y: Float = 0.5
            while y < height {
                s.with(0xB2C46A) { $0.tube(base: base + lean.act([0, y, 0]), height: 0.03, radius: radius * 1.12, lean: lean, segments: 6) }
                y += rng.range(0.9, 1.2)
            }
            for _ in 0..<6 {
                let top = base + lean.act([0, rng.range(height * 0.6, height), 0])
                let dir = rng.range(0, 2 * .pi)
                let out = SIMD3<Float>(cos(dir), -0.35, sin(dir))
                let across = SIMD3<Float>(-sin(dir), 0, cos(dir)) * 0.035
                s.with(rng.unit() < 0.5 ? 0x5E953E : 0x86B54E) { $0.blade(top - across, top + across, top + out * 0.42) }
            }
            obstacles.append([q.x, q.y, 0.12])
            placed += 1
        }
        place(s, centre: zone.centre, reach: 34)
    }

    // MARK: Monkey Onsen

    private func buildOnsen(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let c = SIMD3<Float>(Self.onsen.x, 0, Self.onsen.y)
        s.with(0xA8EEF5, .water) { $0.tube(base: c + [0, 0.02, 0], height: 0.06, radius: Self.onsenRadius, segments: 28) }
        for k in 0..<22 {
            let a = Float(k) / 22 * 2 * .pi
            let r = rng.range(0.35, 0.55)
            s.with(k % 3 == 0 ? 0x8A847B : 0xA49E95, .flat) {
                $0.blob(c + [cos(a) * (Self.onsenRadius + 0.3), r * 0.5, sin(a) * (Self.onsenRadius + 0.3)], [r * 1.2, r * 0.75, r], turn: spin(a, [0, 1, 0]), rings: 4, segments: 7)
            }
        }
        // Wooden pails and a little sign post.
        let pail = c + [Self.onsenRadius + 1.3, 0, 0.6]
        s.with(0xC79A5E, .flat) {
            $0.tube(base: pail, height: 0.22, radius: 0.16, topRadius: 0.19, segments: 10)
            $0.tube(base: pail + [0, 0.22, 0], height: 0.22, radius: 0.15, topRadius: 0.18, segments: 10)
        }
        s.with(0x7A5640, .flat) { $0.tube(base: c + [-Self.onsenRadius - 1.2, 0, -0.5], height: 1.3, radius: 0.05, segments: 6) }
        s.with(0xF4EFE6) { $0.box(c + [-Self.onsenRadius - 1.2, 1.2, -0.5], [0.7, 0.4, 0.05]) }
        s.with(0xE24A5B) { $0.blob(c + [-Self.onsenRadius - 1.2, 1.2, -0.53], [0.1, 0.1, 0.02], rings: 3, segments: 8) }
        obstacles += [[pail.x, pail.z, 0.25], [c.x - Self.onsenRadius - 1.2, c.z - 0.5, 0.1]]
        place(s, centre: Self.onsen, reach: 22)

        // Soft, matte wisps: shiny ones look like soap bubbles.
        for k in 0..<10 {
            let puff = ModelEntity(mesh: ParkMesh.sphere(0.3), materials: [ParkPaint.clear(UIColor(0xFFFFFF), opacity: 0.16, roughness: 1)])
            puff.position = c
            root.addChild(puff)
            steam.append((puff, Float(k) / 10 * 3))
        }
    }

    // MARK: Trees all over

    private func buildTrees(_ rng: inout ParkRandom) {
        var s = Sculpture()
        var placed = 0, tries = 0
        while placed < 70 && tries < 6000 {
            tries += 1
            let a = rng.range(0, 2 * .pi), d = sqrt(rng.unit())
            let p = Self.centre + SIMD2(cos(a), sin(a)) * Self.size * d
            let size = rng.range(0.9, 1.35)
            guard isFree(p, radius: 1.6 * size, pathGap: 3.2) else { continue }
            let base = SIMD3<Float>(p.x, 0, p.y)
            let kind = rng.unit()
            if kind < 0.22 {
                // Japanese pine with cloud-pruned pads.
                let twist = rng.range(0, 6)
                var trunk: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                for k in 0...8 {
                    let t = Float(k) / 8
                    trunk.append((base + [sin(t * 3 + twist) * 0.35 * t, t * 2.6 * size, cos(t * 2 + twist) * 0.25 * t], 0.17 * (1 - t * 0.55) * size, 0.17 * (1 - t * 0.55) * size))
                }
                s.with(0x5E4535, .flat) { $0.loft(trunk, segments: 8) }
                let top = trunk[trunk.count - 1].centre
                for k in 0..<4 {
                    let d = Float(k) / 4 * 2 * .pi + rng.range(0, 1)
                    let end = base + [cos(d) * rng.range(0.8, 1.4) * size, rng.range(1.4, 2.3) * size, sin(d) * rng.range(0.8, 1.4) * size]
                    s.with(0x5E4535, .flat) { $0.loft([(top - [0, 0.6, 0], 0.07, 0.07), (end, 0.04, 0.04)], segments: 5) }
                    s.with(0x3F7A4A) { $0.blob(end + [0, 0.08, 0], [0.72 * size, 0.24 * size, 0.6 * size], turn: spin(d, [0, 1, 0]), rings: 5, segments: 10) }
                }
                s.with(0x3F7A4A) { $0.blob(top + [0, 0.15, 0], [0.85 * size, 0.3 * size, 0.75 * size], rings: 5, segments: 10) }
                obstacles.append([p.x, p.y, 0.4 * size])
            } else {
                // A soft, round crown: cherry pink, maple red, or green.
                let palette: [UInt32]
                if kind < 0.55 { palette = [0xFFC6D8, 0xF7A6C0, 0xFFE4EC] }
                else if kind < 0.7 { palette = [0xE0492E, 0xF2763A, 0xF7A23A] }
                else { palette = [0x6DB35A, 0x86C46A, 0x58A04F] }
                let height = rng.range(1.5, 2.0) * size
                s.with(0x6B4A33, .flat) { $0.tube(base: base, height: height + 0.4 * size, radius: 0.16 * size, topRadius: 0.1 * size, segments: 8) }
                for _ in 0..<2 {
                    let d = rng.range(0, 2 * .pi)
                    let tip = base + [cos(d) * 0.7 * size, height * 0.95, sin(d) * 0.7 * size]
                    s.with(0x6B4A33, .flat) { $0.loft([(base + [0, height * 0.6, 0], 0.07 * size, 0.07 * size), (tip, 0.04, 0.04)], segments: 5) }
                }
                let top = base + [0, height + 0.8 * size, 0]
                let puffs = Int(rng.range(4, 6.99))
                for k in 0..<puffs {
                    let d = Float(k) / Float(puffs) * 2 * .pi + rng.range(0, 1)
                    let offset = k == 0 ? SIMD3<Float>(0, 0.3, 0) * size : SIMD3<Float>(cos(d) * 0.65, rng.range(-0.3, 0.15), sin(d) * 0.65) * size
                    let r = rng.range(0.6, 0.85) * size
                    s.with(palette[k % 3]) { $0.blob(top + offset, [r, r * 0.88, r], rings: 5, segments: 8) }
                }
                if kind < 0.55 { blossomCrowns.append(top) } else if kind < 0.7 { mapleCrowns.append(top) }
                obstacles.append([p.x, p.y, 0.3 * size])
            }
            placed += 1
        }
        // Azalea mounds and grass tufts in the gaps.
        var count = 0
        tries = 0
        while count < 60 && tries < 3000 {
            tries += 1
            let a = rng.range(0, 2 * .pi), d = sqrt(rng.unit())
            let p = Self.centre + SIMD2(cos(a), sin(a)) * Self.size * d
            guard isFree(p, radius: 0.6, pathGap: 1.8) else { continue }
            let base = SIMD3<Float>(p.x, 0, p.y)
            let size = rng.range(0.4, 0.65)
            let colour: UInt32 = [0xF48FB1, 0xE04E8A, 0xFFFFFF][count % 3]
            s.with(0x5E9548) { $0.blob(base + [0, size * 0.45, 0], [size * 1.25, size * 0.7, size], rings: 5, segments: 9) }
            for _ in 0..<8 {
                let dir = simd_normalize(SIMD3<Float>(rng.range(-1, 1), rng.range(0.2, 1), rng.range(-1, 1)))
                s.with(colour) { $0.blob(base + [0, size * 0.45, 0] + dir * [size * 1.2, size * 0.68, size], [0.06, 0.04, 0.06], rings: 2, segments: 5) }
            }
            obstacles.append([p.x, p.y, size])
            count += 1
        }
        for _ in 0..<500 {
            let a = rng.range(0, 2 * .pi), d = sqrt(rng.unit())
            let p = Self.centre + SIMD2(cos(a), sin(a)) * (Self.size - 2) * d
            guard !Self.isWater(p, margin: 0.5), distanceToPaths(p) > 1.6 else { continue }
            let q = SIMD3<Float>(p.x, 0, p.y)
            if rng.unit() < 0.6 {
                for _ in 0..<3 {
                    let tip = q + [rng.range(-0.08, 0.08), rng.range(0.18, 0.32), rng.range(-0.08, 0.08)]
                    let r = rng.range(0, 3)
                    s.with(0x5E953E) { $0.blade(q + [cos(r) * 0.03, 0, sin(r) * 0.03], q - [cos(r) * 0.03, 0, sin(r) * 0.03], tip) }
                }
            } else {
                let colour: UInt32 = [0xFFFFFF, 0xFFE070, 0xCDB2FF, 0xFFB3C7][Int(rng.range(0, 3.99))]
                s.with(colour) { $0.blob(q + [0, 0.07, 0], [0.045, 0.03, 0.045], rings: 2, segments: 4) }
            }
        }
        place(s, centre: Self.centre, reach: 80)
    }

    // MARK: Fence, woods and hills round the outside

    private func buildEdges(_ rng: inout ParkRandom) {
        var s = Sculpture()
        let fence = Self.size + 0.6
        let count = 520
        for i in 0..<count {
            let a = Float(i) / Float(count) * 2 * .pi
            let p = Self.centre + SIMD2(cos(a), sin(a)) * fence
            if abs(p.x - Self.gateX) < 2.2 && p.y < Self.centre.y { continue }
            s.with(0xC4B37A) { $0.tube(base: [p.x, 0, p.y], height: i % 6 == 0 ? 1.2 : 1.0, radius: i % 6 == 0 ? 0.05 : 0.03, segments: 5) }
        }
        let gateAngle = atan2((Self.gateZ - Self.centre.y) / fence.y, (Self.gateX - Self.centre.x) / fence.x)
        let gap: Float = 0.045
        for height: Float in [0.3, 0.65, 0.92] {
            var ring: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for k in 0...140 {
                let a = gateAngle + gap + Float(k) / 140 * (2 * .pi - 2 * gap)
                let p = Self.centre + SIMD2(cos(a), sin(a)) * (fence + 0.05)
                ring.append(([p.x, height, p.y], 0.025, 0.025))
            }
            s.with(0x9C8A55) { $0.loft(ring, segments: 5, capped: false) }
        }
        // Tall cedars and round trees just outside, so the park sits in its
        // own wood.
        for i in 0..<110 {
            let a = Float(i) / 110 * 2 * .pi + rng.range(-0.02, 0.02)
            let p = Self.centre + SIMD2(cos(a), sin(a)) * Self.size * rng.range(1.06, 1.22)
            if p.y < 22 { continue }
            // Nothing standing in the way out of the torii tunnel.
            if abs(p.x - Self.gateX) < 7 && p.y < Self.centre.y { continue }
            let base = SIMD3<Float>(p.x, 0, p.y)
            if i % 3 == 0 {
                let r = rng.range(1.6, 2.4)
                s.with(0x6B4A33, .flat) { $0.tube(base: base, height: 1.6, radius: 0.18, segments: 6) }
                s.with(0x5E9E4F) { $0.blob(base + [0, 1.6 + r * 0.8, 0], [r, r * 0.9, r], rings: 6, segments: 9) }
            } else {
                let h = rng.range(7, 10)
                s.with(0x6B4A33, .flat) { $0.tube(base: base, height: 1.4, radius: 0.16, segments: 6) }
                s.with(0x2F6B45) { $0.tube(base: base + [0, 1.2, 0], height: h * 0.55, radius: 1.5, topRadius: 0.7, segments: 8) }
                s.with(0x2F6B45) { $0.tube(base: base + [0, 1.2 + h * 0.5, 0], height: h * 0.5, radius: 1.1, topRadius: 0, segments: 8) }
            }
        }
        // Soft hills on the far side.
        for i in 0..<14 {
            let a = Float(i) / 14 * .pi * 1.3 - 0.15
            let d = rng.range(1.45, 1.7)
            let p = Self.centre + SIMD2(cos(a), sin(a)) * Self.size * d
            let w = rng.range(16, 26)
            s.with(i % 2 == 0 ? 0x86B868 : 0x9EBC8C) { $0.blob([p.x, -2, p.y], [w, rng.range(7, 12), w * 0.75], turn: spin(-a, [0, 1, 0]), rings: 8, segments: 14) }
        }
        place(s, centre: Self.centre, reach: 400)
    }

    // MARK: Fireflies

    private func buildFireflies(_ rng: inout ParkRandom) {
        let glow = ParkPaint.glow(UIColor(0xF6FF9E))
        let homes = [Self.zones[4].centre, Self.zones[5].centre, Self.zones[6].centre, Self.zones[2].centre, Self.lakeCentre + [-18, 10]]
        for k in 0..<36 {
            let home = homes[k % homes.count] + [rng.range(-6, 6), rng.range(-6, 6)]
            let fly = ModelEntity(mesh: ParkMesh.sphere(0.035), materials: [glow])
            let at = SIMD3<Float>(home.x, rng.range(0.4, 1.8), home.y)
            fly.position = at
            fly.isEnabled = false
            root.addChild(fly)
            fireflies.append((fly, at, rng.range(0, 6)))
        }
    }

    // MARK: Every frame

    func update(deltaTime dt: Float, viewer: SIMD3<Float>, night: Float) {
        clock += dt
        let here = SIMD2(viewer.x, viewer.z)

        // Skip whole corners of the park that are far out of sight.
        nextCull -= dt
        if nextCull <= 0 {
            nextCull = 0.4
            for group in groups {
                // Far enough off that the trees between hide it anyway.
                let show = simd_distance(here, group.centre) < group.reach + 40
                if group.entity.isEnabled != show { group.entity.isEnabled = show }
            }
        }
        let near = simd_distance(here, Self.centre) < 110
        guard near else { return }

        // Carp streamers swim in the breeze.
        for (carp, phase) in streamers {
            let gust = sin(clock * 0.7 + phase) * 0.5 + 0.5
            carp.orientation = spin(0.6 + sin(clock * 0.3 + phase * 0.2) * 0.25, [0, 1, 0])
                * spin(-0.15 - (1 - gust) * 0.55, [0, 0, 1])
                * spin(sin(clock * 3.2 + phase) * 0.12, [0, 1, 0])
        }

        // Steam drifting up off the hot spring.
        let pool = SIMD3<Float>(Self.onsen.x, 0, Self.onsen.y)
        for (puff, phase) in steam {
            let t = (clock * 0.35 + phase).truncatingRemainder(dividingBy: 3) / 3
            puff.position = pool + [sin(phase * 4) * 1.3 + sin(clock * 0.6 + phase) * 0.3, 0.15 + t * 1.8, cos(phase * 3) * 1.2]
            puff.scale = .init(repeating: (0.5 + t * 1.1) * sin(t * .pi))
        }

        let lit = night > 0.25
        for (fly, home, phase) in fireflies {
            let show = lit && simd_distance_squared(home, viewer) < 35 * 35
            if fly.isEnabled != show { fly.isEnabled = show }
            guard show else { continue }
            fly.position = home + [sin(clock * 0.5 + phase) * 1.4, sin(clock * 0.8 + phase * 2) * 0.4, cos(clock * 0.4 + phase) * 1.4]
            fly.scale = .init(repeating: max(0.15, sin(clock * 2.4 + phase * 3)) * night)
        }
    }
}
