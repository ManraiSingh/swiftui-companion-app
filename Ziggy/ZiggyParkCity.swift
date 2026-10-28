//
//  ZiggyParkCity.swift
//  Ziggy
//
//  Everything past the garden gate: the long walk out into town.
//
//  Leave the garden by its east gate and you are on Sakura Canal, a wide
//  paved promenade under cherry trees with a canal running alongside —
//  little red bridges over the water, benches facing it, stone lanterns,
//  paper lanterns strung overhead. At the far end an arch welcomes you to
//  Ziggy Town: a street of shops and houses with their windows lit for the
//  evening, telephone wires sagging between poles, zebra crossings, vending
//  machines glowing on the pavement, a café with tables out. The street
//  opens onto Fountain Plaza, and behind it a Ferris wheel turns slowly
//  against the sunset.
//
//  The whole walk, garden gate to plaza, is about a hundred and seventy
//  metres. Like the garden, it is built from a fixed seed so both phones
//  see the same town, and almost everything is batched by colour.
//

import RealityKit
import UIKit

@available(iOS 18.0, *)
final class ParkCity {

    let root = Entity()

    /// Things to walk around rather than through, as (x, z, radius).
    private(set) var obstacles: [SIMD3<Float>] = []

    /// Buildings, solid to the camera.
    private(set) var blocks: [ParkBlock] = []

    /// Every lamp and lantern, for their glow at night.
    private(set) var lightSpots: [SIMD3<Float>] = []

    /// Where cherry trees out here hold their blossom, so petals can fall
    /// from them too.
    private(set) var blossomCrowns: [SIMD3<Float>] = []

    // The route, west to east.
    static let gardenGate: Float = 22.6
    static let avenueStart: Float = 23
    static let avenueEnd: Float = 72
    static let streetEnd: Float = 138
    static let plaza = SIMD2<Float>(150, 0)
    static let plazaRadius: Float = 14

    private let wheel = Entity()
    private var gondolas: [Entity] = []
    private let wheelHub = SIMD3<Float>(178, 15.5, 0)
    private let wheelRadius: Float = 13
    private var clock: Float = 0

    init() {}

    /// Builds the canal, the town and the plaza, pausing between pieces so
    /// the loading screen can keep up.
    func build(step: () async -> Void) async {
        var rng = ParkRandom(seed: 0xC17)
        buildGatePath(); await step()
        buildAvenue(&rng); await step()
        buildCanal(&rng); await step()
        buildTownArch(); await step()
        buildStreet(); await step()
        buildBuildings(&rng); await step()
        buildStreetLife(&rng); await step()
        buildPlaza(&rng); await step()
        buildWheel(); await step()
    }

    private func add(_ batch: MeshBatch, _ material: some RealityKit.Material) {
        if let entity = batch.entity(material) { root.addChild(entity) }
    }

    // MARK: - Where you can walk

    /// Names for each part of the walk, shown as you arrive.
    static func area(at p: SIMD2<Float>) -> String {
        if let name = ParkHanami.area(at: p) { return name }
        if simd_distance(p, plaza) < plazaRadius + 1 { return "Fountain Plaza" }
        if p.x > avenueEnd { return "Ziggy Town" }
        if p.x > 21 { return "Sakura Canal" }
        return "Ziggy's Garden"
    }

    /// Keeps someone on foot somewhere they can walk: the garden, the gate
    /// path, the canal promenade, the town street or the plaza. Off all of
    /// them, they are put back on whichever is nearest.
    static func keepOnFoot(_ p: SIMD2<Float>, radius: Float, gardenRadius: Float) -> SIMD2<Float> {
        var candidates: [SIMD2<Float>] = []

        func circle(_ centre: SIMD2<Float>, _ r: Float) -> SIMD2<Float> {
            let away = p - centre
            let d = simd_length(away)
            let limit = r - radius
            return d <= limit || d < 0.0001 ? p : centre + away / d * limit
        }
        func rect(_ minX: Float, _ maxX: Float, _ halfZ: Float) -> SIMD2<Float> {
            [min(max(p.x, minX), maxX), min(max(p.y, -halfZ + radius), halfZ - radius)]
        }

        candidates.append(circle([0, 0], gardenRadius))
        candidates.append(rect(16, avenueStart + 1, 2.0))
        candidates.append(rect(avenueStart, avenueEnd + 1, 4.4))
        candidates.append(rect(avenueEnd, streetEnd + 4, 7.2))
        candidates.append(circle(plaza, plazaRadius))
        candidates += ParkHanami.walkable(p, radius: radius)
        return candidates.min { simd_distance_squared($0, p) < simd_distance_squared($1, p) } ?? p
    }

    // MARK: - Gate path

    private func buildGatePath() {
        var gravel = MeshBatch(), edge = MeshBatch(), red = MeshBatch(), black = MeshBatch()
        let line = stride(from: Float(6), through: Self.avenueStart + 0.5, by: 0.5).map { SIMD3<Float>($0, 0.014, 0) }
        edge.ribbon(line.map { $0 - [0, 0.004, 0] }, width: 2.5, closed: false)
        gravel.ribbon(line, width: 2.2, closed: false)

        // A smaller torii marks the way out.
        let x = Self.gardenGate
        for side: Float in [-1.6, 1.6] {
            black.tube(base: [x, 0, side], height: 0.3, radius: 0.18, topRadius: 0.16, segments: 14)
            red.tube(base: [x, 0.25, side], height: 2.6, radius: 0.14, topRadius: 0.12, segments: 14)
        }
        red.box([x, 2.2, 0], [0.15, 0.16, 3.9])
        var top: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
        var cap: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
        for s in 0...20 {
            let z = -2.3 + Float(s) / 20 * 4.6
            let lift = 0.15 * pow(z / 2.3, 4)
            top.append(([x, 2.85 + lift, z], 0.18, 0.1))
            cap.append(([x, 3.02 + lift * 1.3, z * 1.04], 0.2, 0.08))
        }
        red.loft(top, segments: 10)
        black.loft(cap, segments: 10)
        add(edge, ParkPaint.flat(UIColor(0xB9B2A6)))
        add(gravel, ParkPaint.flat(UIColor(0xE3DDD1)))
        add(red, ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3))
        add(black, ParkPaint.flat(UIColor(0x2B2523)))
        obstacles += [[x, -1.6, 0.2], [x, 1.6, 0.2]]
    }

    // MARK: - Sakura Canal

    private func buildAvenue(_ rng: inout ParkRandom) {
        var paving = MeshBatch(), kerb = MeshBatch(), joints = MeshBatch()
        var bark = MeshBatch(), fallen = MeshBatch()
        var blossom = [MeshBatch(), MeshBatch(), MeshBatch()]
        var stone = MeshBatch(), glow = MeshBatch(), slats = MeshBatch(), legs = MeshBatch()
        var poles = MeshBatch(), wire = MeshBatch(), paper = MeshBatch(), caps = MeshBatch()
        var bushes = MeshBatch(), flowers = MeshBatch()

        let start = Self.avenueStart, end = Self.avenueEnd
        let walk = stride(from: start - 0.5, through: end + 0.5, by: 1).map { SIMD3<Float>($0, 0.012, 0) }
        paving.ribbon(walk, width: 9.2, closed: false)
        kerb.ribbon(walk.map { $0 - [0, 0.004, 0] }, width: 9.8, closed: false)
        var x = start
        while x < end {
            joints.box([x, 0.014, 0], [0.04, 0.005, 9.1])
            x += 1.15
        }

        // Cherry trees down both sides, their crowns meeting overhead.
        x = start + 2
        while x < end - 1 {
            // One row, on the far side from the canal and set back a little,
            // so the view along the water stays open.
            for z: Float in [6.6] {
                let base = SIMD3<Float>(x, 0, z)
                let size = rng.range(1.05, 1.3)
                let crown = JapaneseTree.grow(.sakura, at: base, size: size, rng: &rng, bark: &bark, crowns: &blossom)
                blossomCrowns.append(crown)
                for _ in 0..<30 {
                    let t = rng.range(0, 2 * .pi), d = rng.range(0.3, 2.2)
                    let p = base + [cos(t) * d, 0.02, sin(t) * d]
                    let q = rng.range(0, 3)
                    fallen.blade(p + [cos(q) * 0.05, 0, sin(q) * 0.05], p + [cos(q + 2.2) * 0.05, 0.005, sin(q + 2.2) * 0.05],
                                 p + [cos(q + 4.2) * 0.05, 0, sin(q + 4.2) * 0.05])
                }
                obstacles.append([base.x, base.z, 0.25])
            }
            x += 8.5
        }

        // Benches looking out over the canal, and stone lanterns between.
        x = start + 6
        while x < end - 2 {
            let p = SIMD3<Float>(x, 0, 3.9)
            for k in 0..<4 { slats.box(p + [0, 0.45, Float(k) * 0.11 - 0.17], [1.5, 0.05, 0.09]) }
            for side: Float in [-0.6, 0.6] { legs.box(p + [side, 0.22, 0], [0.08, 0.44, 0.42]) }
            obstacles.append([x, 3.9, 0.7])
            let l = SIMD3<Float>(x + 5.5, 0, 4.0)
            stone.tube(base: l, height: 0.16, radius: 0.3, topRadius: 0.27, segments: 6)
            stone.tube(base: l + [0, 0.16, 0], height: 0.55, radius: 0.1, topRadius: 0.09, segments: 6)
            stone.tube(base: l + [0, 0.7, 0], height: 0.1, radius: 0.26, topRadius: 0.24, segments: 6)
            glow.blob(l + [0, 0.97, 0], [0.15, 0.15, 0.15], rings: 6, segments: 10)
            lightSpots.append(l + [0, 0.97, 0])
            stone.tube(base: l + [0, 1.13, 0], height: 0.24, radius: 0.38, topRadius: 0.06, segments: 6)
            obstacles.append([l.x, l.z, 0.3])
            x += 11
        }

        // Paper lanterns strung right across the promenade.
        x = start + 3
        while x < end {
            let a = SIMD3<Float>(x, 3.4, -4.7), b = SIMD3<Float>(x + 1.5, 3.4, 4.7)
            poles.tube(base: [a.x, 0, a.z], height: 3.45, radius: 0.045, segments: 8)
            poles.tube(base: [b.x, 0, b.z], height: 3.45, radius: 0.045, segments: 8)
            var line: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...20 {
                let t = Float(s) / 20
                line.append((a + (b - a) * t - [0, 0.45 * sin(t * .pi), 0], 0.008, 0.008))
            }
            wire.loft(line, segments: 4, capped: false)
            for s in stride(from: 2, to: 19, by: 3) {
                let p = line[s].centre - [0, 0.24, 0]
                paper.blob(p, [0.13, 0.17, 0.13], rings: 8, segments: 12)
                lightSpots.append(p)
                caps.tube(base: p + [0, 0.15, 0], height: 0.05, radius: 0.07, segments: 8)
                caps.tube(base: p - [0, 0.2, 0], height: 0.05, radius: 0.07, segments: 8)
            }
            obstacles += [[a.x, a.z, 0.1], [b.x, b.z, 0.1]]
            x += 9
        }

        // Azaleas along the far side, with a gap for the way into Hanami Park.
        x = start + 1
        while x < end {
            let base = SIMD3<Float>(x + rng.range(-0.5, 0.5), 0, rng.range(7, 9))
            let size = rng.range(0.45, 0.7)
            if abs(base.x - ParkHanami.gateX) < 2.4 + size {
                x += rng.range(2.2, 3.4)
                continue
            }
            bushes.blob(base + [0, size * 0.45, 0], [size * 1.2, size * 0.7, size], rings: 8, segments: 12)
            for _ in 0..<14 {
                let dir = simd_normalize(SIMD3<Float>(rng.range(-1, 1), rng.range(0.1, 1), rng.range(-1, 1)))
                flowers.blob(base + [0, size * 0.45, 0] + dir * [size * 1.2, size * 0.7, size], [0.05, 0.035, 0.05], rings: 4, segments: 6)
            }
            x += rng.range(2.2, 3.4)
        }

        add(kerb, ParkPaint.flat(UIColor(0xA9A296)))
        add(paving, ParkPaint.flat(UIColor(0xDCD4C6)))
        add(joints, ParkPaint.flat(UIColor(0xBDB5A8)))
        add(bark, ParkPaint.flat(UIColor(0x5A4134), roughness: 0.9))
        let shades: [UInt32] = [0xFFC6D8, 0xF7A6C0, 0xFFE4EC]
        for (i, batch) in blossom.enumerated() { add(batch, ParkPaint.soft(UIColor(shades[i]), sheen: 0.55)) }
        add(fallen, ParkPaint.soft(UIColor(0xFFC3D6), sheen: 0.3))
        add(slats, ParkPaint.flat(UIColor(0xA27552)))
        add(legs, ParkPaint.flat(UIColor(0x5A3A2C)))
        add(stone, ParkPaint.flat(UIColor(0xA9A59D)))
        add(glow, ParkPaint.glow(UIColor(0xFFD38A)))
        add(poles, ParkPaint.soft(UIColor(0x9FB35C), sheen: 0.3))
        add(wire, ParkPaint.flat(UIColor(0x3E342C)))
        add(paper, ParkPaint.glow(UIColor(0xFF6B4F)))
        add(caps, ParkPaint.flat(UIColor(0x2B2523)))
        add(bushes, ParkPaint.soft(UIColor(0x6FA052), sheen: 0.4))
        add(flowers, ParkPaint.soft(UIColor(0xF48FB1), sheen: 0.5))
    }

    private func buildCanal(_ rng: inout ParkRandom) {
        var bed = MeshBatch(), walls = MeshBatch(), rail = MeshBatch(), posts = MeshBatch(), red = MeshBatch(), pads = MeshBatch()
        let start = Self.avenueStart - 1, end = Self.avenueEnd + 2
        let line = stride(from: start, through: end, by: 1).map { SIMD3<Float>($0, 0.006, -8.3) }
        bed.ribbon(line, width: 3.6, closed: false)
        for z: Float in [-6.35, -10.25] { walls.box([(start + end) / 2, 0.16, z], [end - start, 0.32, 0.35]) }
        // Wooden railing along the promenade side.
        var x = start + 0.5
        while x < end {
            posts.box([x, 0.45, -5.75], [0.09, 0.9, 0.09])
            x += 2
        }
        rail.box([(start + end) / 2, 0.88, -5.75], [end - start, 0.07, 0.07])
        rail.box([(start + end) / 2, 0.5, -5.75], [end - start, 0.05, 0.05])

        // Little red bridges arching over the water.
        for bx: Float in [36, 52, 66] {
            for side: Float in [-0.6, 0.6] {
                var arch: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                var top: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                for s in 0...16 {
                    let t = Float(s) / 16
                    let z = -6.0 - t * 4.6
                    let h = 0.55 * sin(t * .pi)
                    arch.append(([bx + side, h + 0.1, z], 0.05, 0.05))
                    top.append(([bx + side, h + 0.75, z], 0.035, 0.035))
                }
                red.loft(arch, segments: 8)
                red.loft(top, segments: 8)
                for s in stride(from: 0, through: 16, by: 4) {
                    let t = Float(s) / 16
                    red.tube(base: [bx + side, 0.55 * sin(t * .pi) + 0.1, -6.0 - t * 4.6], height: 0.66, radius: 0.035, segments: 6)
                }
            }
            for s in 0..<12 {
                let t = (Float(s) + 0.5) / 12
                let z = -6.0 - t * 4.6
                walls.box([bx, 0.55 * sin(t * .pi) + 0.14, z], [1.3, 0.05, 0.36])
            }
        }
        for _ in 0..<26 {
            let p = SIMD3<Float>(rng.range(start + 1, end - 1), 0.05, rng.range(-9.6, -7))
            pads.tube(base: p, height: 0.008, radius: rng.range(0.18, 0.3), segments: 12)
        }
        add(bed, ParkPaint.glossy(UIColor(0x3F8F9E), roughness: 0.05))
        add(walls, ParkPaint.flat(UIColor(0xA49E95)))
        add(posts, ParkPaint.flat(UIColor(0x7A5A43)))
        add(rail, ParkPaint.flat(UIColor(0x8C6A4E)))
        add(red, ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3))
        add(pads, ParkPaint.soft(UIColor(0x5FA05A), sheen: 0.2))
    }

    // MARK: - Ziggy Town

    private func buildTownArch() {
        let arch = Entity()
        arch.position = [Self.avenueEnd + 0.6, 0, 0]
        let metal = ParkPaint.metal(UIColor(0x4A3F3A))
        for side: Float in [-1, 1] {
            arch.attach(ParkMesh.box([0.35, 4.6, 0.35]), metal, at: [0, 2.3, 7.4 * side])
            arch.attach(ParkMesh.sphere(0.24), ParkPaint.glow(UIColor(0xFFE0A0)), at: [0, 4.8, 7.4 * side])
            lightSpots.append([Self.avenueEnd + 0.6, 4.8, 7.4 * side])
        }
        arch.attach(ParkMesh.box([0.3, 0.3, 15.2]), metal, at: [0, 4.5, 0])
        arch.attach(ParkMesh.box([0.2, 1.0, 5.2]), ParkPaint.soft(UIColor(0xF27C95), sheen: 0.3), at: [0, 4.0, 0])
        let text = MeshResource.generateText("ZIGGY TOWN", extrusionDepth: 0.04, font: .systemFont(ofSize: 0.62, weight: .heavy),
                                             containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
        for facing: Float in [-1, 1] {
            let label = ModelEntity(mesh: text, materials: [ParkPaint.glow(.white)])
            label.orientation = spin(facing * .pi / 2, [0, 1, 0])
            let c = text.bounds.center
            label.position = [0.12 * facing, 4.0 - c.y, facing < 0 ? -c.x : c.x]
            arch.addChild(label)
        }
        // Bulbs along the beam.
        var bulbs = MeshBatch()
        for k in 0..<26 { bulbs.blob([0.2, 4.28, -6.5 + Float(k) * 0.52], [0.06, 0.06, 0.06], rings: 4, segments: 6) }
        if let b = bulbs.entity(ParkPaint.glow(UIColor(0xFFE7A8))) { arch.addChild(b) }
        root.addChild(arch)
        obstacles += [[Self.avenueEnd + 0.6, -7.4, 0.3], [Self.avenueEnd + 0.6, 7.4, 0.3]]
    }

    private func buildStreet() {
        var road = MeshBatch(), lines = MeshBatch(), pavement = MeshBatch(), kerb = MeshBatch()
        let start = Self.avenueEnd, end = Self.streetEnd + 4
        let centre = stride(from: start, through: end, by: 1).map { SIMD3<Float>($0, 0.01, 0) }
        road.ribbon(centre, width: 6, closed: false)
        for z: Float in [-5.2, 5.2] {
            pavement.ribbon(centre.map { [$0.x, 0.03, z] }, width: 4.4, closed: false)
            kerb.box([(start + end) / 2, 0.06, z > 0 ? 3.05 : -3.05], [end - start, 0.12, 0.18])
        }
        var x = start + 1
        while x < end {
            lines.box([x, 0.013, 0], [1.6, 0.005, 0.12])
            x += 3.2
        }
        for z: Float in [-2.7, 2.7] { lines.box([(start + end) / 2, 0.013, z], [end - start, 0.005, 0.1]) }
        // Zebra crossings.
        for cx: Float in [98, 124] {
            for k in 0..<9 { lines.box([cx, 0.015, -2.6 + Float(k) * 0.65], [2.6, 0.006, 0.38]) }
        }
        add(road, ParkPaint.flat(UIColor(0x5E6068), roughness: 0.9))
        add(lines, ParkPaint.flat(UIColor(0xF4F1EA)))
        add(pavement, ParkPaint.flat(UIColor(0xCFC8BC)))
        add(kerb, ParkPaint.flat(UIColor(0xA9A296)))
    }

    /// Paint pots for the town, so every building of a colour is one shape.
    private struct Palette {
        var batches: [UInt32: MeshBatch] = [:]
        mutating func box(_ colour: UInt32, _ centre: SIMD3<Float>, _ size: SIMD3<Float>, turn: simd_quatf = spin(0, [0, 1, 0])) {
            batches[colour, default: MeshBatch()].box(centre, size, turn: turn)
        }
    }

    private func buildBuildings(_ rng: inout ParkRandom) {
        var soft = Palette(), flat = Palette(), glow = Palette(), glass = MeshBatch()
        let pastel: [UInt32] = [0xF4E9D8, 0xF6CFCB, 0xCFE6D8, 0xCBDDF0, 0xF7D9B5, 0xE7E2EC, 0xE2C2AA, 0xFFFFFF]
        let awningColours: [UInt32] = [0xE24A5B, 0x3E7CB1, 0x4F9E62, 0xE8964A]
        let shopNames = ["CAFE", "BAKERY", "FLOWERS", "BOOKS", "SWEETS", "GIFTS"]
        let shopSigns = ["ラーメン", "喫茶", "甘味", "寿司", "花", "茶"]
        var nameIndex = 0, signIndex = 0

        for side: Float in [-1, 1] {
            var x = Self.avenueEnd + 2
            var traditional = side > 0
            while x < Self.streetEnd - 2 {
                let front = side * 7.7
                // Facing the street: the facade is at `front`, the building
                // runs back from it. `out` points from the facade to the street.
                let out = -side
                if traditional || rng.unit() < 0.3 {
                    let width = rng.range(6, 7.5)
                    machiya(at: x, width: width, front: front, out: out, rng: &rng, soft: &soft, flat: &flat, glow: &glow,
                            sign: signIndex < shopSigns.count && rng.unit() < 0.75 ? shopSigns[signIndex] : nil)
                    blocks.append(ParkBlock(minX: x, maxX: x + width, minZ: min(front, front - out * 7), maxZ: max(front, front - out * 7), height: 7.5))
                    signIndex += 1
                    x += width + 0.15
                } else {
                    let width = rng.range(6.5, 9)
                    let floors = Int(rng.range(3, 5.99))
                    let wall = pastel[Int(rng.unit() * Float(pastel.count)) % pastel.count]
                    let awning = awningColours[Int(rng.unit() * Float(awningColours.count)) % awningColours.count]
                    var name: String?
                    if nameIndex < shopNames.count && rng.unit() < 0.8 { name = shopNames[nameIndex]; nameIndex += 1 }
                    modern(at: x, width: width, floors: floors, front: front, out: out, wall: wall, awning: awning, name: name,
                           rng: &rng, soft: &soft, flat: &flat, glow: &glow, glass: &glass)
                    blocks.append(ParkBlock(minX: x, maxX: x + width, minZ: min(front, front - out * 8), maxZ: max(front, front - out * 8),
                                            height: Float(floors) * 3.1 + 1.5))
                    x += width + 0.15
                }
                traditional.toggle()
            }
        }
        for (colour, batch) in soft.batches { add(batch, ParkPaint.soft(UIColor(colour), sheen: 0.15)) }
        for (colour, batch) in flat.batches { add(batch, ParkPaint.flat(UIColor(colour))) }
        for (colour, batch) in glow.batches { add(batch, ParkPaint.glow(UIColor(colour))) }
        add(glass, ParkPaint.glossy(UIColor(0x8EA6C2), roughness: 0.08))
    }

    /// A traditional wooden townhouse: a latticed shopfront under a little
    /// tiled eave, a noren curtain over the door and a red lantern beside it,
    /// a white upper floor with slatted windows, and a tiled roof.
    private func machiya(at x: Float, width: Float, front: Float, out: Float, rng: inout ParkRandom,
                         soft: inout Palette, flat: inout Palette, glow: inout Palette, sign: String?) {
        let depth: Float = 7
        let back = front - out * depth
        let cx = x + width / 2
        let wood: UInt32 = 0x5E4030, darkWood: UInt32 = 0x3E2A20, plaster: UInt32 = 0xF4EEE3, tile: UInt32 = 0x4A4E57
        let ground: Float = 3.0, upper: Float = 2.5

        soft.box(darkWood, [cx, ground / 2, (front + back) / 2], [width, ground, depth])
        soft.box(plaster, [cx, ground + upper / 2, (front + back) / 2 - out * 0.3], [width, upper, depth - 0.6])

        // Ground floor: a warm glow behind close-set wooden slats.
        let face = front + out * 0.04
        glow.box(0xFFE2B0, [cx - width * 0.12, 1.4, face], [width * 0.62, 2.0, 0.04])
        var slat = cx - width * 0.43
        while slat < cx + width * 0.19 {
            flat.box(wood, [slat, 1.4, face + out * 0.03], [0.05, 2.0, 0.05])
            slat += 0.13
        }
        flat.box(wood, [cx - width * 0.12, 2.45, face + out * 0.03], [width * 0.66, 0.1, 0.08])
        // The doorway, with a noren hanging in three panels.
        let door = cx + width * 0.33
        glow.box(0xFFEBC8, [door, 1.15, face], [1.2, 2.2, 0.04])
        let noren: UInt32 = [0x2E4A7A, 0x9C2B2B, 0x3E6B4E][Int(rng.unit() * 3) % 3]
        for k in 0..<3 {
            soft.box(noren, [door - 0.4 + Float(k) * 0.4, 1.95, face + out * 0.09], [0.38, 0.75, 0.02])
        }
        flat.box(wood, [door, 2.35, face + out * 0.09], [1.3, 0.05, 0.05])
        // A red paper lantern by the door.
        glow.box(0xFF6B4F, [door - 0.85, 2.0, face + out * 0.35], [0.26, 0.36, 0.26])
        flat.box(darkWood, [door - 0.85, 2.21, face + out * 0.35], [0.18, 0.06, 0.18])

        // A small tiled eave over the shopfront, sloping down to the street.
        let eaveTurn = spin(out * 0.38, [1, 0, 0])
        flat.box(tile, [cx, ground + 0.05, front + out * 0.55], [width + 0.2, 0.09, 1.25], turn: eaveTurn)
        var ridge = x + 0.15
        while ridge < x + width {
            flat.box(0x3C3F47, [ridge, ground + 0.12, front + out * 0.55], [0.06, 0.05, 1.25], turn: eaveTurn)
            ridge += 0.28
        }

        // Upper floor: dark timber framing and slatted windows.
        let upperFace = front - out * 0.58
        for k in 0..<2 {
            let wx = cx + (Float(k) - 0.5) * width * 0.48
            flat.box(darkWood, [wx, ground + upper / 2, upperFace], [width * 0.34, 1.1, 0.05])
            var bar = wx - width * 0.15
            while bar < wx + width * 0.16 {
                soft.box(plaster, [bar, ground + upper / 2, upperFace + out * 0.03], [0.07, 1.0, 0.04])
                bar += 0.2
            }
        }
        flat.box(darkWood, [cx, ground + 0.08, upperFace + out * 0.02], [width, 0.12, 0.06])

        // The main roof: two tiled slopes meeting at a ridge along the street.
        let top = ground + upper
        let mid = (front + back) / 2
        for slope: Float in [-1, 1] {
            let turn = spin(slope * 0.5, [1, 0, 0])
            flat.box(tile, [cx, top + 0.85, mid + slope * (depth / 4 + 0.15)], [width + 0.4, 0.14, depth / 2 + 0.75], turn: turn)
        }
        flat.box(0x3C3F47, [cx, top + 1.82, mid], [width + 0.5, 0.2, 0.24])
        for end: Float in [-1, 1] { flat.box(0x3C3F47, [cx + end * (width / 2 + 0.25), top + 1.9, mid], [0.2, 0.32, 0.32]) }
        var line = x + 0.2
        while line < x + width {
            flat.box(0x3C3F47, [line, top + 0.95, mid + out * (depth / 4 + 0.15)], [0.05, 0.06, depth / 2 + 0.7], turn: spin(out * 0.5, [1, 0, 0]))
            line += 0.3
        }

        if let sign {
            verticalSign(sign, at: [x + 0.25, ground + upper * 0.55, front + out * 0.55], out: out)
        }
    }

    /// A pastel building a few storeys tall: a glazed shopfront under a
    /// striped awning, windows with frames and sills, a ledge at every floor,
    /// balconies here and there, and clutter on the roof.
    private func modern(at x: Float, width: Float, floors: Int, front: Float, out: Float, wall: UInt32, awning: UInt32, name: String?,
                        rng: inout ParkRandom, soft: inout Palette, flat: inout Palette, glow: inout Palette, glass: inout MeshBatch) {
        let depth: Float = 8
        let cx = x + width / 2
        let storey: Float = 3.1
        let height = Float(floors) * storey + 0.4
        let mid = front - out * depth / 2
        soft.box(wall, [cx, height / 2, mid], [width, height, depth])
        let face = front + out * 0.04
        let trim: UInt32 = 0xFFFDF8

        // Shopfront.
        glow.box(0xFFEFD0, [cx - 0.5, 1.35, face], [width * 0.62, 2.1, 0.05])
        glow.box(0xFFE6BF, [cx + width * 0.34, 1.15, face], [1.0, 2.2, 0.05])
        flat.box(0x4A4038, [cx - 0.5, 2.45, face + out * 0.02], [width * 0.64, 0.1, 0.08])
        for k in 0..<4 { flat.box(0x4A4038, [cx - 0.5 - width * 0.31 + Float(k) * width * 0.207, 1.35, face + out * 0.02], [0.06, 2.1, 0.06]) }
        // Striped awning.
        let stripes = 8
        for k in 0..<stripes {
            let sx = x + 0.3 + (Float(k) + 0.5) / Float(stripes) * (width - 0.6)
            soft.box(k % 2 == 0 ? awning : trim, [sx, 2.8, front + out * 0.55], [(width - 0.6) / Float(stripes), 0.07, 1.1],
                     turn: spin(out * 0.3, [1, 0, 0]))
        }
        if let name { sign(name, at: [cx, 3.45, front + out * 0.08], facing: out, colour: awning) }

        // A ledge at every floor and windows between.
        for floor in 1..<floors {
            let y = Float(floor) * storey
            soft.box(trim, [cx, y + 0.05, face + out * 0.06], [width + 0.1, 0.14, 0.14])
            let count = max(2, Int(width / 2))
            for w in 0..<count {
                let wx = x + (Float(w) + 0.5) / Float(count) * width
                let pane = SIMD3<Float>(wx, y + 1.55, face)
                if rng.unit() < 0.45 { glow.box(0xFFE2A8, pane, [1.05, 1.4, 0.05]) } else { glass.box(pane, [1.05, 1.4, 0.05]) }
                soft.box(trim, pane + [0, 0.74, out * 0.02], [1.2, 0.08, 0.08])
                soft.box(trim, pane - [0, 0.74, -out * 0.02], [1.2, 0.08, 0.08])
                soft.box(trim, pane + [-0.56, 0, out * 0.02], [0.07, 1.4, 0.08])
                soft.box(trim, pane + [0.56, 0, out * 0.02], [0.07, 1.4, 0.08])
                soft.box(0xD9D2C6, pane - [0, 0.82, -out * 0.08], [1.3, 0.07, 0.18])
            }
            if rng.unit() < 0.4 {
                flat.box(0x6E6A66, [cx, y + 0.5, front + out * 0.5], [width * 0.6, 0.08, 0.95])
                flat.box(0x6E6A66, [cx, y + 0.98, front + out * 0.95], [width * 0.6, 0.05, 0.04])
                var post = cx - width * 0.3
                while post <= cx + width * 0.3 {
                    flat.box(0x6E6A66, [post, y + 0.75, front + out * 0.95], [0.03, 0.5, 0.03])
                    post += 0.25
                }
            }
        }
        // Parapet and rooftop clutter.
        soft.box(trim, [cx, height + 0.2, mid], [width + 0.2, 0.4, depth + 0.2])
        flat.box(0xB4B0A8, [cx - width * 0.2, height + 0.7, mid], [1.2, 0.7, 0.8])
        flat.box(0x8C8780, [cx + width * 0.22, height + 0.9, mid + 1], [1.0, 1.1, 1.0])
    }

    /// A shop's name on a board over its awning.
    private func sign(_ name: String, at position: SIMD3<Float>, facing: Float, colour: UInt32) {
        let board = Entity()
        board.position = position
        board.orientation = spin(facing > 0 ? 0 : .pi, [0, 1, 0])
        board.attach(ParkMesh.box([Float(name.count) * 0.42 + 0.5, 0.7, 0.08]), ParkPaint.soft(UIColor(colour), sheen: 0.3))
        let text = MeshResource.generateText(name, extrusionDepth: 0.02, font: .systemFont(ofSize: 0.42, weight: .heavy),
                                             containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
        let label = ModelEntity(mesh: text, materials: [ParkPaint.glow(.white)])
        label.position = [-text.bounds.center.x, -text.bounds.center.y, 0.05]
        board.addChild(label)
        root.addChild(board)
    }

    /// A tall sign standing out from the wall, read top to bottom.
    private func verticalSign(_ text: String, at position: SIMD3<Float>, out: Float) {
        let board = Entity()
        board.position = position
        board.orientation = spin(.pi / 2, [0, 1, 0])
        let height = Float(text.count) * 0.42 + 0.3
        board.attach(ParkMesh.box([0.5, height, 0.1]), ParkPaint.glow(UIColor(0xFFF8EE)))
        board.attach(ParkMesh.box([0.56, height + 0.06, 0.06]), ParkPaint.soft(UIColor(0x9C2B2B)))
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.02, font: .systemFont(ofSize: 0.34, weight: .heavy),
                                             containerFrame: CGRect(x: 0, y: 0, width: 0.4, height: CGFloat(height)),
                                             alignment: .center, lineBreakMode: .byCharWrapping)
        for face: Float in [-1, 1] {
            let label = ModelEntity(mesh: mesh, materials: [ParkPaint.flat(UIColor(0x9C2B2B))])
            label.orientation = spin(face > 0 ? 0 : .pi, [0, 1, 0])
            let c = mesh.bounds.center
            label.position = [face > 0 ? -c.x : c.x, -c.y, 0.06 * face]
            board.addChild(label)
        }
        root.addChild(board)
    }

    private func buildStreetLife(_ rng: inout ParkRandom) {
        var poles = MeshBatch(), wires = MeshBatch(), lampPosts = MeshBatch(), lampGlow = MeshBatch()
        var machines = MeshBatch(), machineGlow = MeshBatch(), bulbs = MeshBatch(), stringWire = MeshBatch()
        var tables = MeshBatch(), parasols = MeshBatch(), planters = MeshBatch(), shrubs = MeshBatch(), signals = MeshBatch()
        var red = MeshBatch(), green = MeshBatch()
        let start = Self.avenueEnd + 3, end = Self.streetEnd

        // Telephone poles along the north pavement, wires sagging between.
        var tops: [SIMD3<Float>] = []
        var x = start
        while x < end {
            poles.tube(base: [x, 0, -6.9], height: 8, radius: 0.13, topRadius: 0.1, segments: 10)
            poles.box([x, 7.4, -6.9], [0.1, 0.12, 1.6])
            tops.append([x, 7.45, -6.9])
            obstacles.append([x, -6.9, 0.2])
            x += 14
        }
        for i in 0..<(tops.count - 1) {
            for offset: Float in [-0.65, 0, 0.65] {
                let a = tops[i] + [0, 0, offset], b = tops[i + 1] + [0, 0, offset]
                var line: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                for s in 0...16 {
                    let t = Float(s) / 16
                    line.append((a + (b - a) * t - [0, 0.8 * sin(t * .pi), 0], 0.012, 0.012))
                }
                wires.loft(line, segments: 4, capped: false)
            }
        }

        // Street lamps along the south pavement.
        x = start + 7
        while x < end {
            lampPosts.tube(base: [x, 0, 6.9], height: 4.2, radius: 0.08, topRadius: 0.06, segments: 10)
            lampPosts.box([x, 4.2, 6.4], [0.12, 0.1, 1.1])
            lampGlow.blob([x, 4.05, 5.9], [0.22, 0.14, 0.22], rings: 6, segments: 10)
            lightSpots.append([x, 4.0, 5.9])
            obstacles.append([x, 6.9, 0.15])
            x += 14
        }

        // String lights across the street.
        x = start + 10
        while x < end {
            let a = SIMD3<Float>(x, 5.5, -7.6), b = SIMD3<Float>(x + 2, 5.5, 7.6)
            var line: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...30 {
                let t = Float(s) / 30
                line.append((a + (b - a) * t - [0, 0.7 * sin(t * .pi), 0], 0.008, 0.008))
            }
            stringWire.loft(line, segments: 4, capped: false)
            for s in 1..<30 { bulbs.blob(line[s].centre - [0, 0.05, 0], [0.04, 0.05, 0.04], rings: 4, segments: 6) }
            x += 16
        }

        // Vending machines glowing against the shopfronts.
        for (vx, vz) in [(86, 7.2), (103, -7.2), (118, 7.2), (131, -7.2)] as [(Float, Float)] {
            machines.box([vx, 0.9, vz], [0.9, 1.8, 0.7])
            machineGlow.box([vx, 1.15, vz - (vz > 0 ? 0.36 : -0.36)], [0.7, 1.0, 0.02])
            obstacles.append([vx, vz, 0.55])
        }

        // A café terrace: little tables under pink parasols.
        for k in 0..<3 {
            let p = SIMD3<Float>(108 + Float(k) * 2.4, 0, 5.4)
            tables.tube(base: p, height: 0.72, radius: 0.04, segments: 8)
            tables.tube(base: p + [0, 0.72, 0], height: 0.04, radius: 0.4, segments: 16)
            for side: Float in [-0.55, 0.55] {
                tables.box(p + [side, 0.23, 0], [0.38, 0.46, 0.38])
            }
            parasols.tube(base: p + [0, 0.75, 0], height: 1.5, radius: 0.025, segments: 6)
            parasols.tube(base: p + [0, 2.0, 0], height: 0.35, radius: 1.0, topRadius: 0.02, segments: 12)
            obstacles.append([p.x, p.z, 0.8])
        }

        // Planters with little trees.
        x = start + 4
        while x < end {
            let p = SIMD3<Float>(x + 3.5, 0, 6.4)
            planters.box(p + [0, 0.25, 0], [0.8, 0.5, 0.8])
            shrubs.blob(p + [0, 1.1, 0], [0.55, 0.6, 0.55], rings: 6, segments: 10)
            obstacles.append([p.x, p.z, 0.5])
            x += 14
        }

        // Traffic lights at the crossings.
        for cx: Float in [98, 124] {
            for side: Float in [-1, 1] {
                let p = SIMD3<Float>(cx + side * 1.7, 0, side * 3.4)
                signals.tube(base: p, height: 3.0, radius: 0.06, segments: 8)
                signals.box(p + [0, 3.2, 0], [0.3, 0.8, 0.3])
                red.blob(p + [0, 3.42, side * -0.16], [0.09, 0.09, 0.03], rings: 4, segments: 8)
                green.blob(p + [0, 2.98, side * -0.16], [0.09, 0.09, 0.03], rings: 4, segments: 8)
                obstacles.append([p.x, p.z, 0.15])
            }
        }

        add(poles, ParkPaint.flat(UIColor(0x8C8780)))
        add(wires, ParkPaint.flat(UIColor(0x2B2523)))
        add(lampPosts, ParkPaint.metal(UIColor(0x3F4A44)))
        add(lampGlow, ParkPaint.glow(UIColor(0xFFE7B0)))
        add(stringWire, ParkPaint.flat(UIColor(0x2B2523)))
        add(bulbs, ParkPaint.glow(UIColor(0xFFE0A0)))
        add(machines, ParkPaint.glossy(UIColor(0xF4F4F4), roughness: 0.3))
        add(machineGlow, ParkPaint.glow(UIColor(0x9FD8FF)))
        add(tables, ParkPaint.flat(UIColor(0xF6F1E8)))
        add(parasols, ParkPaint.soft(UIColor(0xF7A8BC), sheen: 0.4))
        add(planters, ParkPaint.flat(UIColor(0x9C8A73)))
        add(shrubs, ParkPaint.soft(UIColor(0x5E9E4F), sheen: 0.3))
        add(signals, ParkPaint.flat(UIColor(0x45484E)))
        add(red, ParkPaint.glow(UIColor(0xFF4D4D)))
        add(green, ParkPaint.glow(UIColor(0x5CF2A0)))
    }

    // MARK: - Fountain Plaza and the Ferris wheel

    private func buildPlaza(_ rng: inout ParkRandom) {
        var ground = MeshBatch(), rings = MeshBatch(), stone = MeshBatch(), slats = MeshBatch(), legs = MeshBatch()
        var lampPosts = MeshBatch(), lampGlow = MeshBatch(), red = MeshBatch(), pink = MeshBatch(), leaves = MeshBatch()
        let c = SIMD3<Float>(Self.plaza.x, 0, Self.plaza.y)
        ground.tube(base: c, height: 0.025, radius: Self.plazaRadius + 0.8, segments: 64)
        for r: Float in [4, 8, 12] {
            var circle: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...64 {
                let a = Float(s) / 64 * 2 * .pi
                circle.append((c + [cos(a) * r, 0.03, sin(a) * r], 0.06, 0.006))
            }
            rings.loft(circle, segments: 4, capped: false)
        }

        // A three-tier fountain.
        stone.tube(base: c, height: 0.55, radius: 2.6, topRadius: 2.5, segments: 40)
        stone.tube(base: c + [0, 0.55, 0], height: 1.3, radius: 0.35, topRadius: 0.3, segments: 16)
        stone.tube(base: c + [0, 1.85, 0], height: 0.25, radius: 1.3, topRadius: 1.4, segments: 32)
        stone.tube(base: c + [0, 2.1, 0], height: 0.9, radius: 0.18, topRadius: 0.14, segments: 12)
        stone.tube(base: c + [0, 3.0, 0], height: 0.16, radius: 0.6, topRadius: 0.65, segments: 24)
        let water = ParkPaint.clear(UIColor(0x9FDBEA), opacity: 0.7, roughness: 0.02)
        let pool = ModelEntity(mesh: .generateCylinder(height: 0.04, radius: 2.35), materials: [water])
        pool.position = c + [0, 0.5, 0]
        root.addChild(pool)
        let upper = ModelEntity(mesh: .generateCylinder(height: 0.04, radius: 1.25), materials: [water])
        upper.position = c + [0, 2.08, 0]
        root.addChild(upper)
        // Water spilling over each tier.
        for (y, r, h) in [(Float(2.1), Float(1.32), Float(1.55)), (3.15, 0.62, 1.05)] {
            let sheet = ModelEntity(mesh: .generateCylinder(height: h, radius: r), materials: [ParkPaint.clear(UIColor(0xD9F3F8), opacity: 0.35)])
            sheet.position = c + [0, y - h / 2, 0]
            root.addChild(sheet)
        }
        obstacles.append([c.x, c.z, 2.75])

        // Benches round the fountain, lamps round the edge.
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi + .pi / 6
            let p = c + [cos(a) * 7, 0, sin(a) * 7]
            let yaw = atan2(c.x - p.x, c.z - p.z)
            let turn = spin(yaw, [0, 1, 0])
            for s in 0..<4 { slats.box(p + turn.act([0, 0.45, Float(s) * 0.11 - 0.17]), [1.6, 0.05, 0.09], yaw: yaw) }
            for side: Float in [-0.65, 0.65] { legs.box(p + turn.act([side, 0.22, 0]), [0.08, 0.44, 0.42], yaw: yaw) }
            obstacles.append([p.x, p.z, 0.8])
        }
        for k in 0..<10 {
            let a = Float(k) / 10 * 2 * .pi
            let p = c + [cos(a) * 13, 0, sin(a) * 13]
            if abs(p.z) < 7.5 && p.x < c.x { continue }
            lampPosts.tube(base: p, height: 3.6, radius: 0.07, topRadius: 0.05, segments: 8)
            lampGlow.blob(p + [0, 3.75, 0], [0.24, 0.3, 0.24], rings: 6, segments: 10)
            lightSpots.append(p + [0, 3.75, 0])
            obstacles.append([p.x, p.z, 0.15])
        }

        // Two hearts planted in flowers either side of the fountain.
        for side: Float in [-1, 1] {
            let centre = c + [3, 0, side * 6]
            for ring in 0..<3 {
                let scale = 0.055 - Float(ring) * 0.014
                let count = 48 - ring * 10
                for i in 0..<count {
                    let t = Float(i) / Float(count) * 2 * .pi
                    let hx = 16 * pow(sin(t), 3)
                    let hz = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
                    let p = centre + [-hz * scale, 0.12, hx * scale]
                    leaves.blob(p - [0, 0.05, 0], [0.08, 0.05, 0.08], rings: 3, segments: 6)
                    if ring % 2 == 0 { red.blob(p, [0.06, 0.05, 0.06], rings: 4, segments: 7) } else { pink.blob(p, [0.06, 0.05, 0.06], rings: 4, segments: 7) }
                }
            }
            obstacles.append([centre.x, centre.z, 0.9])
        }
        add(ground, ParkPaint.flat(UIColor(0xE6DCCB)))
        add(rings, ParkPaint.flat(UIColor(0xBFB4A3)))
        add(stone, ParkPaint.flat(UIColor(0xD6CFC3)))
        add(slats, ParkPaint.flat(UIColor(0xA27552)))
        add(legs, ParkPaint.metal(UIColor(0x3F4A44)))
        add(lampPosts, ParkPaint.metal(UIColor(0x3F4A44)))
        add(lampGlow, ParkPaint.glow(UIColor(0xFFE7B0)))
        add(leaves, ParkPaint.soft(UIColor(0x5E9E4F), sheen: 0.3))
        add(red, ParkPaint.soft(UIColor(0xE24A61), sheen: 0.5))
        add(pink, ParkPaint.soft(UIColor(0xF7A8BC), sheen: 0.5))
    }

    private func buildWheel() {
        var frame = MeshBatch(), legs = MeshBatch(), bulbs = MeshBatch()
        // The wheel turns in the plane facing back down the street.
        for offset: Float in [-0.7, 0.7] {
            var rim: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...72 {
                let a = Float(s) / 72 * 2 * .pi
                rim.append(([offset, sin(a) * wheelRadius, cos(a) * wheelRadius], 0.12, 0.12))
            }
            frame.loft(rim, segments: 6, capped: false)
            for k in 0..<16 {
                let a = Float(k) / 16 * 2 * .pi
                frame.loft([([offset, 0, 0], 0.06, 0.06), ([offset, sin(a) * wheelRadius, cos(a) * wheelRadius], 0.05, 0.05)], segments: 5)
            }
            for k in 0..<64 {
                let a = Float(k) / 64 * 2 * .pi
                bulbs.blob([offset * 1.1, sin(a) * (wheelRadius + 0.1), cos(a) * (wheelRadius + 0.1)], [0.12, 0.12, 0.12], rings: 4, segments: 6)
            }
        }
        frame.tube(base: [-0.9, 0, 0], height: 1.8, radius: 0.5, lean: spin(-.pi / 2, [0, 0, 1]), segments: 16)
        if let f = frame.entity(ParkPaint.soft(.white, sheen: 0.2)) { wheel.addChild(f) }
        if let b = bulbs.entity(ParkPaint.glow(UIColor(0xFFD8E8))) { wheel.addChild(b) }
        wheel.position = wheelHub
        root.addChild(wheel)

        for side: Float in [-1.4, 1.4] {
            for spread: Float in [-6, 6] {
                legs.loft([(wheelHub + [side, 0, 0], 0.18, 0.18), ([wheelHub.x + side * 1.6, 0, spread], 0.25, 0.25)], segments: 10)
            }
        }
        add(legs, ParkPaint.soft(UIColor(0xF2EEE8), sheen: 0.2))

        // Gondolas hang from the rim and stay level as it turns.
        let colours: [UInt32] = [0xF27C95, 0x7FC8E8, 0xF7D36A, 0xA6DB8E, 0xC6A4F2, 0xFFA97A]
        for k in 0..<12 {
            let cabin = Entity()
            let paint = ParkPaint.glossy(UIColor(colours[k % colours.count]), roughness: 0.3)
            cabin.attach(ParkMesh.box([1.3, 1.3, 1.3]), paint, at: [0, -0.9, 0])
            cabin.attach(ParkMesh.box([1.36, 0.5, 1.0]), ParkPaint.glow(UIColor(0xFFF2D8)), at: [0, -0.75, 0])
            cabin.attach(.generateCylinder(height: 0.4, radius: 0.05), ParkPaint.soft(.white), at: [0, -0.1, 0])
            root.addChild(cabin)
            gondolas.append(cabin)
        }
    }

    // MARK: - Every frame

    func update(deltaTime dt: Float) {
        clock += dt
        let turn = clock * 0.035
        wheel.orientation = spin(turn, [1, 0, 0])
        for (k, cabin) in gondolas.enumerated() {
            // Turning the wheel about +X carries a point at angle a round to
            // a - turn, so each cabin rides its own spoke.
            let a = Float(k) / Float(gondolas.count) * 2 * .pi - turn
            cabin.position = wheelHub + [0, sin(a) * wheelRadius, cos(a) * wheelRadius]
            cabin.orientation = spin(sin(clock * 0.8 + Float(k)) * 0.04, [1, 0, 0])
        }
    }
}
