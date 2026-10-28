//
//  ZiggyParkScenery.swift
//  Ziggy
//
//  Ziggy's garden: a Japanese garden at golden hour, everything in the world
//  that is not one of you three.
//
//  You start in front of a red torii gate. Past it, a gravel path runs down
//  to a koi pond, and a red arched bridge carries you over the water —
//  up and over, the way those bridges do — to a little shrine with a bell
//  and a rack of wooden prayer plaques painted with hearts. A pagoda stands
//  off to one side and a tea house with glowing paper screens to the other,
//  beside a raked gravel garden. Stone lanterns line the paths, red paper
//  lanterns hang between bamboo poles, bamboo groves rustle at the edges,
//  and cherry trees drop petals on everything. Mount Fuji sits on the
//  horizon under a peach and lavender sky, and fireflies come out over the
//  moss.
//
//  It is all placed from a fixed seed, so it is the same garden on both
//  phones. Anything that stands still is poured into `MeshBatch`es, one per
//  colour, so the whole garden is a few dozen draw calls.
//

import CoreGraphics
import RealityKit
import UIKit

@available(iOS 18.0, *)
final class ParkScenery {

    let root = Entity()

    /// Things to walk around rather than through, as (x, z, radius).
    private(set) var obstacles: [SIMD3<Float>] = []

    /// Buildings: solid to walk into, and solid to the camera.
    private(set) var blocks: [ParkBlock] = []

    /// How far from the middle anyone can walk. The bamboo fence stands just past it.
    static let walkRadius: Float = 22

    private struct Butterfly {
        let entity: Entity
        let wings: [Entity]
        let centre: SIMD3<Float>
        let radius: Float
        let speed: Float
        let phase: Float
    }

    private struct Firefly {
        let entity: ModelEntity
        var position: SIMD3<Float>
        var drift: SIMD3<Float>
        let phase: Float
    }

    private struct Petal {
        let entity: ModelEntity
        var position: SIMD3<Float>
        var spin: Float
        var resting: Float
        let sway: Float
    }

    private struct Koi {
        let entity: Entity
        let tail: Entity
        let radius: SIMD2<Float>
        let speed: Float
        let phase: Float
    }

    private var butterflies: [Butterfly] = []
    private var fireflies: [Firefly] = []
    private var petals: [Petal] = []
    private var koi: [Koi] = []
    private var blossomCrowns: [SIMD3<Float>] = []
    private var mapleCrowns: [SIMD3<Float>] = []
    private var leaves: [Petal] = []
    private let clouds = Entity()

    // Day into night.
    private let sun = Entity()
    private let moon = Entity()
    private var skyDome: ModelEntity?
    /// The sky from golden hour to full night, in steps. Swapping between
    /// solid pictures, rather than fading a see-through night sky over the
    /// evening one, means nothing can ever show through from behind.
    private var skyFrames: [TextureResource] = []
    private var skyFrame = -1
    private var cloudPuffs: ModelEntity?
    /// Each lamp's glow, and how big it is at full night.
    private var glows: [(entity: Entity, size: Float)] = []
    /// Where you are, for switching off what is too far away to see.
    private var viewer = SIMD3<Float>(50, 0, 38)
    private var nextCull: Float = 0
    /// Falling things this far from you are paused and hidden.
    private let nearby: Float = 24
    private var night: Float = -1
    private var cloudStep: Float = -1

    /// Where the lamps and lanterns are, for real lights near wherever you
    /// are walking at night.
    private(set) var lightSpots: [SIMD3<Float>] = []
    private var bell: Entity?
    private var clock: Float = 0
    private var rng = ParkRandom(seed: 0x10FE)

    /// The canal promenade, the town and the plaza beyond the east gate.
    private let city = ParkCity()
    /// The big stroll garden off the canal.
    let hanami = ParkHanami()

    // Landmarks, placed by hand so the scatter can steer round them.
    static let pond = SIMD2<Float>(0, -12)
    static let pondRadius = SIMD2<Float>(6.2, 3.0)
    /// The bridge runs north–south across the middle of the pond.
    static let bridgeStart: Float = -7.4
    static let bridgeEnd: Float = -16.6
    static let bridgeRise: Float = 0.85
    private let torii = SIMD2<Float>(0, -1.6)
    private let shrine = SIMD2<Float>(0, -19.4)
    private let pagoda = SIMD2<Float>(-14, -11)
    private let teaHouse = SIMD2<Float>(13, -9)
    private let zen = SIMD2<Float>(9, 5)
    private let ema = SIMD2<Float>(3.2, -18.2)
    private let groves: [(SIMD2<Float>, Float)] = [([-15, 5], 3.4), ([15.5, 13], 3.0), ([-6, 16], 2.6)]

    /// The loop path's distance from the middle at a given angle.
    static func pathRadius(_ angle: Float) -> Float {
        6.6 + sin(angle * 3) * 0.7
    }

    init() {}

    /// Builds the whole world, a piece at a time. Between pieces it pauses
    /// for a moment so the screen can redraw — the loading screen keeps
    /// moving and its progress bar fills — rather than the app freezing on a
    /// blank page until everything is done. `progress` runs 0 to 1.
    func build(progress: @escaping (Float) -> Void) async {
        let total: Float = 46
        var done: Float = 0
        func step() async {
            done += 1
            progress(min(1, done / total))
            try? await Task.sleep(for: .milliseconds(1))
        }
        var rng = ParkRandom(seed: 0x5A1665)
        buildSky(&rng); await step()
        buildGround(); await step()
        buildHills(&rng); await step()
        buildPaths(&rng); await step()
        buildPond(&rng); await step()
        buildBridge(); await step()
        buildTorii(); await step()
        buildShrine(); await step()
        buildEma(); await step()
        buildPagoda(); await step()
        buildTeaHouse(); await step()
        buildZenGarden(&rng); await step()
        buildLanterns(); await step()
        buildLanternStrings(); await step()
        buildBamboo(&rng); await step()
        buildFence(); await step()
        buildBenches(); await step()
        buildTrees(&rng); await step()
        buildAzaleas(&rng); await step()
        buildMoss(&rng); await step()
        buildButterflies(&rng)
        buildFireflies(&rng); await step()
        await city.build(step: step)
        root.addChild(city.root)
        obstacles += city.obstacles
        blocks += city.blocks
        blossomCrowns += city.blossomCrowns
        lightSpots += city.lightSpots
        await hanami.build(step: step)
        root.addChild(hanami.root)
        obstacles += hanami.obstacles
        blocks += hanami.blocks
        lightSpots += hanami.lightSpots
        blossomCrowns += hanami.blossomCrowns
        mapleCrowns += hanami.mapleCrowns
        lightSpots += [[shrine.x, 1.6, shrine.y + 1.2], [teaHouse.x, 1.5, teaHouse.y]]
        buildPetals(); await step()
        buildLeaves()
        buildGlows(); await step()
        progress(1)
    }

    // MARK: - Ground height and the rules of where you can walk

    /// How high the ground is here: zero everywhere except on the bridge,
    /// which rises and falls in a smooth arch over the water.
    static func height(atX x: Float, z: Float) -> Float {
        guard abs(x) < 0.95, z < bridgeStart, z > bridgeEnd else { return 0 }
        let t = (z - bridgeEnd) / (bridgeStart - bridgeEnd)
        return bridgeRise * sin(.pi * t)
    }

    private static func onBridge(_ p: SIMD2<Float>) -> Bool {
        abs(p.x) < 0.95 && p.y < bridgeStart + 0.1 && p.y > bridgeEnd - 0.1
    }

    private func inPond(_ p: SIMD2<Float>, margin: Float) -> Bool {
        let d = (p - Self.pond) / (Self.pondRadius + margin)
        return simd_length_squared(d) < 1
    }

    private func onLoop(_ p: SIMD2<Float>, margin: Float) -> Bool {
        abs(simd_length(p) - Self.pathRadius(atan2(p.y, p.x))) < 0.7 + margin
    }

    /// Free ground for planting, away from every landmark and path.
    private func clear(_ p: SIMD2<Float>, radius: Float) -> Bool {
        if simd_length(p) > Self.walkRadius - radius { return false }
        if onLoop(p, margin: radius) || inPond(p, margin: radius + 0.6) { return false }
        if abs(p.x) < 1.4 + radius && p.y < 5 && p.y > -21 { return false }
        if p.x > 5 && abs(p.y) < 2.2 + radius { return false }
        let landmarks: [(SIMD2<Float>, Float)] = [
            (torii, 2.4), (shrine, 3.2), (pagoda, 3.2), (teaHouse, 3.8), (zen, 3.0), (ema, 1.2), ([0, 3.5], 2.5),
        ] + groves
        for (centre, size) in landmarks where simd_distance(p, centre) < size + radius { return false }
        for o in obstacles where simd_distance(p, SIMD2(o.x, o.y)) < o.z + radius + 0.3 { return false }
        return true
    }

    /// Keeps someone inside the fence, out of the water — unless they are on
    /// the bridge, where the railings keep them on the deck — and walks them
    /// round anything in the way rather than stopping them dead.
    func constrain(_ p: SIMD3<Float>, radius: Float) -> SIMD3<Float> {
        // The garden, the gate path, the canal, the town or the plaza.
        var flat = ParkCity.keepOnFoot(SIMD2(p.x, p.z), radius: radius, gardenRadius: Self.walkRadius)

        flat = ParkHanami.keepOutOfWater(flat, radius: radius)
        if Self.onBridge(flat) {
            flat.x = min(max(flat.x, -0.5), 0.5)
        } else {
            let reach = Self.pondRadius + radius
            let d = (flat - Self.pond) / reach
            let length = simd_length(d)
            if length < 1, length > 0.0001 { flat = Self.pond + d / length * reach }
        }
        // A few passes, so being pushed out of one thing can never leave you
        // inside the one next to it.
        for _ in 0..<3 {
            for o in obstacles {
                let centre = SIMD2(o.x, o.y)
                let limit = o.z + radius
                let away = flat - centre
                let gap = simd_length(away)
                if gap < limit && gap > 0.0001 { flat = centre + away / gap * limit }
            }
            for block in blocks { flat = block.pushOut(flat, radius: radius) }
        }
        return [flat.x, 0, flat.y]
    }

    /// Whether a camera at `p` would be inside a building.
    func blocksView(_ p: SIMD3<Float>) -> Bool {
        blocks.contains { $0.contains(p, margin: 0.35) }
    }

    private func add(_ batch: MeshBatch, _ material: some RealityKit.Material) {
        if let entity = batch.entity(material) { root.addChild(entity) }
    }

    // MARK: - Sky, Fuji, hills

    private func buildSky(_ rng: inout ParkRandom) {
        skyFrames = makeSkyFrames(count: 16)
        // Big enough to reach past the town and the Ferris wheel.
        let dome = ModelEntity(mesh: .generateSphere(radius: 600), materials: [skyMaterial(0)])
        dome.scale = [-1, 1, 1]
        root.addChild(dome)
        skyDome = dome
        skyFrame = 0

        moon.position = [45, 48, -140]
        moon.attach(ParkMesh.sphere(5), ParkPaint.glow(UIColor(0xFFF8E6)))
        moon.attach(ParkMesh.sphere(9), ParkPaint.clear(UIColor(0xDDE6FF), opacity: 0.2))
        moon.scale = .init(repeating: 0.001)
        root.addChild(moon)

        sun.position = [-55, 14, -130]
        sun.attach(ParkMesh.sphere(7), ParkPaint.glow(UIColor(0xFFF1CF)))
        sun.attach(ParkMesh.sphere(11), ParkPaint.clear(UIColor(0xFFD9A0), opacity: 0.35))
        sun.attach(ParkMesh.sphere(17), ParkPaint.clear(UIColor(0xFFC6A0), opacity: 0.15))
        root.addChild(sun)

        // Mount Fuji, hazy with distance, snow on top.
        var fuji = MeshBatch(), snow = MeshBatch()
        let base = SIMD3<Float>(28, -6, -128)
        fuji.tube(base: base, height: 50, radius: 72, topRadius: 7, segments: 48)
        let snowLine: Float = 72 - 65 * 34 / 50
        snow.tube(base: base + [0, 34, 0], height: 16.3, radius: snowLine + 0.6, topRadius: 7.3, segments: 48)
        for k in 0..<12 {
            let a = Float(k) / 12 * 2 * .pi
            let r: Float = 72 - 65 * 31 / 50
            snow.blob(base + [cos(a) * r, 31.5, sin(a) * r], [3.2, 4.5, 3.2], rings: 4, segments: 8)
        }
        add(fuji, ParkPaint.flat(UIColor(0x8E93BE)))
        add(snow, ParkPaint.flat(UIColor(0xF6F1F6)))

        var puffs = MeshBatch()
        for i in 0..<12 {
            let a = Float(i) / 12 * 2 * .pi + rng.range(-0.2, 0.2)
            let distance = rng.range(55, 90)
            let centre = SIMD3<Float>(cos(a) * distance, rng.range(16, 28), sin(a) * distance)
            for k in 0..<5 {
                let r = rng.range(2.2, 3.6) * (k == 2 ? 1.3 : 1)
                puffs.blob(centre + [Float(k) * 2.6 - 5.2, rng.range(-0.3, 0.8), rng.range(-0.8, 0.8)], [r * 1.2, r * 0.6, r], rings: 6, segments: 10)
            }
        }
        if let entity = puffs.entity(ParkPaint.glow(UIColor(0xFFE3E4))) {
            clouds.addChild(entity)
            cloudPuffs = entity
        }
        root.addChild(clouds)
    }

    private func buildGround() {
        var material = ParkPaint.flat(UIColor(0x8FC46A), roughness: 1)
        if let grass = mossTexture() { material.baseColor = .init(tint: .white, texture: .init(grass)) }
        let ground = ModelEntity(mesh: .generatePlane(width: 760, depth: 420), materials: [material])
        ground.position = [80, 0, 0]
        root.addChild(ground)
    }

    private func buildHills(_ rng: inout ParkRandom) {
        var near = MeshBatch(), far = MeshBatch(), pines = MeshBatch()
        for i in 0..<26 {
            let a = Float(i) / 26 * 2 * .pi + rng.range(-0.08, 0.08)
            let distance = rng.range(34, 42)
            let width = rng.range(9, 15)
            let height = rng.range(3, 7)
            // Leave the way east open, out to the canal and the town, and
            // the view south-east over Hanami Park.
            if a < 1.45 || a > 2 * .pi - 0.5 { continue }
            let centre = SIMD3<Float>(cos(a) * distance, -1, sin(a) * distance)
            if i % 2 == 0 { near.blob(centre, [width, height, width * 0.7], turn: spin(-a, [0, 1, 0]), rings: 10, segments: 18) }
            else { far.blob(centre * 1.25, [width * 1.3, height * 1.5, width], turn: spin(-a, [0, 1, 0]), rings: 10, segments: 18) }
            for _ in 0..<3 {
                let b = a + rng.range(-0.12, 0.12)
                let d = distance + rng.range(-2, 2)
                pines.blob([cos(b) * d, height * 0.55 + 0.6, sin(b) * d], [1.6, 0.7, 1.4], rings: 5, segments: 8)
            }
        }
        add(near, ParkPaint.soft(UIColor(0x86B868), sheen: 0.3))
        add(far, ParkPaint.soft(UIColor(0x9EBC8C), sheen: 0.3))
        add(pines, ParkPaint.soft(UIColor(0x3F7A4A), sheen: 0.3))
    }

    // MARK: - Paths

    private func buildPaths(_ rng: inout ParkRandom) {
        var gravel = MeshBatch(), edge = MeshBatch(), stones = MeshBatch(), pebbles = MeshBatch()

        var loop: [SIMD3<Float>] = []
        for i in 0..<160 {
            let a = Float(i) / 160 * 2 * .pi
            let r = Self.pathRadius(a)
            loop.append([cos(a) * r, 0.012, sin(a) * r])
        }
        edge.ribbon(loop.map { $0 - [0, 0.004, 0] }, width: 1.55, closed: true)
        gravel.ribbon(loop, width: 1.3, closed: true)

        // The main way: from where you start, through the gate, down to the
        // bridge; and on from the far end of the bridge up to the shrine.
        let approach = stride(from: Float(5), through: Self.bridgeStart + 0.2, by: -0.5).map { SIMD3<Float>(0, 0.013, $0) }
        let beyond = stride(from: Self.bridgeEnd - 0.2, through: -18.0, by: -0.4).map { SIMD3<Float>(0, 0.013, $0) }
        for way in [approach, beyond] {
            edge.ribbon(way.map { $0 - [0, 0.004, 0] }, width: 2.0, closed: false)
            gravel.ribbon(way, width: 1.75, closed: false)
        }
        // Stepping stones set into the gravel.
        for z in stride(from: Float(4.4), through: Self.bridgeStart + 0.8, by: -0.75) {
            stones.tube(base: [rng.range(-0.08, 0.08), 0.0, z], height: 0.035, radius: rng.range(0.3, 0.36), segments: 14)
        }
        for _ in 0..<320 {
            let a = rng.range(0, 2 * .pi)
            let r = Self.pathRadius(a) + rng.range(-0.75, 0.75)
            let size = rng.range(0.025, 0.06)
            pebbles.blob([cos(a) * r, 0.015, sin(a) * r], [size * 1.3, size * 0.5, size], turn: spin(rng.range(0, 3), [0, 1, 0]), rings: 3, segments: 6)
        }
        add(edge, ParkPaint.flat(UIColor(0xB9B2A6)))
        add(gravel, ParkPaint.flat(UIColor(0xE3DDD1)))
        add(stones, ParkPaint.flat(UIColor(0xA49E95)))
        add(pebbles, ParkPaint.flat(UIColor(0xC4BDB2)))
    }

    // MARK: - Pond and koi

    private func buildPond(_ rng: inout ParkRandom) {
        let centre = SIMD3<Float>(Self.pond.x, 0, Self.pond.y)
        let r = Self.pondRadius
        let bed = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: 1), materials: [ParkPaint.flat(UIColor(0x2F5E57))])
        bed.position = centre + [0, 0.008, 0]
        bed.scale = [r.x, 1, r.y]
        root.addChild(bed)
        // See-through water, so the koi show.
        let water = ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 1), materials: [ParkPaint.clear(UIColor(0x7FC4C9), opacity: 0.5, roughness: 0.03)])
        water.position = centre + [0, 0.07, 0]
        water.scale = [r.x * 0.985, 1, r.y * 0.985]
        root.addChild(water)

        var rocks = MeshBatch(), rocksLight = MeshBatch(), pads = MeshBatch(), lotus = MeshBatch(), iris = MeshBatch(), leaves = MeshBatch()
        for i in 0..<64 {
            let a = Float(i) / 64 * 2 * .pi
            let p = centre + [cos(a) * r.x * 1.02, 0.05, sin(a) * r.y * 1.02]
            if abs(p.x) < 1.1 { continue }
            let size = rng.range(0.2, 0.42)
            let shape = SIMD3<Float>(size * 1.3, size * 0.6, size)
            if i % 3 == 0 { rocksLight.blob(p, shape, turn: spin(rng.range(0, 3), [0, 1, 0]), rings: 5, segments: 8) }
            else { rocks.blob(p, shape, turn: spin(rng.range(0, 3), [0, 1, 0]), rings: 5, segments: 8) }
        }
        for _ in 0..<12 {
            let a = rng.range(0, 2 * .pi)
            let d = rng.range(0.35, 0.85)
            let p = centre + [cos(a) * r.x * d, 0.075, sin(a) * r.y * d]
            if abs(p.x) < 1.2 { continue }
            pads.tube(base: p, height: 0.008, radius: rng.range(0.2, 0.32), segments: 12)
            if rng.unit() < 0.5 {
                for petal in 0..<7 {
                    let t = Float(petal) / 7 * 2 * .pi
                    lotus.blob(p + [cos(t) * 0.06, 0.05, sin(t) * 0.06], [0.05, 0.035, 0.025], turn: spin(-t, [0, 1, 0]) * spin(0.6, [0, 0, 1]), rings: 4, segments: 6)
                }
            }
        }
        // Purple iris along the banks.
        for _ in 0..<30 {
            let a = rng.range(0, 2 * .pi)
            let p = centre + [cos(a) * (r.x + 0.5), 0, sin(a) * (r.y + 0.5)]
            if abs(p.x) < 1.6 { continue }
            for _ in 0..<3 {
                let q = p + [rng.range(-0.2, 0.2), 0, rng.range(-0.2, 0.2)]
                let h = rng.range(0.45, 0.7)
                leaves.blade(q + [-0.015, 0, 0], q + [0.015, 0, 0], q + [rng.range(-0.08, 0.08), h, rng.range(-0.08, 0.08)])
                iris.blob(q + [0, h * 0.9, 0], [0.05, 0.035, 0.05], rings: 4, segments: 7)
            }
        }
        add(rocks, ParkPaint.flat(UIColor(0x8F8B85)))
        add(rocksLight, ParkPaint.flat(UIColor(0xB4AEA5)))
        add(pads, ParkPaint.soft(UIColor(0x5FA05A), sheen: 0.2))
        add(lotus, ParkPaint.soft(UIColor(0xF8B4CE), sheen: 0.4))
        add(leaves, ParkPaint.soft(UIColor(0x5E8F45), sheen: 0.2))
        add(iris, ParkPaint.soft(UIColor(0x8A63C9), sheen: 0.4))

        // Koi, in orange, white-and-red and gold.
        let patterns: [(UInt32, UInt32)] = [(0xF27A32, 0xFFFFFF), (0xFFFFFF, 0xE2462F), (0xF2B33D, 0xF27A32), (0xFFFFFF, 0xF27A32), (0xE2462F, 0xFFFFFF), (0xF2B33D, 0xFFFFFF), (0xF27A32, 0x222222)]
        for (i, colours) in patterns.enumerated() {
            let fish = Entity()
            let main = ParkPaint.glossy(UIColor(colours.0), roughness: 0.3)
            let patch = ParkPaint.glossy(UIColor(colours.1), roughness: 0.3)
            fish.attach(ParkMesh.sphere(0.1), main, scale: [0.6, 0.45, 1.6])
            fish.attach(ParkMesh.sphere(0.06), patch, at: [0, 0.02, 0.03], scale: [0.7, 0.45, 1.4])
            fish.attach(ParkMesh.sphere(0.012), ParkPaint.glossy(UIColor(0x111111)), at: [0.04, 0.012, 0.12])
            fish.attach(ParkMesh.sphere(0.012), ParkPaint.glossy(UIColor(0x111111)), at: [-0.04, 0.012, 0.12])
            let tail = fish.joint(at: [0, 0, -0.15])
            var fin = MeshBatch()
            fin.blade([0, 0, 0], [-0.07, 0, -0.12], [0.07, 0, -0.12])
            if let finMesh = fin.entity(main) { tail.addChild(finMesh) }
            fish.position = centre + [0, 0.03, 0]
            root.addChild(fish)
            koi.append(Koi(entity: fish, tail: tail, radius: [rng.range(2.0, 4.6), rng.range(0.9, 2.1)],
                           speed: rng.range(0.12, 0.22) * (i % 2 == 0 ? 1 : -1), phase: rng.range(0, 6)))
        }
    }

    // MARK: - The bridge

    private func buildBridge() {
        var deck = MeshBatch(), red = MeshBatch(), under = MeshBatch(), brass = MeshBatch()
        let start = Self.bridgeStart, end = Self.bridgeEnd
        let length = start - end
        func h(_ z: Float) -> Float { Self.height(atX: 0, z: z) }

        // Planks, each tilted to follow the arch.
        let count = 36
        for i in 0..<count {
            let z = start - (Float(i) + 0.5) / Float(count) * length
            let slope = (h(z - 0.05) - h(z + 0.05)) / 0.1
            deck.box([0, h(z) + 0.02, z], [1.5, 0.05, length / Float(count) * 0.94], turn: spin(atan(slope), [1, 0, 0]))
        }
        // Red beams under the deck, and legs down into the water.
        for side: Float in [-0.68, 0.68] {
            var beam: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...30 {
                let z = start + 0.15 - Float(s) / 30 * (length + 0.3)
                beam.append(([side, h(z) - 0.06, z], 0.06, 0.05))
            }
            red.loft(beam, segments: 8)
            for s in 1..<6 {
                let z = start - Float(s) / 6 * length
                under.tube(base: [side, -0.2, z], height: h(z) + 0.15, radius: 0.06, segments: 8)
            }
        }
        // Railings: posts with brass onion-dome caps, a rail along the top
        // that follows the arch and curls up at the ends.
        for side: Float in [-0.72, 0.72] {
            var rail: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...36 {
                let z = start + 0.35 - Float(s) / 36 * (length + 0.7)
                let flick: Float = 0.14 * (pow(max(0, (z - start) / 0.35), 2) + pow(max(0, (end - z) / 0.35), 2))
                rail.append(([side, max(h(z), 0) + 0.78 + flick, z], 0.04, 0.035))
            }
            red.loft(rail, segments: 8)
            var lower: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...30 {
                let z = start - Float(s) / 30 * length
                lower.append(([side, h(z) + 0.4, z], 0.025, 0.022))
            }
            red.loft(lower, segments: 6)
            for s in 0...8 {
                let z = start - Float(s) / 8 * length
                red.tube(base: [side, h(z), z], height: 0.86, radius: 0.045, segments: 8)
                if s == 0 || s == 8 || s == 4 {
                    brass.blob([side, h(z) + 0.94, z], [0.07, 0.08, 0.07], rings: 6, segments: 10)
                    brass.tube(base: [side, h(z) + 1.0, z], height: 0.1, radius: 0.03, topRadius: 0, segments: 8)
                }
            }
        }
        add(deck, ParkPaint.flat(UIColor(0xB98A63)))
        add(red, ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3))
        add(under, ParkPaint.flat(UIColor(0x5A3A2C)))
        add(brass, ParkPaint.metal(UIColor(0xE0B44E)))
        for side: Float in [-0.72, 0.72] {
            obstacles.append([side * 1.35, start + 0.3, 0.12])
            obstacles.append([side * 1.35, end - 0.3, 0.12])
        }
    }

    // MARK: - Torii, shrine, prayer plaques

    private func buildTorii() {
        var red = MeshBatch(), black = MeshBatch(), gold = MeshBatch()
        let c = SIMD3<Float>(torii.x, 0, torii.y)
        for side: Float in [-1.4, 1.4] {
            black.tube(base: c + [side, 0, 0], height: 0.35, radius: 0.22, topRadius: 0.2, segments: 16)
            red.tube(base: c + [side, 0.3, 0], height: 3.1, radius: 0.17, topRadius: 0.15, segments: 16)
        }
        // Nuki: the lower crossbeam, running through both pillars.
        red.box(c + [0, 2.55, 0], [3.7, 0.2, 0.18])
        // Shimaki and kasagi: the great top beam, curving up at the ends.
        var shimaki: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
        var kasagi: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
        for s in 0...24 {
            let x = -2.2 + Float(s) / 24 * 4.4
            let lift = 0.18 * pow(x / 2.2, 4)
            shimaki.append((c + [x, 3.32 + lift, 0], 0.11, 0.18))
            kasagi.append((c + [x * 1.04, 3.52 + lift * 1.3, 0], 0.09, 0.22))
        }
        red.loft(shimaki, segments: 10)
        black.loft(kasagi, segments: 10)
        // Gakuzuka: the short post between the beams, and the name plaque.
        red.box(c + [0, 2.95, 0], [0.2, 0.62, 0.16])
        black.box(c + [0, 2.98, 0.07], [0.46, 0.56, 0.05])
        gold.box(c + [0, 2.98, 0.1], [0.38, 0.48, 0.01])
        add(red, ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3))
        add(black, ParkPaint.flat(UIColor(0x2B2523)))
        add(gold, ParkPaint.metal(UIColor(0xD9AE52)))
        obstacles += [[torii.x - 1.4, torii.y, 0.24], [torii.x + 1.4, torii.y, 0.24]]
    }

    private func buildShrine() {
        let hall = Entity()
        hall.position = [shrine.x, 0, shrine.y]
        let stoneColour = ParkPaint.flat(UIColor(0xB4AFA6))
        let woodFloor = ParkPaint.flat(UIColor(0x8A5A3C))
        let vermilion = ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3)
        let plaster = ParkPaint.soft(UIColor(0xF6F1E8), sheen: 0.1)
        let dark = ParkPaint.flat(UIColor(0x3A2E2A))

        // Stone base and steps, a raised wooden floor on top.
        hall.attach(ParkMesh.box([4.4, 0.45, 3.8]), stoneColour, at: [0, 0.225, 0])
        for step in 0..<3 {
            hall.attach(ParkMesh.box([1.8, 0.15, 0.34]), stoneColour,
                        at: [0, 0.075 + Float(step) * 0.15, 2.2 - Float(step) * 0.3])
        }
        hall.attach(ParkMesh.box([3.4, 0.25, 2.8]), woodFloor, at: [0, 0.6, 0])

        var pillars = MeshBatch(), rails = MeshBatch(), walls = MeshBatch(), beams = MeshBatch()
        let floor: Float = 0.725, top: Float = 2.55
        let posts: [SIMD2<Float>] = [[-1.25, -0.95], [1.25, -0.95], [-1.25, 0.95], [1.25, 0.95], [-0.45, 0.95], [0.45, 0.95], [-1.25, 0], [1.25, 0]]
        for post in posts {
            pillars.tube(base: [post.x, floor, post.y], height: top - floor, radius: 0.09, segments: 12)
            pillars.tube(base: [post.x, floor, post.y], height: 0.12, radius: 0.12, segments: 12)
        }
        // White plaster walls at the back and sides, doors at the front.
        walls.box([0, (floor + top) / 2, -0.95], [2.5, top - floor, 0.06])
        for side: Float in [-1.25, 1.25] { walls.box([side, (floor + top) / 2, 0], [0.06, top - floor, 1.9]) }
        // Red beams tying the pillars together at the top.
        beams.box([0, top - 0.08, 0.95], [2.7, 0.16, 0.14])
        beams.box([0, top - 0.08, -0.95], [2.7, 0.16, 0.14])
        for side: Float in [-1.25, 1.25] { beams.box([side, top - 0.08, 0], [0.14, 0.16, 2.0]) }
        // A veranda railing round the front and sides of the floor.
        for x in stride(from: Float(-1.6), through: 1.6, by: 0.4) where abs(x) > 0.85 {
            rails.tube(base: [x, floor, 1.35], height: 0.4, radius: 0.025, segments: 6)
        }
        for z in stride(from: Float(-1.3), through: 1.3, by: 0.43) {
            for side: Float in [-1.65, 1.65] { rails.tube(base: [side, floor, z], height: 0.4, radius: 0.025, segments: 6) }
        }
        for side: Float in [-1, 1] {
            rails.box([side * 1.25, floor + 0.4, 1.35], [0.8, 0.04, 0.04])
            rails.box([side * 1.65, floor + 0.4, 0], [0.04, 0.04, 2.7])
        }
        for (batch, paint) in [(pillars, vermilion), (rails, vermilion), (beams, vermilion)] {
            if let e = batch.entity(paint) { hall.addChild(e) }
        }
        if let w = walls.entity(plaster) { hall.addChild(w) }

        // Lattice doors, lit from within.
        hall.attach(ParkMesh.box([2.3, 1.45, 0.04]), ParkPaint.glow(UIColor(0xFFE2B0)), at: [0, 1.55, 0.93])
        for k in 0..<9 { hall.attach(ParkMesh.box([0.03, 1.45, 0.05]), dark, at: [-1.12 + Float(k) * 0.28, 1.55, 0.95]) }
        for k in 0..<6 { hall.attach(ParkMesh.box([2.3, 0.03, 0.05]), dark, at: [0, 0.9 + Float(k) * 0.26, 0.95]) }

        // The roof: two curved slopes, steep at the ridge and flattening out
        // to wide eaves that lift at the corners, with a beam along the top.
        var roof = MeshBatch(), under = MeshBatch(), fascia = MeshBatch(), gables = MeshBatch()
        let ridge: Float = 3.6, drop: Float = 1.1, reach: Float = 1.85, halfLength: Float = 2.2
        func roofPoint(_ x: Float, _ t: Float, _ front: Float) -> SIMD3<Float> {
            let fall = 1 - pow(1 - t, 1.8)
            let lift = 0.22 * pow(abs(x) / halfLength, 4) * t * t
            return [x, ridge - drop * fall + lift, front * t * reach]
        }
        for front: Float in [-1, 1] {
            var rowsTop: [[SIMD3<Float>]] = [], rowsUnder: [[SIMD3<Float>]] = []
            var centresTop: [SIMD3<Float>] = [], centresUnder: [SIMD3<Float>] = []
            for i in 0...10 {
                let t = Float(i) / 10
                let row = (0...24).map { j in roofPoint(-halfLength + Float(j) / 24 * 2 * halfLength, t, front) }
                rowsTop.append(row)
                rowsUnder.append(row.map { $0 - [0, 0.09, 0] })
                let mid = roofPoint(0, t, front)
                centresTop.append(mid - [0, 3, 0])
                centresUnder.append(mid + [0, 3, 0])
            }
            roof.sheet(rowsTop, closed: false, centres: centresTop)
            under.sheet(rowsUnder, closed: false, centres: centresUnder)
            fascia.loft((0...24).map { j in (centre: roofPoint(-halfLength + Float(j) / 24 * 2 * halfLength, 1, front) - [0, 0.05, 0], rx: Float(0.06), rz: Float(0.06)) },
                        segments: 6)
        }
        fascia.loft([([-halfLength - 0.1, ridge + 0.06, 0], 0.1, 0.1), ([halfLength + 0.1, ridge + 0.06, 0], 0.1, 0.1)], segments: 10)
        for side: Float in [-1, 1] {
            fascia.blob([side * (halfLength + 0.12), ridge + 0.12, 0], [0.14, 0.2, 0.14], rings: 6, segments: 10)
            // Gable walls filling the triangle under each end of the roof.
            let x = side * 1.28
            gables.blade([x, top, -0.95], [x, top, 0.95], [x, ridge - 0.12, 0])
        }
        if let r = roof.entity(ParkPaint.soft(UIColor(0x5F8F80), sheen: 0.2)) { hall.addChild(r) }
        if let u = under.entity(ParkPaint.flat(UIColor(0x6E4A34))) { hall.addChild(u) }
        if let f = fascia.entity(ParkPaint.flat(UIColor(0x3F5F55))) { hall.addChild(f) }
        if let g = gables.entity(plaster) { hall.addChild(g) }

        // The sacred straw rope across the front, with zigzag paper streamers.
        var rope = MeshBatch(), shide = MeshBatch()
        rope.loft((0...20).map { j -> (centre: SIMD3<Float>, rx: Float, rz: Float) in
            let t = Float(j) / 20
            let r: Float = 0.06 + 0.035 * sin(t * .pi)
            return ([-1.2 + t * 2.4, 2.33 - 0.16 * sin(t * .pi), 1.12], r, r)
        }, segments: 10)
        for x: Float in [-0.75, -0.25, 0.25, 0.75] {
            var y: Float = 2.2 - 0.14 * cos(x * 1.2)
            for k in 0..<4 {
                let shift: Float = k % 2 == 0 ? 0.05 : -0.05
                shide.blade([x - 0.05 + shift, y, 1.13], [x + 0.05 + shift, y, 1.13], [x - shift, y - 0.12, 1.13])
                y -= 0.1
            }
        }
        if let r = rope.entity(ParkPaint.soft(UIColor(0xD9C37A), sheen: 0.3)) { hall.addChild(r) }
        if let s = shide.entity(ParkPaint.soft(.white, sheen: 0.2)) { hall.addChild(s) }

        // Bell and its red-and-white rope; an offering box below.
        let bellJoint = hall.joint(at: [0, 2.32, 1.3])
        bellJoint.attach(.generateCylinder(height: 0.9, radius: 0.025), ParkPaint.soft(UIColor(0xE8E1D6)), at: [0, -0.55, 0])
        bellJoint.attach(.generateCylinder(height: 0.4, radius: 0.028), vermilion, at: [0, -0.75, 0])
        bellJoint.attach(ParkMesh.sphere(0.13), ParkPaint.metal(UIColor(0xE0B44E)), at: [0, 0, 0], scale: [1, 0.8, 1])
        bell = bellJoint
        hall.attach(ParkMesh.box([0.9, 0.4, 0.4]), ParkPaint.flat(UIColor(0x7A4A2E)), at: [0, 0.925, 1.15])
        hall.attach(ParkMesh.box([1.3, 0.14, 0.32]), woodFloor, at: [0, 0.52, 1.56])
        root.addChild(hall)
        // The whole base, steps and all: the hall is up on a platform you
        // cannot climb onto.
        blocks.append(ParkBlock(minX: shrine.x - 2.25, maxX: shrine.x + 2.25, minZ: shrine.y - 1.95, maxZ: shrine.y + 2.42, height: 3.8))
    }

    /// A rack of little wooden prayer plaques, each with a red heart on it.
    private func buildEma() {
        var wood = MeshBatch(), plaques = MeshBatch(), hearts = MeshBatch(), roof = MeshBatch()
        let c = SIMD3<Float>(ema.x, 0, ema.y)
        let turn = spin(-0.5, [0, 1, 0])
        for side: Float in [-0.9, 0.9] { wood.box(c + turn.act([side, 0.8, 0]), [0.1, 1.6, 0.1], yaw: -0.5) }
        for y: Float in [0.9, 1.3] { wood.box(c + turn.act([0, y, 0]), [1.9, 0.06, 0.06], yaw: -0.5) }
        roof.box(c + turn.act([0, 1.68, 0]), [2.2, 0.08, 0.5], yaw: -0.5)
        var rng = ParkRandom(seed: 3)
        for row: Float in [0.9, 1.3] {
            for k in 0..<8 {
                let x = -0.75 + Float(k) * 0.215 + rng.range(-0.02, 0.02)
                let p = c + turn.act([x, row - 0.12, 0.05])
                plaques.box(p, [0.17, 0.13, 0.015], yaw: -0.5 + rng.range(-0.1, 0.1))
                let face = p + turn.act([0, 0.005, 0.012])
                hearts.blob(face + turn.act([-0.016, 0.012, 0]), [0.018, 0.018, 0.006], turn: turn, rings: 4, segments: 7)
                hearts.blob(face + turn.act([0.016, 0.012, 0]), [0.018, 0.018, 0.006], turn: turn, rings: 4, segments: 7)
                hearts.tube(base: face + [0, -0.03, 0], height: 0.035, radius: 0, topRadius: 0.03, lean: turn, segments: 8)
            }
        }
        add(wood, ParkPaint.flat(UIColor(0x8A5A3C)))
        add(roof, ParkPaint.flat(UIColor(0x4A4E57)))
        add(plaques, ParkPaint.flat(UIColor(0xE8CDA2)))
        add(hearts, ParkPaint.soft(UIColor(0xE0344F), sheen: 0.3))
        obstacles.append([ema.x, ema.y, 1.0])
    }

    // MARK: - Pagoda, tea house, zen garden

    private func buildPagoda() {
        var walls = MeshBatch(), pillars = MeshBatch(), roofs = MeshBatch(), gold = MeshBatch(), stone = MeshBatch()
        let c = SIMD3<Float>(pagoda.x, 0, pagoda.y)
        stone.box(c + [0, 0.2, 0], [3.4, 0.4, 3.4])
        var y: Float = 0.4
        for tier in 0..<3 {
            let w: Float = 2.5 - Float(tier) * 0.45
            let h: Float = 1.05 - Float(tier) * 0.1
            walls.box(c + [0, y + h / 2, 0], [w, h, w])
            for (dx, dz) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] as [(Float, Float)] {
                pillars.box(c + [dx * w / 2, y + h / 2, dz * w / 2], [0.12, h, 0.12])
            }
            pillars.box(c + [0, y + h / 2, w / 2 + 0.01], [0.5, h * 0.7, 0.02])
            y += h
            // A wide, low roof flaring out past the walls.
            roofs.tube(base: c + [0, y - 0.05, 0], height: 0.42, radius: w * 1.05, topRadius: w * 0.38, lean: spin(.pi / 4, [0, 1, 0]), segments: 4)
            roofs.tube(base: c + [0, y - 0.12, 0], height: 0.08, radius: w * 1.08, lean: spin(.pi / 4, [0, 1, 0]), segments: 4)
            y += 0.42
        }
        // The spire: stacked gold rings and a jewel on top.
        gold.tube(base: c + [0, y - 0.05, 0], height: 0.25, radius: 0.12, segments: 10)
        for k in 0..<6 { gold.tube(base: c + [0, y + 0.22 + Float(k) * 0.18, 0], height: 0.05, radius: 0.12 - Float(k) * 0.008, segments: 12) }
        gold.tube(base: c + [0, y + 0.2, 0], height: 1.15, radius: 0.04, segments: 8)
        gold.blob(c + [0, y + 1.4, 0], [0.09, 0.12, 0.09], rings: 6, segments: 10)
        add(stone, ParkPaint.flat(UIColor(0xB4AFA6)))
        add(walls, ParkPaint.soft(UIColor(0xF4EBDD), sheen: 0.2))
        add(pillars, ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3))
        add(roofs, ParkPaint.flat(UIColor(0x434756)))
        add(gold, ParkPaint.metal(UIColor(0xE0B44E)))
        blocks.append(ParkBlock(centre: pagoda, half: [1.75, 1.75], height: 7))
    }

    private func buildTeaHouse() {
        let house = Entity()
        house.position = [teaHouse.x, 0, teaHouse.y]
        house.orientation = spin(atan2(-teaHouse.x, -teaHouse.y), [0, 1, 0])
        let wood = ParkPaint.flat(UIColor(0x6E4A34))
        let shoji = ParkPaint.glow(UIColor(0xFFF0D2))
        house.attach(ParkMesh.box([3.6, 0.35, 3.0]), ParkPaint.flat(UIColor(0xA27552)), at: [0, 0.35, 0])
        for (dx, dz) in [(-1.7, -1.4), (1.7, -1.4), (-1.7, 1.4), (1.7, 1.4)] as [(Float, Float)] {
            house.attach(ParkMesh.box([0.14, 2.3, 0.14]), wood, at: [dx, 1.4, dz])
        }
        // Paper screens on three sides, glowing, with their wooden grids.
        for (centre, size) in [([0, 1.45, -1.38], [3.3, 1.8, 0.04]), ([-1.68, 1.45, 0], [0.04, 1.8, 2.7]), ([1.68, 1.45, 0], [0.04, 1.8, 2.7])] as [(SIMD3<Float>, SIMD3<Float>)] {
            house.attach(ParkMesh.box(size), shoji, at: centre)
        }
        for k in 0..<12 {
            house.attach(ParkMesh.box([0.025, 1.8, 0.05]), wood, at: [-1.62 + Float(k) * 0.295, 1.45, -1.35])
        }
        for k in 0..<6 { house.attach(ParkMesh.box([3.3, 0.025, 0.05]), wood, at: [0, 0.6 + Float(k) * 0.34, -1.35]) }
        var roof = MeshBatch()
        roof.tube(base: [0, 2.5, 0], height: 1.1, radius: 3.0, topRadius: 0.35, lean: spin(.pi / 4, [0, 1, 0]), segments: 4)
        roof.tube(base: [0, 2.45, 0], height: 0.08, radius: 3.05, lean: spin(.pi / 4, [0, 1, 0]), segments: 4)
        if let r = roof.entity(ParkPaint.flat(UIColor(0x4A4038))) { house.addChild(r) }
        // A red parasol over a bench draped in red felt, outside the door.
        var canopyA = MeshBatch(), canopyB = MeshBatch()
        let top = SIMD3<Float>(1.2, 2.3, 2.4)
        for w in 0..<16 {
            let t0 = Float(w) / 16 * 2 * .pi, t1 = Float(w + 1) / 16 * 2 * .pi
            let apex = top + [0, 0.05, 0]
            let r0 = top + [cos(t0) * 1.2, -0.42, sin(t0) * 1.2], r1 = top + [cos(t1) * 1.2, -0.42, sin(t1) * 1.2]
            if w % 2 == 0 { canopyA.blade(apex, r0, r1) } else { canopyB.blade(apex, r0, r1) }
        }
        if let a = canopyA.entity(ParkPaint.soft(UIColor(0xD8402E), sheen: 0.4)) { house.addChild(a) }
        if let b = canopyB.entity(ParkPaint.soft(UIColor(0xC73A2A), sheen: 0.4)) { house.addChild(b) }
        house.attach(.generateCylinder(height: 2.3, radius: 0.03), wood, at: [1.2, 1.15, 2.4])
        house.attach(ParkMesh.box([1.6, 0.08, 0.6]), ParkPaint.soft(UIColor(0xD8402E), sheen: 0.3), at: [0.4, 0.45, 2.3])
        for dx: Float in [-0.3, 1.1] { house.attach(ParkMesh.box([0.08, 0.42, 0.5]), wood, at: [dx, 0.21, 2.3]) }
        root.addChild(house)
        obstacles.append([teaHouse.x, teaHouse.y, 2.4])
        blocks.append(ParkBlock(centre: teaHouse, half: [2.0, 2.0], height: 3.8))
    }

    private func buildZenGarden(_ rng: inout ParkRandom) {
        var sand = MeshBatch(), rakes = MeshBatch(), rocks = MeshBatch(), moss = MeshBatch(), border = MeshBatch()
        let c = SIMD3<Float>(zen.x, 0, zen.y)
        sand.tube(base: c, height: 0.03, radius: 2.6, segments: 48)
        border.tube(base: c, height: 0.05, radius: 2.75, topRadius: 2.7, segments: 48)
        let stones: [(SIMD3<Float>, Float)] = [([-0.8, 0, 0.3], 0.42), ([0.9, 0, -0.5], 0.32), ([0.4, 0, 1.1], 0.22)]
        for (offset, size) in stones {
            let p = c + offset
            let turn = spin(rng.range(0, 3), [0, 1, 0])
            rocks.blob(p + [0, size * 0.4, 0], [size * 1.3, size * 0.8, size], turn: turn, rings: 7, segments: 10)
            moss.blob(p + [0, 0.04, 0], [size * 1.6, 0.06, size * 1.3], turn: turn, rings: 4, segments: 10)
            // Raked rings rippling out round each stone.
            for ring in 1...3 {
                let radius = size * 1.4 + Float(ring) * 0.16
                var circle: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                for s in 0...32 {
                    let a = Float(s) / 32 * 2 * .pi
                    circle.append((p + [cos(a) * radius, 0.034, sin(a) * radius], 0.012, 0.012))
                }
                rakes.loft(circle, segments: 4, capped: false)
            }
        }
        add(border, ParkPaint.flat(UIColor(0x8C8780)))
        add(sand, ParkPaint.flat(UIColor(0xEFEAE0)))
        add(rakes, ParkPaint.flat(UIColor(0xD6CFC1)))
        add(rocks, ParkPaint.flat(UIColor(0x6F6B66)))
        add(moss, ParkPaint.soft(UIColor(0x6F9E4C), sheen: 0.3))
        obstacles.append([zen.x, zen.y, 2.6])
    }

    // MARK: - Lanterns

    /// A stone lantern: a hexagonal base, a post, a little house for the
    /// light with its windows glowing, and a curved cap.
    private func stoneLantern(at p: SIMD3<Float>, into stone: inout MeshBatch, glow: inout MeshBatch) {
        stone.tube(base: p, height: 0.16, radius: 0.32, topRadius: 0.28, segments: 6)
        stone.tube(base: p + [0, 0.16, 0], height: 0.55, radius: 0.1, topRadius: 0.09, segments: 6)
        stone.tube(base: p + [0, 0.7, 0], height: 0.1, radius: 0.27, topRadius: 0.25, segments: 6)
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi + .pi / 6
            stone.box(p + [cos(a) * 0.17, 0.97, sin(a) * 0.17], [0.05, 0.34, 0.05])
        }
        glow.blob(p + [0, 0.97, 0], [0.15, 0.15, 0.15], rings: 6, segments: 10)
        lightSpots.append(p + [0, 0.97, 0])
        stone.tube(base: p + [0, 1.13, 0], height: 0.24, radius: 0.4, topRadius: 0.06, segments: 6)
        stone.blob(p + [0, 1.4, 0], [0.07, 0.09, 0.07], rings: 5, segments: 8)
    }

    private func buildLanterns() {
        var stone = MeshBatch(), glow = MeshBatch()
        var spots: [SIMD2<Float>] = [[-1.5, 3.2], [1.5, 3.2], [-1.6, -4.6], [1.6, -4.6], [-1.6, -17.6], [1.6, -17.6], [-6.9, -9.5], [6.9, -9.5], [-6.6, -14.8], [6.6, -14.8]]
        // Round the loop, but never on the paths north, south or east.
        for a: Float in [.pi / 6, .pi * 5 / 6, .pi * 7 / 6, .pi * 11 / 6] {
            let r = Self.pathRadius(a) + 1.15
            spots.append([cos(a) * r, sin(a) * r])
        }
        for spot in spots {
            stoneLantern(at: [spot.x, 0, spot.y], into: &stone, glow: &glow)
            obstacles.append([spot.x, spot.y, 0.32])
        }
        add(stone, ParkPaint.flat(UIColor(0xA9A59D)))
        add(glow, ParkPaint.glow(UIColor(0xFFD38A)))
    }

    /// Red paper lanterns strung between bamboo poles along the loop.
    private func buildLanternStrings() {
        var poles = MeshBatch(), rope = MeshBatch(), paper = MeshBatch(), caps = MeshBatch()
        let count = 10
        var tops: [SIMD3<Float>] = []
        var angles: [Float] = []
        for i in 0..<count {
            let a = Float(i) / Float(count) * 2 * .pi + .pi / 5
            let r = Self.pathRadius(a) - 0.95
            let p = SIMD3<Float>(cos(a) * r, 0, sin(a) * r)
            poles.tube(base: p, height: 2.5, radius: 0.04, topRadius: 0.035, segments: 8)
            tops.append(p + [0, 2.45, 0])
            angles.append(a)
            obstacles.append([p.x, p.z, 0.12])
        }
        for i in 0..<count {
            // Not across the main way through the gate and over the bridge.
            let from = angles[i], to = angles[i] + 2 * .pi / Float(count)
            if [0, Float.pi / 2, Float.pi * 1.5, Float.pi * 2, Float.pi * 2.5].contains(where: { $0 > from && $0 < to }) { continue }
            let a = tops[i], b = tops[(i + 1) % count]
            var line: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...20 {
                let t = Float(s) / 20
                line.append((a + (b - a) * t - [0, 0.55 * sin(t * .pi), 0], 0.008, 0.008))
            }
            rope.loft(line, segments: 4, capped: false)
            for s in stride(from: 3, to: 18, by: 3) {
                let p = line[s].centre - [0, 0.24, 0]
                paper.blob(p, [0.13, 0.17, 0.13], rings: 8, segments: 12)
                lightSpots.append(p)
                caps.tube(base: p + [0, 0.15, 0], height: 0.05, radius: 0.07, segments: 8)
                caps.tube(base: p - [0, 0.2, 0], height: 0.05, radius: 0.07, segments: 8)
                caps.tube(base: p + [0, 0.2, 0], height: 0.09, radius: 0.01, segments: 4)
            }
        }
        add(poles, ParkPaint.soft(UIColor(0x9FB35C), sheen: 0.3))
        add(rope, ParkPaint.flat(UIColor(0x3E342C)))
        add(paper, ParkPaint.glow(UIColor(0xFF6B4F)))
        add(caps, ParkPaint.flat(UIColor(0x2B2523)))
    }

    // MARK: - Bamboo, fence, benches

    private func buildBamboo(_ rng: inout ParkRandom) {
        var stalks = MeshBatch(), nodes = MeshBatch(), leaves = MeshBatch(), leavesLight = MeshBatch()
        for (centre, size) in groves {
            for _ in 0..<Int(size * 11) {
                let a = rng.range(0, 2 * .pi)
                let d = sqrt(rng.unit()) * size
                let base = SIMD3<Float>(centre.x + cos(a) * d, 0, centre.y + sin(a) * d)
                let height = rng.range(4.5, 7)
                let lean = spin(rng.range(-0.08, 0.08), [1, 0, 0]) * spin(rng.range(-0.08, 0.08), [0, 0, 1])
                let radius = rng.range(0.04, 0.065)
                stalks.tube(base: base, height: height, radius: radius, topRadius: radius * 0.75, lean: lean, segments: 8)
                var y: Float = 0.45
                while y < height {
                    nodes.tube(base: base + lean.act([0, y, 0]), height: 0.03, radius: radius * 1.12, lean: lean, segments: 8)
                    y += rng.range(0.4, 0.5)
                }
                for _ in 0..<10 {
                    let h = rng.range(height * 0.55, height)
                    let p = base + lean.act([0, h, 0])
                    let dir = rng.range(0, 2 * .pi)
                    let out = SIMD3<Float>(cos(dir), -0.35, sin(dir))
                    let side = SIMD3<Float>(-sin(dir), 0, cos(dir)) * 0.03
                    if rng.unit() < 0.5 { leaves.blade(p - side, p + side, p + out * 0.38) } else { leavesLight.blade(p - side, p + side, p + out * 0.38) }
                }
            }
            obstacles.append([centre.x, centre.y, size * 0.9])
        }
        add(stalks, ParkPaint.soft(UIColor(0x8DB04F), sheen: 0.4))
        add(nodes, ParkPaint.soft(UIColor(0xB2C46A), sheen: 0.4))
        add(leaves, ParkPaint.soft(UIColor(0x5E953E), sheen: 0.3))
        add(leavesLight, ParkPaint.soft(UIColor(0x86B54E), sheen: 0.3))
    }

    private func buildFence() {
        var poles = MeshBatch(), ties = MeshBatch()
        let radius = Self.walkRadius + 1.2
        let count = 260
        let gap: Float = 0.1
        for i in 0..<count {
            let a = Float(i) / Float(count) * 2 * .pi
            // An opening to the east, where the gate leads out.
            if a < gap || a > 2 * .pi - gap { continue }
            let p = SIMD3<Float>(cos(a) * radius, 0, sin(a) * radius)
            poles.tube(base: p, height: i % 6 == 0 ? 1.25 : 1.05, radius: i % 6 == 0 ? 0.05 : 0.03, segments: 6)
        }
        for height: Float in [0.3, 0.65, 0.95] {
            var ring: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
            for s in 0...96 {
                let a = gap + Float(s) / 96 * (2 * .pi - 2 * gap)
                ring.append(([cos(a) * (radius + 0.05), height, sin(a) * (radius + 0.05)], 0.025, 0.025))
            }
            ties.loft(ring, segments: 6, capped: false)
        }
        add(poles, ParkPaint.soft(UIColor(0xC4B37A), sheen: 0.3))
        add(ties, ParkPaint.soft(UIColor(0x9C8A55), sheen: 0.3))
    }

    private func buildBenches() {
        var slats = MeshBatch(), legs = MeshBatch()
        for spot: SIMD2<Float> in [[-4.2, -7.8], [4.2, -7.8]] {
            let p = SIMD3<Float>(spot.x, 0, spot.y)
            let yaw = atan2(Self.pond.x - spot.x, Self.pond.y - spot.y)
            let turn = spin(yaw, [0, 1, 0])
            for k in 0..<4 { slats.box(p + turn.act([0, 0.45, Float(k) * 0.11 - 0.17]), [1.5, 0.05, 0.09], yaw: yaw) }
            for side: Float in [-0.6, 0.6] {
                legs.box(p + turn.act([side, 0.22, 0]), [0.08, 0.44, 0.42], yaw: yaw)
            }
            obstacles.append([spot.x, spot.y, 0.75])
        }
        add(slats, ParkPaint.flat(UIColor(0xA27552)))
        add(legs, ParkPaint.flat(UIColor(0x5A3A2C)))
    }

    // MARK: - Trees

    private func buildTrees(_ rng: inout ParkRandom) {
        var bark = MeshBatch(), pineBark = MeshBatch(), pinePads = MeshBatch(), fallen = MeshBatch()
        var sakura = [MeshBatch(), MeshBatch(), MeshBatch()]
        var maple = [MeshBatch(), MeshBatch(), MeshBatch()]

        func petalsUnder(_ base: SIMD3<Float>, _ size: Float, _ rng: inout ParkRandom) {
            for _ in 0..<60 {
                let t = rng.range(0, 2 * .pi)
                let d = rng.range(0.3, 2.4) * size
                let p = base + [cos(t) * d, 0.02, sin(t) * d]
                let q = rng.range(0, 3)
                fallen.blade(p + [cos(q) * 0.05, 0, sin(q) * 0.05], p + [cos(q + 2.2) * 0.05, 0.005, sin(q + 2.2) * 0.05],
                             p + [cos(q + 4.2) * 0.05, 0, sin(q + 4.2) * 0.05])
            }
        }

        // Fewer trees than there is room for, and none crowding the paths, so
        // they frame the walk instead of getting between you and the camera.
        var placed = 0, tries = 0
        while placed < 15 && tries < 3000 {
            tries += 1
            let a = rng.range(0, 2 * .pi)
            let r = rng.range(4.5, Self.walkRadius - 0.8)
            let spot = SIMD2<Float>(cos(a) * r, sin(a) * r)
            let size = rng.range(0.9, 1.25)
            guard clear(spot, radius: 1.3 * size) else { continue }
            if onLoop(spot, margin: 2.6) || abs(spot.x) < 4.5 || (spot.x > 4 && abs(spot.y) < 4.5) { continue }
            let base = SIMD3<Float>(spot.x, 0, spot.y)
            let kind = rng.unit()

            if kind < 0.18 {
                // Japanese pine: a twisting trunk, branches holding out flat
                // cushions of needles, like clouds.
                var trunk: [(centre: SIMD3<Float>, rx: Float, rz: Float)] = []
                let twist = rng.range(0, 6)
                for s in 0...12 {
                    let t = Float(s) / 12
                    trunk.append((base + [sin(t * 3 + twist) * 0.35 * t, t * 2.6 * size, cos(t * 2 + twist) * 0.25 * t], 0.17 * (1 - t * 0.55) * size, 0.17 * (1 - t * 0.55) * size))
                }
                pineBark.loft(trunk, segments: 10)
                let top = trunk.last!.centre
                for k in 0..<5 {
                    let d = Float(k) / 5 * 2 * .pi + rng.range(0, 1)
                    let reach = rng.range(0.8, 1.5) * size
                    let end = base + [cos(d) * reach, rng.range(1.4, 2.4) * size, sin(d) * reach]
                    pineBark.loft([(top - [0, 0.6, 0], 0.07, 0.07), (end, 0.04, 0.04)], segments: 6)
                    pinePads.blob(end + [0, 0.08, 0], [0.75 * size, 0.24 * size, 0.62 * size], turn: spin(d, [0, 1, 0]), rings: 6, segments: 12)
                }
                pinePads.blob(top + [0, 0.15, 0], [0.85 * size, 0.3 * size, 0.75 * size], rings: 6, segments: 12)
                obstacles.append([spot.x, spot.y, 0.4 * size])
            } else if kind > 0.8 {
                // Japanese maple, in its autumn reds.
                mapleCrowns.append(JapaneseTree.grow(.maple, at: base, size: size, rng: &rng, bark: &bark, crowns: &maple))
                obstacles.append([spot.x, spot.y, 0.35 * size])
            } else {
                // Cherry: a short trunk forking into wide, spreading limbs,
                // every twig ending in a clump of blossom.
                let crown = JapaneseTree.grow(.sakura, at: base, size: size, rng: &rng, bark: &bark, crowns: &sakura)
                blossomCrowns.append(crown)
                petalsUnder(base, size, &rng)
                obstacles.append([spot.x, spot.y, 0.35 * size])
            }
            placed += 1
        }
        add(bark, ParkPaint.flat(UIColor(0x5A4134), roughness: 0.9))
        let blossom: [UInt32] = [0xFFC6D8, 0xF7A6C0, 0xFFE4EC]
        for (i, batch) in sakura.enumerated() { add(batch, ParkPaint.soft(UIColor(blossom[i]), sheen: 0.55)) }
        let leaves: [UInt32] = [0xE0492E, 0xF2763A, 0xBF3426]
        for (i, batch) in maple.enumerated() { add(batch, ParkPaint.soft(UIColor(leaves[i]), sheen: 0.4)) }
        add(pineBark, ParkPaint.flat(UIColor(0x5E4535)))
        add(pinePads, ParkPaint.soft(UIColor(0x3F7A4A), sheen: 0.3))
        add(fallen, ParkPaint.soft(UIColor(0xFFC3D6), sheen: 0.3))
    }

    /// Clipped azalea mounds in pink, magenta and white, dotted with flowers.
    private func buildAzaleas(_ rng: inout ParkRandom) {
        let colours: [(UInt32, UInt32)] = [(0x6FA052, 0xF48FB1), (0x5E9548, 0xE04E8A), (0x6FA052, 0xFFFFFF)]
        var bushes = Array(repeating: MeshBatch(), count: 3), flowers = Array(repeating: MeshBatch(), count: 3)
        var count = 0, tries = 0
        while count < 34 && tries < 2000 {
            tries += 1
            let spot = SIMD2<Float>(rng.range(-21, 21), rng.range(-21, 21))
            let size = rng.range(0.35, 0.65)
            guard clear(spot, radius: size) else { continue }
            let kind = Int(rng.unit() * 3) % 3
            let base = SIMD3<Float>(spot.x, 0, spot.y)
            bushes[kind].blob(base + [0, size * 0.45, 0], [size * 1.15, size * 0.7, size], turn: spin(rng.range(0, 3), [0, 1, 0]), rings: 8, segments: 12)
            for _ in 0..<16 {
                let dir = simd_normalize(SIMD3<Float>(rng.range(-1, 1), rng.range(0.1, 1), rng.range(-1, 1)))
                flowers[kind].blob(base + [0, size * 0.45, 0] + dir * [size * 1.15, size * 0.7, size], [0.05, 0.035, 0.05], rings: 4, segments: 6)
            }
            obstacles.append([spot.x, spot.y, size * 0.85])
            count += 1
        }
        for i in 0..<3 {
            add(bushes[i], ParkPaint.soft(UIColor(colours[i].0), sheen: 0.4))
            add(flowers[i], ParkPaint.soft(UIColor(colours[i].1), sheen: 0.5))
        }
    }

    private func buildMoss(_ rng: inout ParkRandom) {
        var grass = MeshBatch(), grassLight = MeshBatch()
        for _ in 0..<700 {
            let centre = SIMD2<Float>(rng.range(-22, 22), rng.range(-22, 22))
            if simd_length(centre) > Self.walkRadius + 0.8 || onLoop(centre, margin: 0) || inPond(centre, margin: 0.3) { continue }
            if abs(centre.x) < 1.2 && centre.y < 5.2 && centre.y > -19 { continue }
            if simd_distance(centre, zen) < 2.9 || simd_distance(centre, teaHouse) < 2.6 { continue }
            let light = rng.unit() < 0.45
            for _ in 0..<6 {
                let angle = rng.range(0, 2 * .pi)
                let out = SIMD3<Float>(cos(angle), 0, sin(angle))
                let root = SIMD3<Float>(centre.x, 0, centre.y) + out * rng.range(0, 0.12)
                let height = rng.range(0.1, 0.24)
                let side = SIMD3<Float>(-out.z, 0, out.x) * 0.02
                let tip = root + out * height * 0.45 + [0, height, 0]
                if light { grassLight.blade(root - side, root + side, tip) } else { grass.blade(root - side, root + side, tip) }
            }
        }
        add(grass, ParkPaint.soft(UIColor(0x6AAE4C), sheen: 0.4))
        add(grassLight, ParkPaint.soft(UIColor(0x94C962), sheen: 0.4))
    }

    // MARK: - Things that move

    private func buildButterflies(_ rng: inout ParkRandom) {
        let colours = [UIColor(0xFFB3CF), UIColor(0xFFE58A), UIColor(0xB9D7FF), UIColor(0xFFFFFF), UIColor(0xD7B8FF)]
        for i in 0..<8 {
            let butterfly = Entity()
            butterfly.attach(ParkMesh.box([0.018, 0.018, 0.1]), ParkPaint.flat(UIColor(0x4A3A35)))
            let paint = ParkPaint.soft(colours[i % colours.count], sheen: 0.6)
            var wings: [Entity] = []
            for side: Float in [-1, 1] {
                let hinge = butterfly.joint(at: [0.008 * side, 0, 0])
                hinge.attach(ParkMesh.sphere(0.06), paint, at: [0.055 * side, 0, 0.02], scale: [1, 0.08, 0.8])
                hinge.attach(ParkMesh.sphere(0.045), paint, at: [0.04 * side, 0, -0.045], scale: [1, 0.08, 0.75])
                wings.append(hinge)
            }
            butterflies.append(Butterfly(entity: butterfly, wings: wings, centre: [rng.range(-14, 14), 0, rng.range(-14, 14)],
                                         radius: rng.range(1.2, 3), speed: rng.range(0.3, 0.6), phase: rng.range(0, 10)))
            root.addChild(butterfly)
        }
    }

    private func buildFireflies(_ rng: inout ParkRandom) {
        let mesh = ParkMesh.sphere(0.022)
        let glow = ParkPaint.glow(UIColor(0xFFF1A0))
        for _ in 0..<40 {
            let entity = ModelEntity(mesh: mesh, materials: [glow])
            let p = SIMD3<Float>(rng.range(-18, 18), rng.range(0.3, 1.6), rng.range(-18, 18))
            entity.position = p
            root.addChild(entity)
            fireflies.append(Firefly(entity: entity, position: p,
                                     drift: simd_normalize(SIMD3<Float>(rng.range(-1, 1), rng.range(-0.3, 0.3), rng.range(-1, 1))),
                                     phase: rng.range(0, 10)))
        }
    }

    private func buildPetals() {
        var shape = MeshBatch()
        shape.blade([-0.045, 0, 0], [0, 0, 0.065], [0.045, 0, 0])
        shape.blade([-0.045, 0, 0], [0.045, 0, 0], [0, 0, -0.04])
        guard let template = shape.entity(ParkPaint.soft(UIColor(0xFFC3D6), sheen: 0.5)), !blossomCrowns.isEmpty else { return }
        for i in 0..<150 {
            let entity = template.clone(recursive: false)
            root.addChild(entity)
            var petal = Petal(entity: entity, position: .zero, spin: rng.range(0, 6), resting: 0, sway: rng.range(0, 6))
            petal.position = petalStart()
            petal.position.y -= Float(i % 10) * 0.35
            petals.append(petal)
        }
    }

    private func petalStart() -> SIMD3<Float> {
        // From a tree near you, when there is one: the park is big, and a
        // petal sent off from the far side is a petal you never see.
        let near = blossomCrowns.filter { simd_distance_squared(SIMD2($0.x, $0.z), SIMD2(viewer.x, viewer.z)) < 22 * 22 }
        let crown = rng.pick(near.isEmpty ? blossomCrowns : near)
        return crown + [rng.range(-1.8, 1.8), rng.range(-0.2, 0.5), rng.range(-1.8, 1.8)]
    }

    /// Maple leaves, red and orange, fluttering down from the maples.
    private func buildLeaves() {
        guard !mapleCrowns.isEmpty else { return }
        var shape = MeshBatch()
        // Five pointed lobes round a centre: a maple leaf.
        for k in 0..<5 {
            let a = Float(k) / 5 * 2 * .pi - .pi / 2
            let tip = SIMD3<Float>(cos(a), 0, sin(a)) * 0.07
            let side = SIMD3<Float>(-sin(a), 0, cos(a)) * 0.022
            shape.blade(side, -side, tip)
        }
        let paints = [UIColor(0xE0492E), UIColor(0xF2763A), UIColor(0xC93326)]
        for i in 0..<45 {
            guard let leaf = shape.entity(ParkPaint.soft(paints[i % paints.count], sheen: 0.3)) else { break }
            root.addChild(leaf)
            var petal = Petal(entity: leaf, position: leafStart(), spin: rng.range(0, 6), resting: 0, sway: rng.range(0, 6))
            petal.position.y -= Float(i % 8) * 0.4
            leaves.append(petal)
        }
    }

    private func leafStart() -> SIMD3<Float> {
        let near = mapleCrowns.filter { simd_distance_squared(SIMD2($0.x, $0.z), SIMD2(viewer.x, viewer.z)) < 22 * 22 }
        return rng.pick(near.isEmpty ? mapleCrowns : near) + [rng.range(-1.6, 1.6), rng.range(-0.2, 0.5), rng.range(-1.6, 1.6)]
    }

    private func skyMaterial(_ frame: Int) -> UnlitMaterial {
        var material = UnlitMaterial()
        if frame < skyFrames.count { material.color = .init(tint: .white, texture: .init(skyFrames[frame])) }
        return material
    }

    /// How far into the night it is: 0 golden hour, 1 full night. The sky,
    /// sun, moon and clouds all follow it.
    func setNight(_ amount: Float) {
        guard abs(amount - night) > 0.004 else { return }
        night = amount
        let frame = Int((amount * Float(max(1, skyFrames.count - 1))).rounded())
        if frame != skyFrame {
            skyFrame = frame
            skyDome?.model?.materials = [skyMaterial(frame)]
        }
        sun.scale = .init(repeating: max(0.001, 1 - amount))
        // Lamps glow a little in the evening light and properly once it is dark.
        let glow = max(0.001, 0.22 + 0.78 * amount)
        for g in glows { g.entity.scale = .init(repeating: g.size * glow) }
        moon.scale = .init(repeating: max(0.001, amount))
        // In the same steps as the sky, rather than a new material every frame.
        let step = Float(frame) / Float(max(1, skyFrames.count - 1))
        if step != cloudStep {
            cloudStep = step
            let cloud = UIColor(red: CGFloat(1 - 0.62 * step), green: CGFloat(0.89 - 0.52 * step), blue: CGFloat(0.89 - 0.4 * step), alpha: 1)
            cloudPuffs?.model?.materials = [ParkPaint.glow(cloud)]
        }
    }

    /// `viewer` is where you are: anything that only matters close up —
    /// falling petals, fireflies, lamp glows — is paused and hidden when it
    /// is far from you, the way games only animate what is near the player.
    func update(deltaTime dt: Float, viewer: SIMD3<Float>) {
        clock += dt
        self.viewer = viewer
        nextCull -= dt
        if nextCull <= 0 {
            nextCull = 0.3
            let lit = night > 0.03
            for g in glows {
                let show = lit && simd_distance_squared(g.entity.position, viewer) < 45 * 45
                if g.entity.isEnabled != show { g.entity.isEnabled = show }
            }
        }

        for b in butterflies {
            let t = clock * b.speed + b.phase
            let position = b.centre + [cos(t) * b.radius, 0.7 + sin(t * 2.3) * 0.35 + 0.25 * sin(t * 5.1), sin(t * 1.3) * b.radius * 0.8]
            let ahead = b.centre + [cos(t + 0.05) * b.radius, 0, sin((t + 0.05) * 1.3) * b.radius * 0.8]
            b.entity.position = position
            b.entity.orientation = spin(atan2(ahead.x - position.x, ahead.z - position.z), [0, 1, 0])
            let flap = sin(clock * 22 + b.phase) * 0.9
            b.wings[0].orientation = spin(-flap, [0, 0, 1])
            b.wings[1].orientation = spin(flap, [0, 0, 1])
        }

        // Koi glide in slow loops, tails swishing.
        for fish in koi {
            let t = clock * fish.speed + fish.phase
            let centre = SIMD3<Float>(Self.pond.x, 0.03, Self.pond.y)
            let p = centre + [cos(t) * fish.radius.x, 0, sin(t) * fish.radius.y]
            let ahead = centre + [cos(t + 0.02 * (fish.speed > 0 ? 1 : -1)) * fish.radius.x, 0, sin(t + 0.02 * (fish.speed > 0 ? 1 : -1)) * fish.radius.y]
            fish.entity.position = p
            fish.entity.orientation = spin(atan2(ahead.x - p.x, ahead.z - p.z), [0, 1, 0]) * spin(sin(clock * 3 + fish.phase) * 0.12, [0, 1, 0])
            fish.tail.orientation = spin(sin(clock * 6 + fish.phase) * 0.45, [0, 1, 0])
        }

        for i in fireflies.indices {
            var f = fireflies[i]
            let close = isNear(f.position)
            if f.entity.isEnabled != close { f.entity.isEnabled = close }
            guard close else { continue }
            let t = clock * 0.6 + f.phase
            f.drift = simd_normalize(f.drift + SIMD3<Float>(sin(t * 1.3), sin(t * 0.7) * 0.4, cos(t * 1.1)) * dt * 0.8)
            f.position += f.drift * dt * 0.25
            if simd_length(SIMD2(f.position.x, f.position.z)) > 19 { f.drift.x *= -1; f.drift.z *= -1 }
            f.position.y = min(1.8, max(0.25, f.position.y))
            f.entity.position = f.position
            // A few at golden hour; the whole meadow of them at night.
            let glow = max(0.15, sin(clock * 2.2 + f.phase * 3)) * (0.35 + 0.65 * max(0, night))
            f.entity.scale = .init(repeating: glow)
            fireflies[i] = f
        }

        for i in petals.indices {
            var p = petals[i]
            if p.resting > 0 {
                p.resting -= dt
                if p.resting <= 0 {
                    p.position = petalStart()
                    // Far from you: wait and try again somewhere else.
                    if !isNear(p.position) { p.resting = rng.range(0.5, 1.5) }
                }
            }
            let close = isNear(p.position)
            if p.entity.isEnabled != close { p.entity.isEnabled = close }
            if !close { petals[i] = p; continue }
            if p.resting <= 0 {
                p.position.y -= dt * 0.32
                p.position.x += sin(clock * 1.4 + p.sway) * dt * 0.25
                p.position.z += cos(clock * 1.1 + p.sway) * dt * 0.18
                p.spin += dt * 1.6
                if p.position.y <= 0.03 {
                    p.position.y = 0.03
                    p.resting = rng.range(2, 6)
                }
            }
            p.entity.position = p.position
            p.entity.orientation = p.resting > 0
                ? spin(p.sway, [0, 1, 0])
                : spin(p.spin, [0, 1, 0]) * spin(sin(p.spin * 1.7) * 0.8, [1, 0, 0])
            petals[i] = p
        }

        // Maple leaves: slower than petals, tumbling and swinging side to side.
        for i in leaves.indices {
            var leaf = leaves[i]
            if leaf.resting > 0 {
                leaf.resting -= dt
                if leaf.resting <= 0 {
                    leaf.position = leafStart()
                    if !isNear(leaf.position) { leaf.resting = rng.range(0.5, 1.5) }
                }
            }
            let close = isNear(leaf.position)
            if leaf.entity.isEnabled != close { leaf.entity.isEnabled = close }
            if !close { leaves[i] = leaf; continue }
            if leaf.resting <= 0 {
                leaf.position.y -= dt * 0.42
                leaf.position.x += sin(clock * 1.1 + leaf.sway) * dt * 0.45
                leaf.position.z += cos(clock * 0.9 + leaf.sway) * dt * 0.3
                leaf.spin += dt * 2.2
                if leaf.position.y <= 0.03 {
                    leaf.position.y = 0.03
                    leaf.resting = rng.range(3, 7)
                }
            }
            leaf.entity.position = leaf.position
            leaf.entity.orientation = leaf.resting > 0
                ? spin(leaf.sway, [0, 1, 0])
                : spin(leaf.spin, [0, 1, 0]) * spin(sin(leaf.spin * 1.3) * 1.1, [1, 0, 0]) * spin(cos(leaf.spin) * 0.5, [0, 0, 1])
            leaves[i] = leaf
        }

        bell?.orientation = spin(sin(clock * 1.3) * 0.05, [1, 0, 0])
        city.update(deltaTime: dt)
        hanami.update(deltaTime: dt, viewer: viewer, night: max(0, night))
        clouds.orientation = spin(clock * 0.004, [0, 1, 0])
    }

    private func isNear(_ p: SIMD3<Float>) -> Bool {
        let d = SIMD2(p.x - viewer.x, p.z - viewer.z)
        return simd_length_squared(d) < nearby * nearby
    }

    // MARK: - Textures

    /// A soft glow round every lamp and lantern: a picture of light fading
    /// from the middle out, always turned to face you, so it reads as glow
    /// rather than as a ball of glass. Faded in and out with the night.
    private func buildGlows() {
        guard let texture = glowTexture() else { return }
        let mesh = MeshResource.generatePlane(width: 1, height: 1)
        var warm = UnlitMaterial()
        warm.color = .init(tint: UIColor(0xFFC878), texture: .init(texture))
        warm.blending = .transparent(opacity: .init(scale: 0.9, texture: .init(texture)))
        for spot in lightSpots {
            let glow = ModelEntity(mesh: mesh, materials: [warm])
            glow.position = spot
            glow.components.set(BillboardComponent())
            glow.isEnabled = false
            root.addChild(glow)
            // Bigger for the tall street lamps, smaller for the lanterns.
            // Scaled where it stands: scaling a holder at the middle of the
            // park instead slid every glow in from the middle as night fell.
            glows.append((glow, spot.y > 3 ? 2.4 : 1.5))
        }
    }

    /// White in the middle, fading smoothly to nothing at the edge.
    private func glowTexture() -> TextureResource? {
        let size = 128
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [UIColor(white: 1, alpha: 0.95).cgColor, UIColor(white: 1, alpha: 0.45).cgColor,
                                                 UIColor(white: 1, alpha: 0.12).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                                        locations: [0, 0.18, 0.5, 1])
        else { return nil }
        let centre = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: CGFloat(size) / 2, options: [])
        guard let image = context.makeImage() else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }

    /// Every step of the sky from golden hour to night, each a solid
    /// picture: the evening gradient with the night sky painted over it a
    /// little more strongly each time.
    private func makeSkyFrames(count: Int) -> [TextureResource] {
        let width = 640, height = 320
        let stops: [UInt32] = [0x6E7FCC, 0xB59AD6, 0xF2AFC0, 0xFFD3A6, 0xFFE6BF, 0xFFD3A6, 0xF2AFC0, 0xB59AD6, 0x6E7FCC]
        guard let day = gradientImage(width: width, height: height, stops: stops.map { UIColor($0) }),
              let night = starImage(width: width, height: height)
        else { return [] }
        return (0..<count).compactMap { k in
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            context.draw(day, in: rect)
            context.setAlpha(CGFloat(k) / CGFloat(count - 1))
            context.draw(night, in: rect)
            guard let image = context.makeImage() else { return nil }
            return try? TextureResource(image: image, options: .init(semantic: .color))
        }
    }

    private func gradientImage(width: Int, height: Int, stops: [UIColor]) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops.map(\.cgColor) as CFArray,
                                        locations: stops.indices.map { CGFloat($0) / CGFloat(stops.count - 1) })
        else { return nil }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        return context.makeImage()
    }

    /// The night sky: deep blue overhead, violet at the horizon, and stars.
    private func starImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [0x0C1230, 0x1A2152, 0x3A336C, 0x5E4A80, 0x3A336C, 0x1A2152, 0x0C1230].map { UIColor(UInt32($0)).cgColor } as CFArray,
                                        locations: [0, 0.25, 0.42, 0.5, 0.58, 0.75, 1])
        else { return nil }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        var rng = ParkRandom(seed: 777)
        for _ in 0..<700 {
            let x = CGFloat(rng.range(0, Float(width)))
            var y = CGFloat(rng.range(0, Float(height) * 0.4))
            if rng.unit() < 0.5 { y = CGFloat(height) - y }
            let size = CGFloat(rng.range(0.7, 2.0))
            context.setFillColor(UIColor(white: 1, alpha: CGFloat(rng.range(0.4, 1))).cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
        return context.makeImage()
    }

    private func gradientTexture(stops: [UIColor]) -> TextureResource? {
        let height = 512
        guard let context = CGContext(data: nil, width: 4, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops.map(\.cgColor) as CFArray,
                                        locations: stops.indices.map { CGFloat($0) / CGFloat(stops.count - 1) })
        else { return nil }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        guard let image = context.makeImage() else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }

    /// Soft moss greens with a scatter of fallen petals.
    private func mossTexture() -> TextureResource? {
        let size = 1024
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(UIColor(0x93C46C).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        var rng = ParkRandom(seed: 99)
        let tints = [UIColor(0xA8D27A), UIColor(0x7FB45C), UIColor(0x9CCB70), UIColor(0xB7D98A), UIColor(0x74A853)]
        for _ in 0..<600 {
            let r = CGFloat(rng.range(8, 70))
            let x = CGFloat(rng.range(0, Float(size))), y = CGFloat(rng.range(0, Float(size)))
            context.setFillColor(rng.pick(tints).withAlphaComponent(CGFloat(rng.range(0.15, 0.4))).cgColor)
            context.fillEllipse(in: CGRect(x: x - r, y: y - r * 0.7, width: r * 2, height: r * 1.4))
        }
        for _ in 0..<6000 {
            let x = CGFloat(rng.range(0, Float(size))), y = CGFloat(rng.range(0, Float(size)))
            let speck = rng.unit() < 0.8 ? UIColor(0x6A9E48) : UIColor(0xFFC9D8)
            context.setFillColor(speck.withAlphaComponent(0.55).cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: 2.4, height: 2.4))
        }
        guard let image = context.makeImage() else { return nil }
        return try? TextureResource(image: image, options: .init(semantic: .color))
    }
}
