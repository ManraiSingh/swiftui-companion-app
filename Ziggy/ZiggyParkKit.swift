//
//  ZiggyParkKit.swift
//  Ziggy
//
//  The small toolbox the park, the people and Ziggy are all built with.
//
//  Two problems it exists to solve. Materials: everything in the park should
//  look like it is made of the same soft stuff, so there is one place that
//  says what "fabric", "fur" and "glossy" mean. And draw calls: a meadow is
//  thousands of blades of grass, and thousands of separate entities would
//  bring a phone to its knees, so anything that never moves on its own is
//  poured into a `MeshBatch` and drawn as one shape per colour.
//

import RealityKit
import UIKit

// MARK: - Materials

enum ParkPaint {

    /// Matte, with a soft sheen at the edges — cloth, fur, leaves. The sheen
    /// is what makes a sphere read as plush rather than plastic.
    ///
    /// The sheen is tinted with the colour itself. A white sheen is right on
    /// cream fur but turns dark hair and dark cloth a dusty grey, because at
    /// the edges it outshines the colour underneath.
    static func soft(_ color: UIColor, sheen: Float = 0.6) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: 0.85)
        material.metallic = .init(floatLiteral: 0)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let amount = CGFloat(sheen)
        let lift: CGFloat = 0.35
        material.sheen = .init(tint: UIColor(
            red: (r + (1 - r) * lift) * amount,
            green: (g + (1 - g) * lift) * amount,
            blue: (b + (1 - b) * lift) * amount,
            alpha: 1
        ))
        return material
    }

    /// Smooth and shiny — eyes, noses, water, polished wood.
    static func glossy(_ color: UIColor, roughness: Float = 0.12) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0)
        material.clearcoat = .init(floatLiteral: 1)
        material.clearcoatRoughness = .init(floatLiteral: 0.05)
        return material
    }

    /// Plain and dull — stone, bark, sand.
    static func flat(_ color: UIColor, roughness: Float = 0.95) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0)
        return material
    }

    static func metal(_ color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: 0.3)
        material.metallic = .init(floatLiteral: 1)
        return material
    }

    /// Skin: soft, a little satin, never plastic.
    static func skin(_ color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: 0.62)
        material.metallic = .init(floatLiteral: 0)
        material.specular = .init(floatLiteral: 0.35)
        material.sheen = .init(tint: color.withBrightness(0.35))
        return material
    }

    /// See-through — shallow water, foam, glass.
    static func clear(_ color: UIColor, opacity: Float, roughness: Float = 0.05) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    /// Lit from inside: lamp glass, the sun.
    static func glow(_ color: UIColor) -> UnlitMaterial {
        UnlitMaterial(color: color)
    }
}

// MARK: - Shapes

/// Spheres and boxes, made cheaply and only once each.
///
/// RealityKit's own sphere is about 8,000 triangles and its rounded box about
/// 13,000 — fine for one hero object, ruinous for hundreds of lattice bars,
/// eyes and fireflies. These are a few hundred at most, and every identical
/// shape shares one mesh.
enum ParkMesh {

    private static var cache: [String: MeshResource] = [:]

    /// As smooth as its size needs: a firefly gets a handful of faces, the
    /// moon a few hundred.
    static func sphere(_ radius: Float) -> MeshResource {
        let (rings, segments) = radius < 0.03 ? (6, 10) : radius < 0.3 ? (10, 16) : (14, 22)
        let key = "s\(radius)"
        if let mesh = cache[key] { return mesh }
        var batch = MeshBatch()
        batch.blob(.zero, .init(repeating: radius), rings: rings, segments: segments)
        let mesh = batch.mesh() ?? .generateSphere(radius: radius)
        cache[key] = mesh
        return mesh
    }

    /// A plain box: twelve triangles. The rounded corners RealityKit offers
    /// cost a thousand times that and are too small to see at walking distance.
    static func box(_ size: SIMD3<Float>) -> MeshResource {
        let key = "b\(size)"
        if let mesh = cache[key] { return mesh }
        let mesh = MeshResource.generateBox(size: size)
        cache[key] = mesh
        return mesh
    }
}

extension UIColor {
    convenience init(_ hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Assembling entities

extension Entity {

    /// Adds a shape as a child and hands it back, so a body can be described
    /// one line per part.
    @discardableResult
    func attach(
        _ mesh: MeshResource,
        _ material: some RealityKit.Material,
        at position: SIMD3<Float> = .zero,
        scale: SIMD3<Float> = .one,
        turn: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
    ) -> ModelEntity {
        let part = ModelEntity(mesh: mesh, materials: [material])
        part.position = position
        part.scale = scale
        part.orientation = turn
        addChild(part)
        return part
    }

    /// An empty joint to hang limbs from.
    func joint(at position: SIMD3<Float>) -> Entity {
        let joint = Entity()
        joint.position = position
        addChild(joint)
        return joint
    }
}

func spin(_ angle: Float, _ axis: SIMD3<Float>) -> simd_quatf {
    simd_quatf(angle: angle, axis: axis)
}

// MARK: - Batched geometry

/// Many static shapes poured into one mesh, drawn in one go.
struct MeshBatch {

    private(set) var positions: [SIMD3<Float>] = []
    private(set) var normals: [SIMD3<Float>] = []
    private(set) var indices: [UInt32] = []

    var isEmpty: Bool { indices.isEmpty }

    /// A single triangle, visible from both sides — grass blades and petals
    /// are paper-thin, and one-sided they vanish when seen from behind.
    mutating func blade(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
        var n = simd_normalize(simd_cross(b - a, c - a))
        // Lean every blade's normal towards the sky so a meadow is lit as a
        // surface, not as thousands of randomly angled cards.
        n = simd_normalize(n * 0.35 + [0, 1, 0])
        let base = UInt32(positions.count)
        positions += [a, b, c, a, c, b]
        normals += [n, n, n, n, n, n]
        indices += [base, base + 1, base + 2, base + 3, base + 4, base + 5]
    }

    /// An ellipsoid. `turn` is applied before it is placed.
    mutating func blob(
        _ center: SIMD3<Float>,
        _ radii: SIMD3<Float>,
        turn: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0]),
        rings: Int = 8,
        segments: Int = 12
    ) {
        let base = UInt32(positions.count)
        for ring in 0...rings {
            let v = Float(ring) / Float(rings) * .pi
            for segment in 0...segments {
                let u = Float(segment) / Float(segments) * 2 * .pi
                let unit = SIMD3<Float>(sin(v) * cos(u), cos(v), sin(v) * sin(u))
                positions.append(center + turn.act(unit * radii))
                normals.append(simd_normalize(turn.act(unit / radii)))
            }
        }
        let stride = UInt32(segments + 1)
        for ring in 0..<UInt32(rings) {
            for segment in 0..<UInt32(segments) {
                let a = base + ring * stride + segment
                let b = a + stride
                indices += [a, a + 1, b, a + 1, b + 1, b]
            }
        }
    }

    /// A cylinder or a cone (set `topRadius` to zero), standing on `base`.
    mutating func tube(
        base: SIMD3<Float>,
        height: Float,
        radius: Float,
        topRadius: Float? = nil,
        lean: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0]),
        segments: Int = 10
    ) {
        let top = topRadius ?? radius
        let start = UInt32(positions.count)
        let slope = (radius - top) / height
        for segment in 0...segments {
            let u = Float(segment) / Float(segments) * 2 * .pi
            let around = SIMD3<Float>(cos(u), 0, sin(u))
            let normal = simd_normalize(lean.act(around + [0, slope, 0]))
            positions.append(base + lean.act(around * radius))
            positions.append(base + lean.act(around * top + [0, height, 0]))
            normals += [normal, normal]
        }
        for segment in 0..<UInt32(segments) {
            let a = start + segment * 2
            indices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
        }
        // A lid, so a stump is not hollow.
        if top > 0 {
            let centre = UInt32(positions.count)
            positions.append(base + lean.act([0, height, 0]))
            normals.append(lean.act([0, 1, 0]))
            for segment in 0...segments {
                let u = Float(segment) / Float(segments) * 2 * .pi
                positions.append(base + lean.act(SIMD3<Float>(cos(u), 0, sin(u)) * top + [0, height, 0]))
                normals.append(lean.act([0, 1, 0]))
            }
            for segment in 0..<UInt32(segments) {
                indices += [centre, centre + segment + 2, centre + segment + 1]
            }
        }
    }

    /// A box, turned about Y.
    mutating func box(_ center: SIMD3<Float>, _ size: SIMD3<Float>, yaw: Float = 0) {
        box(center, size, turn: simd_quatf(angle: yaw, axis: [0, 1, 0]))
    }

    /// A box at any angle — a plank following the curve of a bridge.
    mutating func box(_ center: SIMD3<Float>, _ size: SIMD3<Float>, turn: simd_quatf) {
        let h = size / 2
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            ([1, 0, 0], [0, 1, 0], [0, 0, 1]), ([-1, 0, 0], [0, 0, 1], [0, 1, 0]),
            ([0, 1, 0], [0, 0, 1], [1, 0, 0]), ([0, -1, 0], [1, 0, 0], [0, 0, 1]),
            ([0, 0, 1], [1, 0, 0], [0, 1, 0]), ([0, 0, -1], [0, 1, 0], [1, 0, 0]),
        ]
        for (n, u, v) in faces {
            let base = UInt32(positions.count)
            let c = n * h
            let du = u * h, dv = v * h
            for corner in [c - du - dv, c + du - dv, c + du + dv, c - du + dv] {
                positions.append(center + turn.act(corner))
                normals.append(turn.act(n))
            }
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
    }

    /// A smooth surface of revolution, like something turned on a lathe or
    /// thrown on a wheel — a torso that goes in at the waist and out at the
    /// chest, a skirt that flares, a sleeve that tapers.
    ///
    /// `profile` is (height, radius) pairs from the bottom up. `depth`
    /// flattens it front to back, because bodies are not round. `pleats`
    /// ripples the radius that many times around.
    mutating func lathe(
        _ profile: [SIMD2<Float>],
        at origin: SIMD3<Float> = .zero,
        depth: Float = 1,
        pleats: (count: Int, amount: Float) = (0, 0),
        segments: Int = 32
    ) {
        guard profile.count > 1 else { return }
        let base = UInt32(positions.count)
        for (i, point) in profile.enumerated() {
            let previous = profile[max(0, i - 1)]
            let next = profile[min(profile.count - 1, i + 1)]
            let dy = next.x - previous.x, dr = next.y - previous.y
            let length = max(0.0001, (dy * dy + dr * dr).squareRoot())
            let outward = dy / length, upward = -dr / length
            for segment in 0...segments {
                let u = Float(segment) / Float(segments) * 2 * .pi
                let ripple = 1 + pleats.amount * cos(Float(pleats.count) * u)
                let r = point.y * ripple
                positions.append(origin + [cos(u) * r, point.x, sin(u) * r * depth])
                normals.append(simd_normalize(SIMD3<Float>(cos(u) * outward, upward, sin(u) * outward / depth)))
            }
        }
        let stride = UInt32(segments + 1)
        for ring in 0..<UInt32(profile.count - 1) {
            for segment in 0..<UInt32(segments) {
                let a = base + ring * stride + segment
                let b = a + stride
                indices += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
    }

    /// A surface from rows of points — the general case everything smooth
    /// is built from. Each row is a loop (when `closed`) or a strip; rows
    /// run from one end of the shape to the other. Normals are worked out
    /// from the neighbouring points, and turned to face away from each row's
    /// `centres` entry, so shapes come out lit correctly whichever way round
    /// their rows were listed.
    mutating func sheet(_ rows: [[SIMD3<Float>]], closed: Bool, centres: [SIMD3<Float>]) {
        guard rows.count > 1, let width = rows.first?.count, width > 2 else { return }
        let columns = closed ? width + 1 : width
        func point(_ i: Int, _ j: Int) -> SIMD3<Float> {
            let row = rows[min(max(i, 0), rows.count - 1)]
            if closed { return row[((j % width) + width) % width] }
            return row[min(max(j, 0), width - 1)]
        }
        let base = UInt32(positions.count)
        for i in 0..<rows.count {
            for j in 0..<columns {
                let p = point(i, j)
                let du = point(i, j + 1) - point(i, j - 1)
                let dv = point(i + 1, j) - point(i - 1, j)
                var n = simd_cross(du, dv)
                let outward = p - centres[min(i, centres.count - 1)]
                if simd_length_squared(n) < 1e-14 { n = outward }
                if simd_dot(n, outward) < 0 { n = -n }
                positions.append(p)
                normals.append(simd_length_squared(n) > 1e-14 ? simd_normalize(n) : [0, 1, 0])
            }
        }
        // Pick the winding that agrees with the normals, judged on a quad
        // from the middle of the shape where nothing is degenerate.
        let mi = (rows.count - 1) / 2, mj = (columns - 1) / 2
        let a = Int(base) + mi * columns + mj
        let pa = positions[a], pb = positions[a + columns], pc = positions[a + 1]
        let flip = simd_dot(simd_cross(pb - pa, pc - pa), normals[a]) < 0
        let stride = UInt32(columns)
        for i in 0..<UInt32(rows.count - 1) {
            for j in 0..<UInt32(columns - 1) {
                let a = base + i * stride + j
                let b = a + stride
                if flip { indices += [a, a + 1, b, a + 1, b + 1, b] } else { indices += [a, b, a + 1, a + 1, b, b + 1] }
            }
        }
    }

    /// A tube through a list of rings — a limb, a torso, a palm trunk.
    /// Each ring is an ellipse at right angles to the path, `rx` across and
    /// `rz` through. `capped` rounds both ends off.
    mutating func loft(
        _ rings: [(centre: SIMD3<Float>, rx: Float, rz: Float)],
        segments: Int = 20,
        capped: Bool = true,
        capStart: Bool? = nil,
        capEnd: Bool? = nil,
        ripple: (count: Int, amount: Float) = (0, 0)
    ) {
        guard rings.count > 1 else { return }
        var path = rings
        let closeStart = capStart ?? capped, closeEnd = capEnd ?? capped
        if closeStart || closeEnd {
            let startDir = simd_normalize(rings[1].centre - rings[0].centre)
            let endDir = simd_normalize(rings[rings.count - 1].centre - rings[rings.count - 2].centre)
            let first = rings[0], last = rings[rings.count - 1]
            let r0 = max(first.rx, first.rz), r1 = max(last.rx, last.rz)
            if closeStart {
                path.insert((first.centre - startDir * r0 * 0.38, first.rx * 0.72, first.rz * 0.72), at: 0)
                path.insert((first.centre - startDir * r0 * 0.6, first.rx * 0.08, first.rz * 0.08), at: 0)
            }
            if closeEnd {
                path.append((last.centre + endDir * r1 * 0.38, last.rx * 0.72, last.rz * 0.72))
                path.append((last.centre + endDir * r1 * 0.6, last.rx * 0.08, last.rz * 0.08))
            }
        }
        var rows: [[SIMD3<Float>]] = []
        for (i, ring) in path.enumerated() {
            let ahead = path[min(i + 1, path.count - 1)].centre - path[max(i - 1, 0)].centre
            let t = simd_length(ahead) > 1e-6 ? simd_normalize(ahead) : SIMD3<Float>(0, -1, 0)
            let reference: SIMD3<Float> = abs(t.z) < 0.9 ? [0, 0, 1] : [0, 1, 0]
            let across = simd_normalize(simd_cross(t, reference))
            let through = simd_normalize(simd_cross(t, across))
            var row: [SIMD3<Float>] = []
            for s in 0..<segments {
                let u = Float(s) / Float(segments) * 2 * .pi
                let k = 1 + ripple.amount * cos(Float(ripple.count) * u)
                row.append(ring.centre + across * (cos(u) * ring.rx * k) + through * (sin(u) * ring.rz * k))
            }
            rows.append(row)
        }
        sheet(rows, closed: true, centres: path.map(\.centre))
    }

    /// A flat ribbon along a path, lying on the ground.
    mutating func ribbon(_ points: [SIMD3<Float>], width: Float, closed: Bool) {
        let count = points.count
        guard count > 1 else { return }
        let start = UInt32(positions.count)
        for i in 0..<count {
            let next = points[(i + 1) % count]
            let previous = points[(i - 1 + count) % count]
            var along = (closed || (i > 0 && i < count - 1)) ? next - previous : (i == 0 ? next - points[i] : points[i] - previous)
            along.y = 0
            let side = simd_normalize(SIMD3<Float>(-along.z, 0, along.x)) * (width / 2)
            positions += [points[i] - side, points[i] + side]
            normals += [[0, 1, 0], [0, 1, 0]]
        }
        // Wind the triangles so they face the sky, whichever way the path
        // runs: a ribbon facing the ground is invisible from above.
        let p0 = positions[Int(start)], p1 = positions[Int(start) + 1], p2 = positions[Int(start) + 2]
        let facesUp = simd_cross(p2 - p0, p1 - p0).y > 0
        let segments = closed ? count : count - 1
        for i in 0..<segments {
            let a = start + UInt32(i * 2)
            let b = start + UInt32(((i + 1) % count) * 2)
            if facesUp { indices += [a, b, a + 1, a + 1, b, b + 1] } else { indices += [a, a + 1, b, a + 1, b + 1, b] }
        }
    }

    /// Pours another batch into this one.
    mutating func append(_ other: MeshBatch) {
        let base = UInt32(positions.count)
        positions += other.positions
        normals += other.normals
        indices += other.indices.map { $0 + base }
    }

    func mesh() -> MeshResource? {
        guard !isEmpty else { return nil }
        var descriptor = MeshDescriptor()
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    func entity(_ material: some RealityKit.Material) -> ModelEntity? {
        guard let mesh = mesh() else { return nil }
        return ModelEntity(mesh: mesh, materials: [material])
    }
}

// MARK: - Repeatable randomness

/// The park is scattered at random, but the same random every visit — and,
/// more to the point, the same on both phones, so the tree your partner is
/// standing beside is the tree you see them beside.
struct ParkRandom {

    private var generator: SeededGenerator

    init(seed: UInt64) { generator = SeededGenerator(seed: seed) }

    /// 0..<1
    mutating func unit() -> Float {
        Float(generator.next() >> 40) / Float(1 << 24)
    }

    mutating func range(_ low: Float, _ high: Float) -> Float {
        low + (high - low) * unit()
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[min(items.count - 1, Int(unit() * Float(items.count)))]
    }
}

// MARK: - Sky light

/// Soft light from the whole sky, as well as the sun.
///
/// A directional light on its own lights one side of everything and leaves
/// the other side flat and grey — the look that makes a scene read as a
/// "3D model" rather than a place. Real daylight comes from the whole sky,
/// blue from above and warm off the sand below, and that is what this is:
/// a picture of the sky, wrapped round the scene and used as a light.
@available(iOS 18.0, *)
enum ParkSkyLight {

    static func make(zenith: UIColor, horizon: UIColor, ground: UIColor) async -> Entity? {
        let width = 512, height = 256
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [zenith.cgColor, horizon.cgColor, horizon.cgColor, ground.cgColor, ground.cgColor] as CFArray,
                                        locations: [0, 0.46, 0.5, 0.56, 1])
        else { return nil }
        // Core Graphics draws bottom-up; equirectangular images are top-down.
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: .zero, options: [])
        guard let image = context.makeImage(),
              let environment = try? await EnvironmentResource(equirectangular: image)
        else { return nil }
        let light = Entity()
        light.components.set(ImageBasedLightComponent(source: .single(environment), intensityExponent: 0.4))
        return light
    }

    /// Lets everything under `root` be lit by `light`.
    static func apply(_ light: Entity, to root: Entity) {
        if root is ModelEntity {
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        }
        for child in root.children { apply(light, to: child) }
    }
}

// MARK: - Japanese trees

/// Trees grown the way trees grow: a trunk that forks into limbs, limbs
/// that fork into branches, each a little thinner and shorter than the one
/// before and heading off at its own angle, with blossom or leaves gathered
/// at the ends. Every tree comes out different, and you can see sky through
/// the gaps between the branches — which is what makes them read as trees
/// rather than lollipops.
enum JapaneseTree {

    enum Kind { case sakura, maple }

    /// Grows one tree. Bark goes into `bark`; blossom or leaf clusters are
    /// spread across the `crowns` batches for a mix of shades. Returns the
    /// middle of the canopy, for petals to fall from.
    @discardableResult
    static func grow(
        _ kind: Kind,
        at base: SIMD3<Float>,
        size: Float,
        rng: inout ParkRandom,
        bark: inout MeshBatch,
        crowns: inout [MeshBatch]
    ) -> SIMD3<Float> {
        var tips: [SIMD3<Float>] = []
        let trunkLength: Float = (kind == .sakura ? 1.35 : 1.7) * size
        let lean = SIMD3<Float>(rng.range(-0.12, 0.12), 1, rng.range(-0.12, 0.12))

        // Roots flaring out into the ground.
        for k in 0..<5 {
            let a = Float(k) / 5 * 2 * .pi + rng.range(0, 0.8)
            bark.blob(base + [cos(a) * 0.2 * size, 0.05, sin(a) * 0.2 * size], [0.16 * size, 0.08 * size, 0.08 * size],
                      turn: spin(-a, [0, 1, 0]), rings: 4, segments: 6)
        }
        branch(from: base, direction: simd_normalize(lean), length: trunkLength, radius: 0.2 * size, depth: 3,
               spread: kind == .sakura ? (0.75, 1.15) : (0.4, 0.75), rise: kind == .sakura ? 0.02 : 0.18,
               rng: &rng, bark: &bark, tips: &tips)

        // Blossom gathered at every branch end, in soft overlapping clumps:
        // three fat ones rather than five small, which looks just as full
        // from a few steps away and costs a third as much to draw.
        for tip in tips {
            for _ in 0..<3 {
                let offset = SIMD3<Float>(rng.range(-0.3, 0.3), rng.range(-0.16, 0.2), rng.range(-0.3, 0.3)) * size
                let r = rng.range(0.25, 0.42) * size
                let shade = Int(rng.unit() * Float(crowns.count)) % crowns.count
                crowns[shade].blob(tip + offset, [r, r * 0.78, r], turn: spin(rng.range(0, 3), [0, 1, 0]), rings: 4, segments: 7)
            }
        }
        return tips.reduce(.zero, +) / Float(max(1, tips.count))
    }

    private static func branch(
        from start: SIMD3<Float>,
        direction: SIMD3<Float>,
        length: Float,
        radius: Float,
        depth: Int,
        spread: (Float, Float),
        rise: Float,
        rng: inout ParkRandom,
        bark: inout MeshBatch,
        tips: inout [SIMD3<Float>]
    ) {
        // A gentle kink part way along, so no branch is a straight stick.
        let bend = SIMD3<Float>(rng.range(-0.2, 0.2), rng.range(-0.08, 0.12), rng.range(-0.2, 0.2))
        let middle = start + direction * length * 0.5 + bend * length * 0.25
        let end = start + simd_normalize(direction + bend * 0.5) * length
        bark.loft([(start, radius, radius), (middle, radius * 0.86, radius * 0.86), (end, radius * 0.7, radius * 0.7)],
                  segments: radius > 0.1 ? 12 : (radius > 0.04 ? 8 : 5))

        if depth == 0 {
            tips.append(end)
            return
        }
        let children = depth == 3 ? Int(rng.range(3, 4.99)) : Int(rng.range(2, 3.99))
        let side = abs(direction.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let across = simd_normalize(simd_cross(direction, side))
        let through = simd_cross(direction, across)
        let twist = rng.range(0, 2 * .pi)
        for k in 0..<children {
            let around = twist + Float(k) / Float(children) * 2 * .pi + rng.range(-0.4, 0.4)
            let tilt = rng.range(spread.0, spread.1) * (depth == 3 ? 1 : 0.7)
            var heading = direction * cos(tilt) + (across * cos(around) + through * sin(around)) * sin(tilt)
            heading.y += rise
            if depth == 1 { heading.y -= 0.12 }   // the outermost twigs droop
            let from = start + (end - start) * rng.range(0.82, 1.0)
            branch(from: from, direction: simd_normalize(heading), length: length * rng.range(0.62, 0.78),
                   radius: radius * 0.64, depth: depth - 1, spread: spread, rise: rise, rng: &rng, bark: &bark, tips: &tips)
        }
    }
}

// MARK: - Solid footprints

/// A building's footprint on the ground, and how tall it is: something you
/// walk round and the camera does not pass through.
struct ParkBlock {
    var minX: Float, maxX: Float, minZ: Float, maxZ: Float
    var height: Float

    init(centre: SIMD2<Float>, half: SIMD2<Float>, height: Float) {
        minX = centre.x - half.x; maxX = centre.x + half.x
        minZ = centre.y - half.y; maxZ = centre.y + half.y
        self.height = height
    }

    init(minX: Float, maxX: Float, minZ: Float, maxZ: Float, height: Float) {
        self.minX = minX; self.maxX = maxX; self.minZ = minZ; self.maxZ = maxZ
        self.height = height
    }

    /// Moves `p` out of the footprint by the shortest way, keeping `radius`
    /// clear of the walls.
    func pushOut(_ p: SIMD2<Float>, radius: Float) -> SIMD2<Float> {
        let left = p.x - (minX - radius), right = (maxX + radius) - p.x
        let front = p.y - (minZ - radius), back = (maxZ + radius) - p.y
        guard left > 0, right > 0, front > 0, back > 0 else { return p }
        let least = min(left, right, front, back)
        if least == left { return [minX - radius, p.y] }
        if least == right { return [maxX + radius, p.y] }
        if least == front { return [p.x, minZ - radius] }
        return [p.x, maxZ + radius]
    }

    /// Whether a point in the air is inside it, give or take `margin`.
    func contains(_ p: SIMD3<Float>, margin: Float) -> Bool {
        p.x > minX - margin && p.x < maxX + margin && p.z > minZ - margin && p.z < maxZ + margin && p.y < height + margin
    }
}
