//
//  ZiggyParkAnimals.swift
//  Ziggy
//
//  The animals of Hanami Park.
//
//  Fifteen kinds live in the park, each in its own corner: deer under the
//  cherry blossom, bunnies in the rapeseed, a calico cat napping by the tea
//  pavilion, a tanuki in the bamboo, a fox at the shrine, frogs on the lily
//  pads, a pair of swans on the lake, squirrels in the maples, sparrows on
//  the paths, turtles on the bank, a duck and her ducklings, koi, and a
//  snow monkey soaking in the hot spring. Two only come out at night: an
//  owl in Maple Valley, and a white spirit fox at the shrine.
//
//  They get on with their own lives — wandering, grazing, napping, hopping
//  from pad to pad — and notice you. Deer wander over when you stand still;
//  sparrows and squirrels scatter if you rush at them. Walk up to one and
//  you can pet it (or wave, or feed the koi), and it answers in its own way:
//  the deer bows, the tanuki drums his tummy, the swans touch beaks and make
//  a heart.
//
//  Animals are only for looking at and saying hello to, so each phone
//  runs its own; they are not kept in step between phones.
//

import RealityKit
import UIKit

// MARK: - Who they are

enum ParkFriend: String, CaseIterable, Identifiable {
    case deer, bunny, cat, tanuki, fox, frog, swan, squirrel, sparrow, turtle, duck, koi, monkey, owl, spiritFox

    var id: String { rawValue }

    var name: String {
        switch self {
        case .deer: return "Momiji"
        case .bunny: return "Mochi"
        case .cat: return "Tama"
        case .tanuki: return "Pon"
        case .fox: return "Kitsu"
        case .frog: return "Kero"
        case .swan: return "Hana & Yuki"
        case .squirrel: return "Kurumi"
        case .sparrow: return "Chun"
        case .turtle: return "Kame"
        case .duck: return "Ahiru"
        case .koi: return "Nishiki"
        case .monkey: return "Saru-san"
        case .owl: return "Fuku"
        case .spiritFox: return "Tsuki"
        }
    }

    var species: String {
        switch self {
        case .deer: return "Nara deer"
        case .bunny: return "Bunny"
        case .cat: return "Calico cat"
        case .tanuki: return "Tanuki"
        case .fox: return "Red fox"
        case .frog: return "Little frog"
        case .swan: return "Swan couple"
        case .squirrel: return "Squirrel"
        case .sparrow: return "Sparrow"
        case .turtle: return "Pond turtle"
        case .duck: return "Mother duck"
        case .koi: return "Koi"
        case .monkey: return "Snow monkey"
        case .owl: return "Owl"
        case .spiritFox: return "Spirit fox"
        }
    }

    var emoji: String {
        switch self {
        case .deer: return "🦌"
        case .bunny: return "🐰"
        case .cat: return "🐱"
        case .tanuki: return "🦝"
        case .fox: return "🦊"
        case .frog: return "🐸"
        case .swan: return "🦢"
        case .squirrel: return "🐿️"
        case .sparrow: return "🐦"
        case .turtle: return "🐢"
        case .duck: return "🦆"
        case .koi: return "🐟"
        case .monkey: return "🐒"
        case .owl: return "🦉"
        case .spiritFox: return "🦊"
        }
    }

    /// A small drawn icon for them on the hello button.
    var symbol: String {
        switch self {
        case .bunny: return "hare.fill"
        case .cat: return "cat.fill"
        case .turtle: return "tortoise.fill"
        case .koi: return "fish.fill"
        case .swan, .duck, .sparrow, .owl: return "bird.fill"
        case .spiritFox: return "sparkles"
        default: return "pawprint.fill"
        }
    }

    /// What you do when you walk up to them.
    var action: String {
        switch self {
        case .deer, .bunny, .cat, .fox: return "Pet"
        case .tanuki, .turtle: return "Pat"
        case .frog, .sparrow: return "Say hi to"
        case .swan, .duck, .monkey: return "Wave to"
        case .squirrel: return "Offer a nut to"
        case .koi: return "Feed"
        case .owl: return "Hoot at"
        case .spiritFox: return "Bow to"
        }
    }

    var fact: String {
        switch self {
        case .deer: return "Nara deer bow politely when they'd like a treat."
        case .bunny: return "Mochi's nose never, ever stops wiggling."
        case .cat: return "Tama has napped in every sunny spot in the park."
        case .tanuki: return "Pon drums on his round tummy when he's happy."
        case .fox: return "Kitsu is the shrine's official greeter."
        case .frog: return "Kero is how frogs say ribbit in Japanese."
        case .swan: return "Swans pair for life — just like you two."
        case .squirrel: return "Kurumi means walnut. Guess her favourite snack."
        case .sparrow: return "Chun-chun is what sparrows sing in Japan."
        case .turtle: return "Kame takes life slowly, and loves every minute."
        case .duck: return "Ahiru never lets her ducklings out of sight."
        case .koi: return "Koi can live for more than a hundred years."
        case .monkey: return "Saru-san's towel has never once fallen off."
        case .owl: return "Fukurou sounds like 'no hardship' — a lucky bird."
        case .spiritFox: return "Seeing a spirit fox means good luck for you both."
        }
    }

    /// The colour behind their face on the hello button.
    var tint: UInt32 {
        switch self {
        case .deer: return 0xF6D9B8
        case .bunny: return 0xFBE3EC
        case .cat: return 0xFFE7C7
        case .tanuki: return 0xE5D8C9
        case .fox: return 0xFFD6B8
        case .frog: return 0xD8F0C8
        case .swan: return 0xDDEBFF
        case .squirrel: return 0xF2D3BC
        case .sparrow: return 0xEFE3D2
        case .turtle: return 0xD5EBD0
        case .duck: return 0xFFF2BF
        case .koi: return 0xFFDCCF
        case .monkey: return 0xF7D8D0
        case .owl: return 0xE2D6F2
        case .spiritFox: return 0xE4E0FF
        }
    }
}

// MARK: - Building them

/// One animal's shapes, a batch per colour, so each part is a few draws.
private struct Coat {

    var batches: [UInt32: MeshBatch] = [:]
    static let eye: UInt32 = 0x1E1A1A
    static let shine: UInt32 = 0xFFFFFE
    static let blush: UInt32 = 0xFF9FB4

    mutating func ball(_ colour: UInt32, _ p: SIMD3<Float>, _ r: SIMD3<Float>, turn: simd_quatf = spin(0, [0, 1, 0]), fine: Bool = false) {
        batches[colour, default: MeshBatch()].blob(p, r, turn: turn, rings: fine ? 8 : 5, segments: fine ? 12 : 8)
    }

    mutating func ball(_ colour: UInt32, _ p: SIMD3<Float>, _ r: Float, fine: Bool = false) {
        ball(colour, p, [r, r, r], fine: fine)
    }

    mutating func stick(_ colour: UInt32, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ r: Float) {
        batches[colour, default: MeshBatch()].loft([(a, r, r), (b, r * 0.85, r * 0.85)], segments: 6)
    }

    mutating func cone(_ colour: UInt32, _ base: SIMD3<Float>, height: Float, radius: Float, lean: simd_quatf = spin(0, [0, 1, 0])) {
        batches[colour, default: MeshBatch()].tube(base: base, height: height, radius: radius, topRadius: 0, lean: lean, segments: 7)
    }

    /// Two shiny eyes with a glint, and pink cheeks.
    mutating func face(eyes: Float, at y: Float, forward z: Float, size r: Float, cheeks: Bool = true) {
        for side: Float in [-1, 1] {
            ball(Self.eye, [side * eyes, y, z], [r, r * 1.15, r * 0.7], fine: true)
            ball(Self.shine, [side * eyes + r * 0.3, y + r * 0.45, z + r * 0.45], r * 0.35)
            if cheeks { ball(Self.blush, [side * (eyes + r * 1.3), y - r * 1.6, z - r * 0.4], [r * 0.9, r * 0.55, r * 0.35]) }
        }
    }

    func dress(_ entity: Entity, glow: Set<UInt32> = []) {
        for (colour, batch) in batches {
            let material: any RealityKit.Material
            if colour == Self.eye { material = ParkPaint.glossy(UIColor(colour), roughness: 0.15) }
            else if colour == Self.shine || glow.contains(colour) { material = ParkPaint.glow(UIColor(colour)) }
            else { material = ParkPaint.soft(UIColor(colour), sheen: 0.45) }
            if let part = batch.entity(material) { entity.addChild(part) }
        }
    }
}

// MARK: - The animals

@available(iOS 18.0, *)
final class ParkAnimals {

    let root = Entity()

    private enum Way {
        /// Wanders the grass round home.
        case roam
        /// Swims a loop round the lake, `ring` of the way out to the bank.
        case swim(ring: Float, speed: Float)
        /// Sits on a lily pad, and hops to another now and then.
        case pads
        /// Stays put (in the hot spring, on a perch).
        case still
    }

    private final class Animal {
        let kind: ParkFriend
        let way: Way
        let root = Entity()
        let body = Entity()
        let head = Entity()
        var tail: Entity?
        var limbs: [Entity] = []
        var extras: [Entity] = []
        var bodyRest: SIMD3<Float> = .zero
        var headRest: SIMD3<Float> = .zero

        var home: SIMD2<Float>
        var range: Float
        var position: SIMD2<Float>
        var height: Float = 0
        var target: SIMD2<Float>
        var heading: Float = 0
        var speed: Float = 0.5
        var rest: Float = 0
        var gait: Float = 0
        var hop: Float = 0
        var hopHeight: Float = 0
        var shy = false
        var curious = false
        var sleepy = false
        var sleeping: Float = 0
        var react: Float = -1
        var appear: Float = 1
        var nightOnly = false
        var dayOnly = false
        var phase = Float.random(in: 0...10)
        var swimAt: Float = 0
        var size: Float = 1
        /// How close you have to be to say hello.
        var reach: Float = 1.9
        var cull: Float = 50

        init(_ kind: ParkFriend, way: Way, home: SIMD2<Float>, range: Float) {
            self.kind = kind
            self.way = way
            self.home = home
            self.range = range
            position = home
            target = home
            root.addChild(body)
            body.addChild(head)
        }

        var visible: Bool { root.isEnabled }
        var headWorld: SIMD3<Float> { head.position(relativeTo: nil) }
    }

    private var animals: [Animal] = []
    private var rng = ParkRandom(seed: 0xF00D)
    private var clock: Float = 0
    private var lilyPads: [SIMD3<Float>] = []

    init() {}

    // MARK: Moving in

    func build(in park: ParkHanami) {
        lilyPads = park.lilyPads
        func at(_ u: Float, _ v: Float) -> SIMD2<Float> { ParkHanami.at(u, v) }
        var rng = ParkRandom(seed: 0xA1A1)

        for k in 0..<3 { add(deer(), way: .roam, home: at(28, -30) + [Float(k) * 3 - 3, Float(k % 2) * 3], range: 11, speed: 0.55) { $0.curious = true } }
        for k in 0..<4 {
            add(bunny(brown: k == 1), way: .roam, home: k == 3 ? at(-5, 30) : at(-40, -27), range: 7, speed: 0.9) { $0.hopHeight = 0.12 }
        }
        add(cat(), way: .roam, home: at(26, 28), range: 4, speed: 0.35) { $0.sleepy = true; $0.curious = true }
        add(cat(), way: .roam, home: at(-14, -30), range: 5, speed: 0.35) { $0.sleepy = true }
        add(tanuki(), way: .roam, home: at(-34, 20), range: 6, speed: 0.45)
        add(fox(spirit: false), way: .roam, home: at(-24, 35), range: 4, speed: 0.6) { $0.dayOnly = true; $0.curious = true }
        add(fox(spirit: true), way: .roam, home: at(-24, 36), range: 3, speed: 0.4) { $0.nightOnly = true; $0.curious = true; $0.height = 0.08 }
        for _ in 0..<4 { add(frog(), way: .pads, home: at(0, 0), range: 0, speed: 0) { $0.reach = 3.2; $0.cull = 30 } }
        for k in 0..<2 { add(swan(), way: .swim(ring: 0.82, speed: 0.012), home: at(0, 0), range: 0, speed: 0) { $0.swimAt = Float(k) * 0.012; $0.reach = 3.4 } }
        for k in 0..<2 { add(squirrel(), way: .roam, home: at(45, 6) + [Float(k) * 4 - 2, 0], range: 8, speed: 1.1) { $0.shy = true; $0.hopHeight = 0.07; $0.cull = 30 } }
        for k in 0..<6 {
            add(sparrow(), way: .roam, home: k < 3 ? at(-20, -36) : at(-3, 21), range: 4, speed: 0.8) { $0.shy = true; $0.hopHeight = 0.05; $0.cull = 28 }
        }
        for k in 0..<2 {
            let i = (ParkHanami.lake.count / 2 + 40 + k * 14) % ParkHanami.lake.count
            let bank = ParkHanami.lake[i]
            let out = simd_normalize(bank - ParkHanami.lakeCentre)
            add(turtle(), way: .roam, home: bank + out * 1.6, range: 1.5, speed: 0.12) { $0.reach = 2.2; $0.cull = 30 }
        }
        for place in 0..<4 {
            add(duck(baby: place > 0), way: .swim(ring: 0.6, speed: 0.008), home: at(0, 0), range: 0, speed: 0) { $0.swimAt = -Float(place) * 0.012; $0.reach = 3.4 }
        }
        for k in 0..<6 {
            add(koi(k), way: .swim(ring: rng.range(0.72, 0.9), speed: rng.range(0.006, 0.014) * (k % 2 == 0 ? 1 : -1)), home: at(0, 0), range: 0, speed: 0) {
                $0.swimAt = Float(k) * 0.17
                $0.reach = 3.2
                $0.cull = 35
            }
        }
        add(monkey(), way: .still, home: ParkHanami.onsen + [0.5, 0.2], range: 0, speed: 0) { $0.reach = 3.4; $0.height = -0.2; $0.heading = .pi / 2 }
        buildPerch(at: at(37, 5))
        add(owl(), way: .still, home: at(37, 5), range: 0, speed: 0) { $0.nightOnly = true; $0.height = 1.25; $0.reach = 2.4; $0.heading = -.pi / 2 }

        for animal in animals {
            animal.position = animal.home
            animal.target = animal.home
            place(animal)
        }
    }

    private func add(_ parts: (Animal) -> Void, way: Way, home: SIMD2<Float>, range: Float, speed: Float, tune: ((Animal) -> Void)? = nil) {
        // The kind is filled in by the builder; a placeholder until then.
        let animal = Animal(currentKind, way: way, home: home, range: range)
        parts(animal)
        animal.speed = speed
        tune?(animal)
        animal.bodyRest = animal.body.position
        animal.headRest = animal.head.position
        animal.heading = animal.heading == 0 ? Float.random(in: 0...(2 * .pi)) : animal.heading
        root.addChild(animal.root)
        animals.append(animal)
    }

    /// Set by each builder, so `add` knows what it is adding.
    private var currentKind: ParkFriend = .deer

    private func buildPerch(at p: SIMD2<Float>) {
        var stump = MeshBatch()
        stump.tube(base: [p.x, 0, p.y], height: 1.2, radius: 0.22, topRadius: 0.18, segments: 10)
        stump.loft([([p.x, 0.9, p.y], 0.06, 0.06), ([p.x + 0.5, 1.4, p.y + 0.1], 0.04, 0.04)], segments: 5)
        if let e = stump.entity(ParkPaint.flat(UIColor(0x6B4A33))) { root.addChild(e) }
        var moss = MeshBatch()
        moss.blob([p.x, 1.2, p.y], [0.2, 0.05, 0.18], rings: 3, segments: 8)
        if let e = moss.entity(ParkPaint.soft(UIColor(0x6FA052))) { root.addChild(e) }
    }

    // MARK: Models
    //
    // Every animal faces +Z with its feet on the ground at y = 0. The head is
    // its own entity, so it can look about, nod and bow.

    private func deer() -> (Animal) -> Void {
        currentKind = .deer
        return { a in
            let brown: UInt32 = 0xC8874E, cream: UInt32 = 0xF4E2C6, dark: UInt32 = 0x4A3426
            var body = Coat()
            body.ball(brown, [0, 0.5, 0], [0.17, 0.16, 0.27], fine: true)
            body.ball(cream, [0, 0.44, 0.02], [0.14, 0.11, 0.23])
            for k in 0..<6 {
                body.ball(0xFFF6E8, [Float(k % 2) * 0.14 - 0.07, 0.64, Float(k / 2) * 0.12 - 0.12], [0.03, 0.012, 0.03])
            }
            for x: Float in [-0.09, 0.09] {
                for z: Float in [-0.16, 0.16] {
                    body.stick(brown, [x, 0.42, z], [x, 0.05, z], 0.035)
                    body.ball(dark, [x, 0.03, z], [0.035, 0.03, 0.04])
                }
            }
            body.stick(brown, [0, 0.55, 0.17], [0, 0.7, 0.24], 0.07)
            body.ball(0xFFFFFF, [0, 0.56, -0.27], [0.05, 0.06, 0.04])
            body.dress(a.body)

            var head = Coat()
            head.ball(brown, [0, 0.04, 0.03], [0.13, 0.12, 0.13], fine: true)
            head.ball(cream, [0, 0.0, 0.13], [0.075, 0.065, 0.07], fine: true)
            head.ball(dark, [0, 0.02, 0.2], [0.028, 0.022, 0.02])
            head.face(eyes: 0.062, at: 0.06, forward: 0.12, size: 0.026)
            for side: Float in [-1, 1] {
                head.ball(brown, [side * 0.14, 0.1, 0.0], [0.085, 0.035, 0.05], turn: spin(side * -0.4, [0, 0, 1]))
                head.ball(0xF2B8A8, [side * 0.145, 0.1, 0.012], [0.06, 0.02, 0.03], turn: spin(side * -0.4, [0, 0, 1]))
                head.cone(0xE9D6B4, [side * 0.05, 0.13, -0.01], height: 0.06, radius: 0.018)
            }
            head.dress(a.head)
            a.head.position = [0, 0.74, 0.27]
        }
    }

    private func bunny(brown: Bool) -> (Animal) -> Void {
        currentKind = .bunny
        return { a in
            let fur: UInt32 = brown ? 0xC79A72 : 0xFFFFFF
            var body = Coat()
            body.ball(fur, [0, 0.12, -0.02], [0.11, 0.1, 0.13], fine: true)
            body.ball(0xFFFFFF, [0, 0.13, -0.15], 0.045)
            for side: Float in [-1, 1] {
                body.ball(fur, [side * 0.06, 0.03, 0.08], [0.03, 0.025, 0.045])
                body.ball(fur, [side * 0.08, 0.05, -0.06], [0.04, 0.045, 0.07])
            }
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], [0.09, 0.085, 0.085], fine: true)
            head.face(eyes: 0.042, at: 0.01, forward: 0.07, size: 0.018)
            head.ball(0xFF8FA8, [0, -0.02, 0.085], [0.016, 0.012, 0.01])
            head.dress(a.head)
            for side: Float in [-1, 1] {
                let ear = Entity()
                var coat = Coat()
                coat.ball(fur, [0, 0.07, 0], [0.026, 0.075, 0.015], fine: true)
                coat.ball(0xFFB3C4, [0, 0.07, 0.008], [0.014, 0.06, 0.01])
                coat.dress(ear)
                ear.position = [side * 0.035, 0.06, -0.01]
                ear.orientation = spin(side * -0.18, [0, 0, 1])
                a.head.addChild(ear)
                a.extras.append(ear)
            }
            a.head.position = [0, 0.2, 0.08]
            a.size = 1
        }
    }

    private func cat() -> (Animal) -> Void {
        currentKind = .cat
        return { a in
            let white: UInt32 = 0xFFFBF5, orange: UInt32 = 0xF2A04A, black: UInt32 = 0x3A3433
            var body = Coat()
            body.ball(white, [0, 0.13, 0], [0.1, 0.09, 0.16], fine: true)
            body.ball(orange, [0.04, 0.17, -0.05], [0.07, 0.05, 0.08])
            body.ball(black, [-0.05, 0.16, 0.06], [0.05, 0.05, 0.06])
            for x: Float in [-0.06, 0.06] {
                for z: Float in [-0.1, 0.1] { body.ball(white, [x, 0.04, z], [0.032, 0.045, 0.035]) }
            }
            body.dress(a.body)
            var head = Coat()
            head.ball(white, [0, 0, 0], [0.1, 0.088, 0.088], fine: true)
            head.ball(orange, [0.05, 0.05, 0.0], [0.06, 0.05, 0.07])
            head.ball(black, [-0.055, 0.045, 0.005], [0.05, 0.045, 0.065])
            head.face(eyes: 0.042, at: 0.005, forward: 0.075, size: 0.017)
            head.ball(0xFF8FA8, [0, -0.02, 0.088], [0.012, 0.009, 0.008])
            head.cone(orange, [0.055, 0.06, 0], height: 0.07, radius: 0.035, lean: spin(-0.3, [0, 0, 1]))
            head.cone(black, [-0.055, 0.06, 0], height: 0.07, radius: 0.035, lean: spin(0.3, [0, 0, 1]))
            head.dress(a.head)
            a.head.position = [0, 0.24, 0.13]
            let tail = Entity()
            var t = Coat()
            t.batches[orange, default: MeshBatch()].loft([([0, 0, 0], 0.022, 0.022), ([0, 0.08, -0.06], 0.02, 0.02), ([0, 0.17, -0.05], 0.018, 0.018), ([0, 0.22, 0.0], 0.016, 0.016)], segments: 6)
            t.dress(tail)
            tail.position = [0, 0.15, -0.15]
            a.body.addChild(tail)
            a.tail = tail
        }
    }

    private func tanuki() -> (Animal) -> Void {
        currentKind = .tanuki
        return { a in
            let fur: UInt32 = 0x9A7B5F, dark: UInt32 = 0x3E3229, cream: UInt32 = 0xF2E2C8
            var body = Coat()
            body.ball(fur, [0, 0.2, 0], [0.16, 0.17, 0.15], fine: true)
            body.ball(cream, [0, 0.18, 0.08], [0.11, 0.12, 0.08], fine: true)
            for side: Float in [-1, 1] {
                body.ball(dark, [side * 0.09, 0.04, 0.03], [0.045, 0.04, 0.05])
                body.ball(dark, [side * 0.14, 0.2, 0.05], [0.035, 0.06, 0.035])
            }
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], [0.12, 0.105, 0.105], fine: true)
            head.ball(cream, [0, -0.03, 0.08], [0.055, 0.045, 0.045])
            for side: Float in [-1, 1] {
                head.ball(dark, [side * 0.05, 0.005, 0.07], [0.045, 0.032, 0.03], turn: spin(side * 0.3, [0, 0, 1]))
                head.ball(dark, [side * 0.075, 0.09, -0.01], [0.035, 0.03, 0.02])
            }
            head.ball(Coat.shine, [-0.042, 0.015, 0.1], 0.012)
            head.ball(Coat.shine, [0.058, 0.015, 0.1], 0.012)
            head.ball(dark, [0, -0.015, 0.125], [0.018, 0.014, 0.012])
            head.ball(Coat.blush, [-0.085, -0.04, 0.07], [0.022, 0.014, 0.01])
            head.ball(Coat.blush, [0.085, -0.04, 0.07], [0.022, 0.014, 0.01])
            head.dress(a.head)
            a.head.position = [0, 0.43, 0.03]
            let tail = Entity()
            var t = Coat()
            t.ball(fur, [0, 0, -0.06], [0.06, 0.06, 0.1])
            t.ball(dark, [0, 0, -0.13], [0.05, 0.05, 0.04])
            t.dress(tail)
            tail.position = [0, 0.12, -0.13]
            a.body.addChild(tail)
            a.tail = tail
        }
    }

    private func fox(spirit: Bool) -> (Animal) -> Void {
        currentKind = spirit ? .spiritFox : .fox
        return { a in
            let fur: UInt32 = spirit ? 0xFFFFFF : 0xF08A3C
            let white: UInt32 = spirit ? 0xFFF4FA : 0xFFFFFF
            let dark: UInt32 = spirit ? 0xE24A5B : 0x3A2A22
            var body = Coat()
            body.ball(fur, [0, 0.22, 0], [0.1, 0.1, 0.19], fine: true)
            body.ball(white, [0, 0.2, 0.12], [0.07, 0.08, 0.07])
            for x: Float in [-0.06, 0.06] {
                for z: Float in [-0.12, 0.12] { body.stick(dark, [x, 0.17, z], [x, 0.02, z], 0.026) }
            }
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], [0.1, 0.09, 0.095], fine: true)
            head.ball(white, [0, -0.03, 0.08], [0.05, 0.035, 0.07])
            head.ball(Coat.eye, [0, -0.015, 0.15], [0.016, 0.013, 0.012])
            head.face(eyes: 0.045, at: 0.015, forward: 0.075, size: 0.016)
            for side: Float in [-1, 1] {
                head.cone(fur, [side * 0.055, 0.06, -0.01], height: 0.11, radius: 0.04, lean: spin(side * -0.25, [0, 0, 1]))
                head.cone(dark, [side * 0.07, 0.13, -0.01], height: 0.045, radius: 0.017, lean: spin(side * -0.25, [0, 0, 1]))
            }
            if spirit {
                head.ball(0xE24A5B, [0, 0.07, 0.07], [0.012, 0.03, 0.006])
            }
            head.dress(a.head, glow: spirit ? [0xE24A5B] : [])
            a.head.position = [0, 0.33, 0.2]
            let tail = Entity()
            var t = Coat()
            t.ball(fur, [0, 0.03, -0.12], [0.07, 0.075, 0.15], fine: true)
            t.ball(white, [0, 0.05, -0.25], [0.05, 0.05, 0.05])
            t.dress(tail, glow: spirit ? [0xFFF4FA] : [])
            tail.position = [0, 0.24, -0.17]
            tail.orientation = spin(-0.4, [1, 0, 0])
            a.body.addChild(tail)
            a.tail = tail
            if spirit {
                // Little blue fox-fire lights floating round her.
                for _ in 0..<3 {
                    let flame = ModelEntity(mesh: ParkMesh.sphere(0.035), materials: [ParkPaint.glow(UIColor(0xA8D8FF))])
                    flame.addChild(ModelEntity(mesh: ParkMesh.sphere(0.07), materials: [ParkPaint.clear(UIColor(0xA8D8FF), opacity: 0.3)]))
                    a.root.addChild(flame)
                    a.extras.append(flame)
                }
            }
        }
    }

    private func frog() -> (Animal) -> Void {
        currentKind = .frog
        return { a in
            let green: UInt32 = 0x7CC46A
            var body = Coat()
            body.ball(green, [0, 0.045, 0], [0.065, 0.045, 0.07], fine: true)
            body.ball(0xE8F5C8, [0, 0.035, 0.02], [0.05, 0.03, 0.05])
            for side: Float in [-1, 1] { body.ball(green, [side * 0.06, 0.02, -0.03], [0.03, 0.02, 0.045]) }
            body.dress(a.body)
            var head = Coat()
            for side: Float in [-1, 1] {
                head.ball(green, [side * 0.03, 0.0, 0], [0.026, 0.026, 0.026], fine: true)
                head.ball(Coat.eye, [side * 0.03, 0.004, 0.018], [0.014, 0.016, 0.01])
                head.ball(Coat.shine, [side * 0.03 + 0.004, 0.01, 0.025], 0.005)
                head.ball(Coat.blush, [side * 0.05, -0.03, 0.04], [0.012, 0.008, 0.005])
            }
            head.dress(a.head)
            a.head.position = [0, 0.085, 0.035]
        }
    }

    private func swan() -> (Animal) -> Void {
        currentKind = .swan
        return { a in
            var body = Coat()
            body.ball(0xFFFFFF, [0, 0.12, 0], [0.16, 0.12, 0.26], fine: true)
            body.ball(0xFFFFFF, [0, 0.2, -0.18], [0.12, 0.08, 0.12], turn: spin(-0.5, [1, 0, 0]))
            body.batches[0xFFFFFF, default: MeshBatch()].loft([([0, 0.16, 0.18], 0.05, 0.05), ([0, 0.3, 0.24], 0.04, 0.04),
                                                               ([0, 0.42, 0.2], 0.037, 0.037), ([0, 0.5, 0.15], 0.035, 0.035)], segments: 8)
            body.dress(a.body)
            var head = Coat()
            head.ball(0xFFFFFF, [0, 0, 0], [0.045, 0.045, 0.06], fine: true)
            head.cone(0xFF9A3C, [0, -0.01, 0.04], height: 0.08, radius: 0.02, lean: spin(.pi / 2, [1, 0, 0]))
            head.ball(0x2B2523, [0, 0.0, 0.05], [0.02, 0.02, 0.015])
            head.face(eyes: 0.03, at: 0.012, forward: 0.035, size: 0.01, cheeks: false)
            head.dress(a.head)
            a.head.position = [0, 0.53, 0.17]
            for side: Float in [-1, 1] {
                let wing = Entity()
                var w = Coat()
                w.ball(0xF4F6FA, [side * 0.06, 0, -0.05], [0.07, 0.06, 0.2])
                w.dress(wing)
                wing.position = [side * 0.11, 0.16, 0]
                a.body.addChild(wing)
                a.limbs.append(wing)
            }
        }
    }

    private func squirrel() -> (Animal) -> Void {
        currentKind = .squirrel
        return { a in
            let fur: UInt32 = 0xB5653A, cream: UInt32 = 0xF4DEC4
            var body = Coat()
            body.ball(fur, [0, 0.07, 0], [0.05, 0.065, 0.06], fine: true)
            body.ball(cream, [0, 0.065, 0.035], [0.035, 0.05, 0.03])
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], [0.048, 0.044, 0.045], fine: true)
            head.face(eyes: 0.022, at: 0.008, forward: 0.036, size: 0.009)
            head.cone(fur, [0.025, 0.03, -0.005], height: 0.035, radius: 0.012)
            head.cone(fur, [-0.025, 0.03, -0.005], height: 0.035, radius: 0.012)
            head.dress(a.head)
            a.head.position = [0, 0.14, 0.03]
            let tail = Entity()
            var t = Coat()
            t.batches[fur, default: MeshBatch()].loft([([0, 0, 0], 0.025, 0.025), ([0, 0.06, -0.05], 0.045, 0.045),
                                                       ([0, 0.15, -0.05], 0.05, 0.05), ([0, 0.2, 0.0], 0.035, 0.035)], segments: 8)
            t.dress(tail)
            tail.position = [0, 0.04, -0.05]
            a.body.addChild(tail)
            a.tail = tail
        }
    }

    private func sparrow() -> (Animal) -> Void {
        currentKind = .sparrow
        return { a in
            var body = Coat()
            body.ball(0x9C6B45, [0, 0.045, 0], [0.038, 0.035, 0.05], fine: true)
            body.ball(0xF2E6D2, [0, 0.04, 0.02], [0.03, 0.026, 0.03])
            body.ball(0x6B4A33, [0, 0.05, -0.055], [0.014, 0.008, 0.03])
            body.dress(a.body)
            var head = Coat()
            head.ball(0x7A4E32, [0, 0, 0], 0.03, fine: true)
            head.ball(0xFFFFFF, [0, -0.008, 0.012], [0.026, 0.016, 0.02])
            head.cone(0x3A3433, [0, -0.002, 0.024], height: 0.018, radius: 0.007, lean: spin(.pi / 2, [1, 0, 0]))
            head.face(eyes: 0.015, at: 0.006, forward: 0.024, size: 0.006, cheeks: false)
            head.ball(0x2B2523, [0.024, -0.005, 0.006], 0.008)
            head.ball(0x2B2523, [-0.024, -0.005, 0.006], 0.008)
            head.dress(a.head)
            a.head.position = [0, 0.085, 0.03]
        }
    }

    private func turtle() -> (Animal) -> Void {
        currentKind = .turtle
        return { a in
            var body = Coat()
            body.ball(0x5E8C4A, [0, 0.06, 0], [0.12, 0.07, 0.15], fine: true)
            for k in 0..<5 {
                let ang = Float(k) / 5 * 2 * .pi
                body.ball(0x7FAE5E, [cos(ang) * 0.05, 0.115, sin(ang) * 0.06], [0.035, 0.012, 0.035])
            }
            body.ball(0x9CC46A, [0, 0.03, 0], [0.11, 0.025, 0.14])
            for x: Float in [-0.09, 0.09] {
                for z: Float in [-0.09, 0.09] { body.ball(0x9CC46A, [x, 0.02, z], [0.03, 0.02, 0.035]) }
            }
            body.dress(a.body)
            var head = Coat()
            head.ball(0x9CC46A, [0, 0, 0], [0.04, 0.038, 0.05], fine: true)
            head.face(eyes: 0.022, at: 0.012, forward: 0.035, size: 0.008)
            head.dress(a.head)
            a.head.position = [0, 0.06, 0.17]
        }
    }

    private func duck(baby: Bool) -> (Animal) -> Void {
        currentKind = .duck
        return { a in
            let s: Float = baby ? 0.55 : 1
            let fur: UInt32 = baby ? 0xFFD84D : 0xFFFFFF
            var body = Coat()
            body.ball(fur, [0, 0.12 * s, 0], [0.2 * s, 0.15 * s, 0.27 * s], fine: true)
            body.ball(fur, [0, 0.18 * s, -0.26 * s], [0.08 * s, 0.05 * s, 0.08 * s])
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], 0.12 * s, fine: true)
            head.ball(0xFF9A3C, [0, -0.02 * s, 0.12 * s], [0.06 * s, 0.025 * s, 0.07 * s])
            head.face(eyes: 0.06 * s, at: 0.03 * s, forward: 0.09 * s, size: 0.02 * s)
            head.dress(a.head)
            a.head.position = [0, 0.32 * s, 0.17 * s]
        }
    }

    private func koi(_ k: Int) -> (Animal) -> Void {
        currentKind = .koi
        return { a in
            let patterns: [(UInt32, UInt32)] = [(0xFF7A3C, 0xFFFFFF), (0xFFFFFF, 0xE8452E), (0xF7C948, 0xFFFFFF), (0xFF7A3C, 0x2B2523)]
            let (main, spot) = patterns[k % patterns.count]
            var body = Coat()
            body.ball(main, [0, 0, 0], [0.065, 0.04, 0.2], fine: true)
            body.ball(spot, [0.01, 0.02, 0.05], [0.045, 0.025, 0.06])
            body.ball(spot, [-0.01, 0.022, -0.07], [0.035, 0.02, 0.045])
            body.ball(Coat.eye, [0.04, 0.012, 0.14], 0.01)
            body.ball(Coat.eye, [-0.04, 0.012, 0.14], 0.01)
            body.dress(a.body)
            let tail = Entity()
            var t = Coat()
            t.ball(main, [0, 0, -0.07], [0.06, 0.012, 0.08])
            t.dress(tail)
            tail.position = [0, 0, -0.17]
            a.body.addChild(tail)
            a.tail = tail
            a.body.position = [0, 0.02, 0]
        }
    }

    private func monkey() -> (Animal) -> Void {
        currentKind = .monkey
        return { a in
            let fur: UInt32 = 0xB08F72, face: UInt32 = 0xF2A8A0
            var body = Coat()
            body.ball(fur, [0, 0.22, 0], [0.16, 0.17, 0.14], fine: true)
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], [0.13, 0.12, 0.12], fine: true)
            head.ball(face, [0, -0.01, 0.07], [0.085, 0.08, 0.06], fine: true)
            // Eyes closed in bliss: two little curves.
            for side: Float in [-1, 1] {
                head.ball(Coat.eye, [side * 0.035, 0.01, 0.125], [0.02, 0.006, 0.005])
                head.ball(fur, [side * 0.13, 0.0, 0.0], [0.035, 0.045, 0.02])
                head.ball(0xFF8FA0, [side * 0.055, -0.035, 0.11], [0.02, 0.012, 0.008])
            }
            head.ball(0xC87878, [0, -0.04, 0.13], [0.015, 0.006, 0.005])
            // A folded towel on top.
            head.batches[0xFFFFFF, default: MeshBatch()].box([0, 0.13, 0], [0.16, 0.035, 0.1], yaw: 0.2)
            head.dress(a.head)
            a.head.position = [0, 0.44, 0.02]
            let arm = Entity()
            var hand = Coat()
            hand.stick(fur, [0, 0, 0], [0, 0.16, 0.05], 0.035)
            hand.ball(face, [0, 0.18, 0.06], 0.035)
            hand.dress(arm)
            arm.position = [0.13, 0.3, 0.02]
            arm.orientation = spin(1.9, [0, 0, 1])
            a.body.addChild(arm)
            a.limbs.append(arm)
        }
    }

    private func owl() -> (Animal) -> Void {
        currentKind = .owl
        return { a in
            let fur: UInt32 = 0x9A7556
            var body = Coat()
            body.ball(fur, [0, 0.12, 0], [0.1, 0.13, 0.09], fine: true)
            body.ball(0xF2E2C8, [0, 0.1, 0.05], [0.07, 0.09, 0.05])
            for side: Float in [-1, 1] { body.ball(0x7A5A40, [side * 0.09, 0.12, -0.01], [0.03, 0.09, 0.06]) }
            body.dress(a.body)
            var head = Coat()
            head.ball(fur, [0, 0, 0], [0.1, 0.085, 0.085], fine: true)
            for side: Float in [-1, 1] {
                head.ball(0xF2E2C8, [side * 0.042, 0, 0.065], [0.04, 0.04, 0.02])
                head.ball(0xFFC23D, [side * 0.042, 0, 0.08], [0.026, 0.026, 0.01])
                head.ball(Coat.eye, [side * 0.042, 0, 0.086], [0.015, 0.015, 0.008])
                head.ball(Coat.shine, [side * 0.036, 0.008, 0.092], 0.005)
                head.cone(fur, [side * 0.06, 0.06, 0], height: 0.05, radius: 0.02, lean: spin(side * -0.4, [0, 0, 1]))
            }
            head.cone(0xE0A040, [0, -0.025, 0.08], height: 0.025, radius: 0.012, lean: spin(.pi, [1, 0, 0]))
            head.dress(a.head, glow: [0xFFC23D])
            a.head.position = [0, 0.29, 0.0]
        }
    }

    // MARK: Who is near

    /// The friend you could say hello to from `p`, if any is close enough.
    func nearest(to p: SIMD3<Float>) -> (index: Int, friend: ParkFriend)? {
        var best: (Int, Float)?
        for (i, a) in animals.enumerated() where a.visible && a.appear > 0.9 {
            let d = simd_distance(SIMD2(p.x, p.z), a.position)
            if d < a.reach, d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d) }
        }
        guard let best else { return nil }
        return (best.0, animals[best.0].kind)
    }

    /// Says hello: the animal turns to you and answers in its own way.
    /// Hands back where its head is, for hearts to float up from.
    func greet(_ index: Int, from p: SIMD3<Float>) -> SIMD3<Float> {
        guard animals.indices.contains(index) else { return p }
        let animal = animals[index]
        // The whole family answers: every swan, duck or koi together.
        for other in animals where other.kind == animal.kind && simd_distance(other.position, animal.position) < 4 {
            other.react = 0
            other.sleeping = 0
            other.rest = 2
            if case .roam = other.way {
                other.heading = atan2(p.x - other.position.x, p.z - other.position.y)
            }
        }
        return animal.headWorld + [0, 0.15, 0]
    }

    // MARK: Every frame

    func update(deltaTime dt: Float, viewer: SIMD3<Float>, viewerSpeed: Float, night: Float,
                constrain: (SIMD3<Float>, Float) -> SIMD3<Float>) {
        clock += dt
        let here = SIMD2(viewer.x, viewer.z)
        for animal in animals {
            // Day and night visitors.
            let wanted: Float = (animal.nightOnly && night < 0.55) || (animal.dayOnly && night > 0.6) ? 0 : 1
            animal.appear += (wanted - animal.appear) * min(1, dt * 2)
            let distance = simd_distance(here, animal.position)
            let show = animal.appear > 0.02 && distance < animal.cull
            if animal.root.isEnabled != show { animal.root.isEnabled = show }
            guard show else { continue }

            animal.phase += dt
            switch animal.way {
            case .roam: roam(animal, dt: dt, here: here, distance: distance, viewerSpeed: viewerSpeed, constrain: constrain)
            case .swim(let ring, let speed): swim(animal, ring: ring, speed: speed, dt: dt)
            case .pads: sitOnPads(animal, dt: dt)
            case .still: break
            }
            pose(animal, dt: dt, here: here, distance: distance)
        }
    }

    private func roam(_ a: Animal, dt: Float, here: SIMD2<Float>, distance: Float, viewerSpeed: Float,
                      constrain: (SIMD3<Float>, Float) -> SIMD3<Float>) {
        var pace: Float = 0
        if a.react >= 0 {
            // Busy saying hello.
        } else if a.shy && distance < 2.6 && viewerSpeed > 0.6 {
            // Startled: off they go, away from you.
            let away = simd_normalize(a.position - here + [0.01, 0])
            a.target = a.position + away * 3.5
            a.rest = 0
            a.sleeping = 0
            pace = a.speed * 2.6
        } else if a.curious && a.kind == .deer && distance < 7 && distance > 1.5 && viewerSpeed < 0.1 && a.rest <= 0 {
            // Deer come over to see if you have a treat.
            a.target = here + simd_normalize(a.position - here) * 1.3
            pace = a.speed * 0.8
        } else if a.sleeping > 0 {
            a.sleeping -= dt
        } else if a.rest > 0 {
            a.rest -= dt
        } else {
            pace = a.speed
        }

        let gap = a.target - a.position
        let d = simd_length(gap)
        if pace > 0 && d > 0.08 {
            let step = min(d, pace * dt)
            a.position += gap / d * step
            a.heading = turn(a.heading, toward: atan2(gap.x, gap.y), rate: 6, dt: dt)
            a.gait += step
            let kept = constrain([a.position.x, 0, a.position.y], 0.12 * a.size)
            a.position = [kept.x, kept.z]
        } else if d <= 0.08 || pace == 0 {
            if a.react < 0 && a.rest <= 0 && a.sleeping <= 0 {
                // Arrived: settle for a while, then pick somewhere new.
                if a.sleepy && rng.unit() < 0.4 {
                    a.sleeping = rng.range(10, 22)
                } else {
                    a.rest = rng.range(1.5, 6)
                }
                a.target = randomNear(a.home, a.range)
            }
        }
    }

    private func randomNear(_ home: SIMD2<Float>, _ range: Float) -> SIMD2<Float> {
        for _ in 0..<12 {
            let ang = rng.range(0, 2 * .pi), d = sqrt(rng.unit()) * range
            let p = home + SIMD2(cos(ang), sin(ang)) * d
            if !ParkHanami.isWater(p, margin: 0.6) { return p }
        }
        return home
    }

    private func swim(_ a: Animal, ring: Float, speed: Float, dt: Float) {
        if a.react < 0 || a.kind == .koi { a.swimAt += speed * dt }
        let lake = ParkHanami.lake
        let n = Float(lake.count)
        var t = a.swimAt.truncatingRemainder(dividingBy: 1)
        if t < 0 { t += 1 }
        func point(_ t: Float) -> SIMD2<Float> {
            let f = t * n
            let i = Int(f) % lake.count, j = (i + 1) % lake.count
            let edge = lake[i] + (lake[j] - lake[i]) * (f - Float(Int(f)))
            return ParkHanami.lakeCentre + (edge - ParkHanami.lakeCentre) * ring
        }
        let p = point(t)
        let ahead = point(t + (speed >= 0 ? 0.004 : -0.004))
        // Swans swim side by side; ducklings in a line behind their mother.
        var offset = SIMD2<Float>.zero
        if a.kind == .swan {
            let side = simd_normalize(SIMD2((ahead - p).y, -(ahead - p).x))
            offset = side * (a.swimAt.truncatingRemainder(dividingBy: 0.024) > 0.006 ? 0.35 : -0.35)
        }
        a.position = p + offset
        a.heading = turn(a.heading, toward: atan2(ahead.x - p.x, ahead.y - p.y), rate: 4, dt: dt)
        a.height = 0.02 + sin(clock * 1.6 + a.phase) * 0.012
    }

    private func sitOnPads(_ a: Animal, dt: Float) {
        guard !lilyPads.isEmpty else { return }
        if a.hop > 0 {
            // Mid-leap from one pad to the next.
            a.hop -= dt / 0.55
            let t = 1 - max(0, a.hop)
            let from = a.target
            let to = a.home
            a.position = from + (to - from) * t
            a.height = sin(t * .pi) * 0.35 + 0.06
            if a.hop <= 0 { a.position = to; a.height = 0.06; a.rest = rng.range(3, 9) }
            return
        }
        if a.home == ParkHanami.at(0, 0) {
            let pad = lilyPads[Int(rng.range(0, Float(lilyPads.count) - 0.01))]
            a.home = SIMD2(pad.x, pad.z)
            a.position = a.home
            a.height = 0.06
            a.rest = rng.range(1, 6)
        }
        a.rest -= dt
        if a.rest <= 0 && a.react < 0 {
            let nearby = lilyPads.filter { simd_distance(SIMD2($0.x, $0.z), a.home) < 3.5 && simd_distance(SIMD2($0.x, $0.z), a.home) > 0.3 }
            guard let next = nearby.isEmpty ? nil : nearby[Int(rng.range(0, Float(nearby.count) - 0.01))] else { a.rest = 4; return }
            a.target = a.home
            a.home = SIMD2(next.x, next.z)
            a.heading = atan2(a.home.x - a.target.x, a.home.y - a.target.y)
            a.hop = 1
        }
    }

    /// Bobs, hops, nods and wags, and plays each animal's hello.
    private func pose(_ a: Animal, dt: Float, here: SIMD2<Float>, distance: Float) {
        let moving: Bool = {
            if case .roam = a.way { return simd_distance(a.position, a.target) > 0.08 && a.rest <= 0 && a.sleeping <= 0 }
            return false
        }()
        var bodyOffset = SIMD3<Float>.zero
        var bodyTurn = spin(0, [0, 1, 0])
        var headTurn = spin(0, [0, 1, 0])
        var lift: Float = 0
        var spinAround: Float = 0
        let wake = a.sleeping > 0 ? 0 : 1

        if moving {
            if a.hopHeight > 0 {
                lift = abs(sin(a.gait * 9)) * a.hopHeight
                bodyTurn = spin(-cos(a.gait * 9) * 0.15, [1, 0, 0])
            } else {
                bodyOffset.y = abs(sin(a.gait * 11)) * 0.02
                bodyTurn = spin(sin(a.gait * 11) * 0.05, [0, 0, 1])
            }
        } else if a.sleeping > 0 {
            // Curled up asleep, breathing slowly.
            bodyOffset.y = -0.03
            let breathe = 1 + sin(clock * 1.6 + a.phase) * 0.03
            a.body.scale = [1.05, 0.85 * breathe, 0.95]
            headTurn = spin(0.5, [1, 0, 0]) * spin(0.6, [0, 1, 0])
        } else {
            // Idle: looking about, and at you if you are close.
            let look: Float
            if distance < 4 && a.react < 0 {
                var toYou = atan2(here.x - a.position.x, here.y - a.position.y) - a.heading
                while toYou > .pi { toYou -= 2 * .pi }
                while toYou < -.pi { toYou += 2 * .pi }
                look = max(-1.0, min(1.0, toYou))
            } else {
                look = sin(clock * 0.5 + a.phase) * 0.6 * (sin(clock * 0.23 + a.phase) > 0 ? 1 : 0.2)
            }
            headTurn = spin(look, [0, 1, 0]) * spin(sin(clock * 0.9 + a.phase) * 0.08, [0, 0, 1])
            if a.kind == .swan || a.kind == .duck { headTurn = spin(look * 0.4, [0, 1, 0]) }
            if a.kind == .deer && sin(clock * 0.3 + a.phase) > 0.7 { headTurn = spin(0.9, [1, 0, 0]) }   // grazing
            if a.kind == .monkey { bodyOffset.y = sin(clock * 0.8) * 0.01 }
        }
        if a.sleeping <= 0 { a.body.scale = .one }

        // Saying hello.
        if a.react >= 0 {
            a.react += dt
            let t = a.react
            switch a.kind {
            case .deer:
                // Two polite bows.
                let bow = max(0, sin(min(t, 2) * .pi))
                headTurn = spin(bow * 1.0, [1, 0, 0])
                bodyTurn = spin(bow * 0.15, [1, 0, 0])
            case .bunny, .sparrow, .squirrel:
                lift = abs(sin(t * 9)) * (a.kind == .bunny ? 0.22 : 0.08) * max(0, 1 - t / 1.8)
                for (k, ear) in a.extras.enumerated() { ear.orientation = spin((k == 0 ? 1 : -1) * (0.18 + sin(t * 20) * 0.2), [0, 0, 1]) }
            case .cat:
                spinAround = t < 1.2 ? t / 1.2 * 2 * .pi : 0
                lift = t < 1.2 ? sin(t / 1.2 * .pi) * 0.12 : 0
            case .tanuki:
                let drum = 1 + abs(sin(t * 14)) * 0.08 * max(0, 1 - t / 2)
                a.body.scale = [drum, 1 / drum, drum]
            case .fox, .spiritFox:
                spinAround = t < 1 ? t * 2 * .pi : 0
                lift = t < 1 ? sin(t * .pi) * 0.2 : 0
            case .frog:
                lift = t < 0.7 ? sin(t / 0.7 * .pi) * 0.4 : 0
            case .swan:
                // Turn to face each other and bow their necks into a heart.
                headTurn = spin(min(1, t) * 0.6, [1, 0, 0])
                for (k, wing) in a.limbs.enumerated() { wing.orientation = spin((k == 0 ? -1 : 1) * abs(sin(t * 6)) * 0.6 * max(0, 1 - t / 1.5), [0, 0, 1]) }
            case .turtle:
                a.head.position = a.headRest + [0, 0, sin(min(t, 1.5) * 2 * .pi) * 0.03]
            case .duck:
                bodyTurn = spin(sin(t * 12) * 0.2 * max(0, 1 - t / 1.2), [1, 0, 0])
            case .koi:
                lift = t < 0.8 ? sin(t / 0.8 * .pi) * 0.25 : 0
                bodyTurn = spin(t < 0.8 ? -cos(t / 0.8 * .pi) * 0.6 : 0, [1, 0, 0])
            case .monkey:
                for arm in a.limbs { arm.orientation = spin(1.9 + sin(t * 10) * 0.4 * max(0, 1 - t / 2), [0, 0, 1]) * spin(0.5, [1, 0, 0]) }
            case .owl:
                headTurn = spin(sin(t * 4) * 0.7 * max(0, 1 - t / 2), [0, 0, 1])
            }
            if t > 2.2 {
                a.react = -1
                a.head.position = a.headRest
                for arm in a.limbs where a.kind == .monkey { arm.orientation = spin(1.9, [0, 0, 1]) }
            }
        } else if a.kind == .swan {
            for wing in a.limbs { wing.orientation = spin(0, [0, 0, 1]) }
        }

        // Tails wag, ears twitch.
        if let tail = a.tail {
            let wag: Float = a.kind == .koi ? 0.5 : (a.react >= 0 ? 0.7 : 0.25) * Float(wake)
            let speedUp: Float = a.kind == .koi ? 6 : (a.react >= 0 ? 14 : 3)
            let base: simd_quatf = a.kind == .fox || a.kind == .spiritFox ? spin(-0.4, [1, 0, 0]) : spin(0, [0, 1, 0])
            tail.orientation = base * spin(sin(clock * speedUp + a.phase) * wag, [0, 1, 0])
        }
        if a.kind == .bunny && a.react < 0 {
            for (k, ear) in a.extras.enumerated() {
                let twitch: Float = sin(clock * 0.7 + a.phase + Float(k)) > 0.95 ? 0.3 : 0
                ear.orientation = spin((k == 0 ? 1 : -1) * (0.18 + twitch), [0, 0, 1])
            }
        }
        if a.kind == .spiritFox {
            for (k, flame) in a.extras.enumerated() {
                let ang = clock * 1.2 + Float(k) / 3 * 2 * .pi
                flame.position = [cos(ang) * 0.45, 0.45 + sin(clock * 2 + Float(k)) * 0.08, sin(ang) * 0.45]
            }
            lift += 0.06 + sin(clock * 1.5) * 0.03
        }

        a.root.position = [a.position.x, a.height + lift, a.position.y]
        a.root.orientation = spin(a.heading + spinAround, [0, 1, 0])
        a.root.scale = .init(repeating: max(0.001, a.appear))
        a.body.position = a.bodyRest + bodyOffset
        a.body.orientation = bodyTurn
        a.head.orientation = headTurn
    }

    private func place(_ a: Animal) {
        a.root.position = [a.position.x, a.height, a.position.y]
        a.root.orientation = spin(a.heading, [0, 1, 0])
    }

    private func turn(_ from: Float, toward angle: Float, rate: Float, dt: Float) -> Float {
        var change = angle - from
        while change > .pi { change -= 2 * .pi }
        while change < -.pi { change += 2 * .pi }
        return from + change * min(1, dt * rate)
    }
}
