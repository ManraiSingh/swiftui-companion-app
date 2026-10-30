//
//  ZiggyParkPeople.swift
//  Ziggy
//
//  The two of you, as little people Ziggy can walk with.
//
//  Cute rather than lifelike: a big round head, a small soft body, short
//  legs — the proportions of a figure you would want to keep on a shelf —
//  but built the careful way. Every part is one smooth sculpted surface, not
//  a stack of boxes: a body that rounds in at the waist, chubby limbs with
//  rounded knees and elbows, mitten hands with a thumb, and a face with full
//  cheeks, a button nose, big shining eyes and a small smile.
//
//  The clothes are proper clothes. A knit jumper with ribbing, worn over a
//  collared shirt whose collar and hem peek out; chinos with turned-up hems;
//  shoes with soles and laces. A pink dress with a rounded white collar, a
//  bow, puff sleeves and a pleated skirt; knee socks and Mary Janes.
//
//  They walk heel to toe — knees folding to swing each foot through, arms
//  swinging against the legs — and when the two of you walk side by side,
//  you hold hands.
//

import RealityKit
import UIKit

// MARK: - Looks

/// Who someone is in the park. Each partner picks their own, and it
/// travels with their position so both phones agree.
enum ParkLook: Int, CaseIterable {
    /// Knit jumper over a collared shirt, chinos, shoes; short hair.
    case casual = 0
    /// Pink dress, knee socks, Mary Janes; long hair with a bow.
    case sundress = 1

    var next: ParkLook { self == .casual ? .sundress : .casual }
}

// MARK: - Emotes

/// Little things to do with yourself while you stand about. Each is made
/// only of joints turning — arms, elbows, waist, head — so nothing ever
/// stretches out of shape; they ease in and out of whatever you were doing.
/// How someone is feeling. Stays on their face until they change it, and
/// their partner sees it too.
enum ParkMood: String, CaseIterable {
    case normal, happy, love, sad, angry

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .happy: return "Happy"
        case .love: return "Love"
        case .sad: return "Sad"
        case .angry: return "Angry"
        }
    }

    /// Finishes "… is feeling".
    var word: String {
        switch self {
        case .normal: return "okay"
        case .happy: return "happy"
        case .love: return "the love"
        case .sad: return "sad"
        case .angry: return "angry"
        }
    }
}

enum ParkEmote: String, CaseIterable {
    case wave, love, yay, dance, bow
    /// Playing with Ziggy: a pat on the head, a treat held out, a ball thrown.
    case pat, offer, toss

    /// The ones in the emote menu; the rest belong to playing with Ziggy.
    static let menu: [ParkEmote] = [.wave, .love, .yay, .dance, .bow]

    var title: String {
        switch self {
        case .wave: return "Wave"
        case .love: return "Kiss"
        case .yay: return "Yay!"
        case .dance: return "Dance"
        case .bow: return "Bow"
        case .pat: return "Pet"
        case .offer: return "Treat"
        case .toss: return "Catch"
        }
    }

    var emoji: String {
        switch self {
        case .wave: return "👋"
        case .love: return "🫶"
        case .yay: return "🎉"
        case .dance: return "💃"
        case .bow: return "🙇"
        case .pat: return "🐶"
        case .offer: return "🦴"
        case .toss: return "🎾"
        }
    }

    var duration: Float {
        switch self {
        case .wave: return 2.2
        case .love: return 2.6
        case .yay: return 1.6
        case .dance: return 2.6
        case .bow: return 2.0
        case .pat: return 2.4
        case .offer: return 2.6
        case .toss: return 1.1
        }
    }
}

private struct Palette {
    let skin = UIColor(0xF7D6BF)
    let blush = UIColor(0xF6A5A8)
    let mouth = UIColor(0xC4525F)
    let eye = UIColor(0x2E1C14)
    let iris = UIColor(0x7A4B2E)
    let hair: UIColor
    let top: UIColor
    let trim: UIColor
    let bottom: UIColor
    let shoe: UIColor
    let sole: UIColor
    let accent: UIColor

    static func of(_ look: ParkLook) -> Palette {
        switch look {
        case .casual:
            return Palette(hair: UIColor(0x3B271C), top: UIColor(0xEFE2CC), trim: UIColor(0xFFFFFF),
                           bottom: UIColor(0x44557A), shoe: UIColor(0x8C5B3D), sole: UIColor(0xF1E6D6), accent: UIColor(0xE7788F))
        case .sundress:
            return Palette(hair: UIColor(0x4A2E22), top: UIColor(0xF8B9CB), trim: UIColor(0xFFFFFF),
                           bottom: UIColor(0xF8B9CB), shoe: UIColor(0xC8485E), sole: UIColor(0x8E2F42), accent: UIColor(0xE0566F))
        }
    }
}

// MARK: - The person

/// One person. Faces +Z, feet at y = 0, about 1.2 units tall.
@available(iOS 18.0, *)
final class ParkPerson3D {

    let root = Entity()

    /// Called after the outfit is rebuilt, so new parts can be lit.
    var onRebuild: ((Entity) -> Void)?

    private let body = Entity()
    private var hips = Entity()
    private var torso = Entity()
    private var head = Entity()
    private var thighs: [Entity] = []
    private var knees: [Entity] = []
    private var ankles: [Entity] = []
    private var shoulders: [Entity] = []
    private var elbows: [Entity] = []
    private var eyes: [Entity] = []
    private var skirt: Entity?
    private var longHair: Entity?
    /// Each mood's brows and mouth, with only the current one showing.
    private var moodFaces: [ParkMood: Entity] = [:]
    private var tear: Entity?
    private var mood: ParkMood = .normal

    private var clock: Float = .random(in: 0...10)
    private var phase: Float = 0
    private var walking: Float = 0
    private var reach: Float = 1
    private var nextBlink: Float = .random(in: 1...4)

    /// Which arm is holding hands (0 left, 1 right), and how far into it.
    private var holdingArm = 1
    private var holding: Float = 0
    private var holdTarget: Float = 0

    private(set) var look: ParkLook
    private var size: Float { look == .casual ? 1.0 : 0.95 }

    private var emote: ParkEmote?
    private var emoteTime: Float = 0
    var isEmoting: Bool { emote != nil }

    /// Plays an emote from the start.
    func play(_ next: ParkEmote) {
        emote = next
        emoteTime = 0
    }

    /// Cuts an emote short — you set off walking.
    func stopEmote() {
        guard let emote else { return }
        // Jump to the easing-out part rather than snapping back.
        emoteTime = max(emoteTime, emote.duration - 0.3)
    }

    /// Changes the expression. Stays until changed, outfit swaps included.
    func feel(_ next: ParkMood) {
        guard next != mood else { return }
        mood = next
        showMood()
    }

    private func showMood() {
        for (face, parts) in moodFaces { parts.isEnabled = face == mood }
        // Happy and loved-up faces have their own eyes.
        for eye in eyes { eye.isEnabled = mood != .happy && mood != .love }
    }

    init(look: ParkLook) {
        self.look = look
        root.addChild(body)
        build()
    }

    /// Swaps who this is in place, keeping position.
    func wear(_ next: ParkLook) {
        guard next != look else { return }
        look = next
        body.children.removeAll()
        thighs = []; knees = []; ankles = []; shoulders = []; elbows = []; eyes = []
        skirt = nil; longHair = nil; moodFaces = [:]; tear = nil
        build()
        onRebuild?(root)
    }

    /// Reach out and hold hands with someone on that side (`arm` 0 is the
    /// left, 1 the right), or let go.
    func holdHands(arm: Int?) {
        if let arm { holdingArm = arm }
        holdTarget = arm == nil ? 0 : 1
    }

    // MARK: Building

    private func build() {
        let p = Palette.of(look)
        let k = size
        buildLegs(p, k)
        buildTorso(p, k)
        buildArms(p, k)
        buildHead(p, k)
    }

    private func part(_ parent: Entity, _ material: some RealityKit.Material, at position: SIMD3<Float> = .zero,
                      turn: simd_quatf = spin(0, [0, 1, 0]), _ make: (inout MeshBatch) -> Void) {
        var batch = MeshBatch()
        make(&batch)
        if let piece = batch.entity(material) {
            piece.position = position
            piece.orientation = turn
            parent.addChild(piece)
        }
    }

    private typealias Ring = (centre: SIMD3<Float>, rx: Float, rz: Float)

    /// Rings as (height, half-width, half-depth, forward offset), scaled.
    private func rings(_ list: [(Float, Float, Float, Float)], k: Float) -> [Ring] {
        list.map { (SIMD3<Float>(0, $0.0 * k, $0.3 * k), $0.1 * k, $0.2 * k) }
    }

    private var skinPaint: PhysicallyBasedMaterial { ParkPaint.skin(Palette.of(look).skin) }

    private func buildLegs(_ p: Palette, _ k: Float) {
        let dress = look == .sundress
        let pants = ParkPaint.soft(p.bottom, sheen: 0.3)
        let skin = skinPaint

        hips = body.joint(at: [0, 0.4 * k, 0])
        part(hips, dress ? ParkPaint.soft(.white, sheen: 0.4) : pants) {
            // Kept well inside the jumper or bodice above it, so the hips
            // turning under the shoulders can never push it through.
            $0.loft(rings([(0.08, 0.11, 0.088, 0), (0.02, 0.128, 0.1, 0), (-0.04, 0.142, 0.11, -0.004),
                           (-0.08, 0.138, 0.106, -0.004), (-0.1, 0.108, 0.088, 0)], k: k), segments: 28)
        }

        if dress {
            // A pleated skirt that flares from the waist to the knee, with a
            // white lace hem. It sways from its own joint.
            let hang = hips.joint(at: .zero)
            part(hang, ParkPaint.soft(p.bottom, sheen: 0.5)) {
                $0.lathe([[-0.2 * k, 0.25 * k], [-0.18 * k, 0.258 * k], [-0.1 * k, 0.225 * k], [-0.02 * k, 0.185 * k],
                          [0.03 * k, 0.15 * k], [0.05 * k, 0.142 * k]], depth: 0.86, pleats: (14, 0.05), segments: 56)
            }
            part(hang, ParkPaint.soft(.white, sheen: 0.6)) {
                $0.lathe([[-0.215 * k, 0.246 * k], [-0.205 * k, 0.256 * k], [-0.19 * k, 0.26 * k], [-0.185 * k, 0.256 * k]],
                         depth: 0.86, pleats: (28, 0.06), segments: 56)
            }
            skirt = hang
        }

        for side: Float in [-1, 1] {
            let thigh = hips.joint(at: [0.072 * k * side, -0.02 * k, 0])
            part(thigh, dress ? skin : pants) {
                $0.loft(rings([(0.02, 0.066, 0.068, 0), (-0.08, 0.062, 0.064, 0), (-0.17, 0.054, 0.056, 0)], k: k), segments: 20)
            }
            thigh.attach(ParkMesh.sphere(0.054 * k), dress ? skin : pants, at: [0, -0.17 * k, 0])

            let knee = thigh.joint(at: [0, -0.17 * k, 0])
            if dress {
                // White knee socks with a frill at the top.
                part(knee, skin) {
                    $0.loft(rings([(0.0, 0.052, 0.054, 0), (-0.04, 0.05, 0.053, -0.004)], k: k), segments: 20)
                }
                part(knee, ParkPaint.soft(.white, sheen: 0.6)) {
                    $0.loft(rings([(-0.03, 0.052, 0.055, -0.004), (-0.09, 0.05, 0.054, -0.006), (-0.16, 0.042, 0.044, 0)], k: k), segments: 20)
                }
                part(knee, ParkPaint.soft(.white, sheen: 0.6)) {
                    $0.lathe([[-0.04 * k, 0.054 * k], [-0.025 * k, 0.062 * k], [-0.018 * k, 0.06 * k]], pleats: (12, 0.12), segments: 24)
                }
            } else {
                part(knee, pants) {
                    $0.loft(rings([(0.0, 0.054, 0.056, 0), (-0.08, 0.052, 0.054, -0.004), (-0.15, 0.05, 0.051, 0)], k: k), segments: 20)
                }
                // Turned-up hems, the lighter inside showing.
                part(knee, ParkPaint.soft(p.bottom.withBrightness(1.25), sheen: 0.3)) {
                    $0.loft(rings([(-0.125, 0.056, 0.057, 0), (-0.15, 0.057, 0.058, 0)], k: k), segments: 20, capped: false)
                }
            }

            let ankle = knee.joint(at: [0, -0.16 * k, 0])
            buildShoe(on: ankle, p, k: k, dress: dress, side: side)

            thighs.append(thigh)
            knees.append(knee)
            ankles.append(ankle)
        }
    }

    private func buildShoe(on ankle: Entity, _ p: Palette, k: Float, dress: Bool, side: Float) {
        // A round-toed shoe, slightly too big, the way cute shoes are.
        part(ankle, ParkPaint.glossy(p.shoe, roughness: dress ? 0.25 : 0.45)) {
            $0.loft([([0, -0.012 * k, -0.045 * k], 0.046 * k, 0.04 * k), ([0, -0.016 * k, -0.01 * k], 0.054 * k, 0.046 * k),
                     ([0, -0.022 * k, 0.04 * k], 0.058 * k, 0.04 * k), ([0, -0.026 * k, 0.085 * k], 0.052 * k, 0.032 * k),
                     ([0, -0.028 * k, 0.11 * k], 0.036 * k, 0.024 * k)], segments: 22)
        }
        part(ankle, ParkPaint.flat(p.sole, roughness: 0.7)) {
            $0.loft([([0, -0.047 * k, -0.05 * k], 0.046 * k, 0.01 * k), ([0, -0.048 * k, 0.0], 0.057 * k, 0.011 * k),
                     ([0, -0.048 * k, 0.06 * k], 0.06 * k, 0.011 * k), ([0, -0.047 * k, 0.12 * k], 0.036 * k, 0.009 * k)], segments: 22)
        }
        if dress {
            // Mary Jane strap and a little gold button.
            part(ankle, ParkPaint.glossy(p.shoe.withBrightness(0.85), roughness: 0.3)) {
                $0.loft([([-0.05 * k, 0.012 * k, 0.03 * k], 0.006 * k, 0.004 * k), ([0, 0.022 * k, 0.034 * k], 0.006 * k, 0.004 * k),
                         ([0.05 * k, 0.012 * k, 0.03 * k], 0.006 * k, 0.004 * k)], segments: 8)
            }
            ankle.attach(ParkMesh.sphere(0.008 * k), ParkPaint.metal(UIColor(0xF2CC6B)), at: [0.048 * k * side, 0.012 * k, 0.032 * k])
        } else {
            // Laces.
            for row in 0..<3 {
                ankle.attach(ParkMesh.box([0.04 * k, 0.005 * k, 0.008 * k]), ParkPaint.soft(p.sole),
                             at: [0, (0.022 - Float(row) * 0.005) * k, (0.0 + Float(row) * 0.022) * k], turn: spin(0.4, [1, 0, 0]))
            }
        }
    }

    private func buildTorso(_ p: Palette, _ k: Float) {
        torso = body.joint(at: [0, 0.44 * k, 0])
        let dress = look == .sundress

        if dress {
            // Fitted bodice, rounded white collar, a bow at the throat and a
            // row of tiny buttons.
            part(torso, ParkPaint.soft(p.top, sheen: 0.5)) {
                $0.loft(rings([(-0.03, 0.15, 0.12, 0), (0.05, 0.142, 0.112, 0), (0.13, 0.148, 0.116, 0.006),
                               (0.2, 0.142, 0.11, 0.004), (0.245, 0.11, 0.088, 0), (0.27, 0.07, 0.062, 0)], k: k),
                        segments: 30, capStart: false, capEnd: true)
            }
            part(torso, ParkPaint.soft(p.accent, sheen: 0.5)) {
                $0.loft(rings([(-0.045, 0.158, 0.128, 0), (-0.0, 0.155, 0.125, 0), (0.02, 0.15, 0.12, 0)], k: k), segments: 30, capped: false)
            }
            for side: Float in [-1, 1] {
                torso.attach(ParkMesh.sphere(0.06 * k), ParkPaint.soft(p.trim, sheen: 0.6), at: [0.045 * k * side, 0.252 * k, 0.05 * k],
                             scale: [1.1, 0.28, 0.95], turn: spin(-0.35 * side, [0, 0, 1]) * spin(0.25, [1, 0, 0]))
                torso.attach(ParkMesh.sphere(0.022 * k), ParkPaint.soft(p.accent, sheen: 0.5), at: [0.026 * k * side, 0.232 * k, 0.1 * k],
                             scale: [1.4, 0.85, 0.5], turn: spin(0.3 * side, [0, 0, 1]))
            }
            torso.attach(ParkMesh.sphere(0.012 * k), ParkPaint.soft(p.accent, sheen: 0.5), at: [0, 0.232 * k, 0.104 * k])
            for row in 0..<3 {
                torso.attach(ParkMesh.sphere(0.007 * k), ParkPaint.glossy(.white), at: [0, (0.17 - Float(row) * 0.05) * k, 0.114 * k])
            }
        } else {
            // A chunky knit jumper — ribbed all over — with the collar and
            // hem of a white shirt peeking out.
            part(torso, ParkPaint.soft(p.top, sheen: 0.6)) {
                $0.loft(rings([(-0.06, 0.165, 0.132, 0), (0.0, 0.16, 0.127, 0), (0.08, 0.158, 0.125, 0.004),
                               (0.15, 0.16, 0.124, 0.006), (0.2, 0.15, 0.116, 0.004), (0.245, 0.115, 0.092, 0), (0.27, 0.075, 0.066, 0)], k: k),
                        segments: 36, capStart: false, capEnd: true, ripple: (36, 0.012))
            }
            part(torso, ParkPaint.soft(p.top.withBrightness(0.94), sheen: 0.6)) {
                $0.loft(rings([(-0.075, 0.168, 0.135, 0), (-0.035, 0.167, 0.134, 0)], k: k), segments: 36, capped: false, ripple: (48, 0.02))
            }
            part(torso, ParkPaint.soft(p.trim, sheen: 0.3)) {
                $0.loft(rings([(-0.1, 0.16, 0.128, 0), (-0.07, 0.161, 0.129, 0)], k: k), segments: 36, capped: false)
            }
            for side: Float in [-1, 1] {
                torso.attach(ParkMesh.sphere(0.045 * k), ParkPaint.soft(p.trim, sheen: 0.3), at: [0.032 * k * side, 0.26 * k, 0.05 * k],
                             scale: [0.85, 0.22, 1.0], turn: spin(-0.6 * side, [0, 0, 1]) * spin(0.45, [1, 0, 0]))
            }
            // A little heart knitted into the front.
            for (dx, dy) in [(-0.009, 0.0), (0.009, 0.0)] as [(Float, Float)] {
                torso.attach(ParkMesh.sphere(0.011 * k), ParkPaint.soft(p.accent, sheen: 0.4), at: [(-0.06 + dx) * k, (0.16 + dy) * k, 0.125 * k],
                             scale: [1, 1, 0.4])
            }
            torso.attach(.generateCone(height: 0.018 * k, radius: 0.016 * k), ParkPaint.soft(p.accent, sheen: 0.4), at: [-0.06 * k, 0.149 * k, 0.125 * k],
                         scale: [1, 1, 0.4], turn: spin(.pi, [0, 0, 1]))
        }

        part(torso, skinPaint) {
            $0.loft(rings([(0.23, 0.046, 0.044, 0), (0.3, 0.043, 0.042, 0)], k: k), segments: 18)
        }
    }

    private func buildArms(_ p: Palette, _ k: Float) {
        let dress = look == .sundress
        let skin = skinPaint
        let sleeve = ParkPaint.soft(p.top, sheen: dress ? 0.5 : 0.6)

        for side: Float in [-1, 1] {
            let shoulder = torso.joint(at: [0.145 * k * side, 0.205 * k, 0])
            if dress {
                // Puff sleeve.
                part(shoulder, sleeve) {
                    $0.lathe([[-0.07 * k, 0.04 * k], [-0.062 * k, 0.056 * k], [-0.03 * k, 0.066 * k], [0.0, 0.06 * k], [0.03 * k, 0.03 * k]],
                             pleats: (8, 0.08), segments: 28)
                }
                part(shoulder, ParkPaint.soft(p.trim, sheen: 0.6)) {
                    $0.loft(rings([(-0.068, 0.043, 0.043, 0), (-0.078, 0.042, 0.042, 0)], k: k), segments: 20, capped: false)
                }
            } else {
                shoulder.attach(ParkMesh.sphere(0.054 * k), sleeve, at: [0, -0.005 * k, 0], scale: [1, 0.85, 1])
            }

            part(shoulder, dress ? skin : sleeve) {
                $0.loft(rings([(0.0, 0.044, 0.045, 0), (-0.08, 0.042, 0.043, 0), (-0.15, 0.039, 0.04, 0)], k: k), segments: 18,
                        ripple: dress ? (0, 0) : (16, 0.03))
            }
            let elbow = shoulder.joint(at: [0, -0.15 * k, 0])
            elbow.attach(ParkMesh.sphere(0.039 * k), dress ? skin : sleeve)
            part(elbow, dress ? skin : sleeve) {
                $0.loft(rings([(0.0, 0.039, 0.04, 0), (-0.07, 0.037, 0.037, 0), (-0.12, 0.034, 0.034, 0)], k: k), segments: 18,
                        ripple: dress ? (0, 0) : (16, 0.03))
            }
            if !dress {
                part(elbow, ParkPaint.soft(p.top.withBrightness(0.94), sheen: 0.6)) {
                    $0.loft(rings([(-0.1, 0.037, 0.037, 0), (-0.135, 0.036, 0.036, 0)], k: k), segments: 18, capped: false, ripple: (20, 0.06))
                }
            }

            // A mitten-shaped hand with a thumb.
            let wrist = elbow.joint(at: [0, -0.14 * k, 0])
            wrist.attach(ParkMesh.sphere(0.04 * k), skin, at: [0, -0.025 * k, 0], scale: [0.95, 1.15, 0.78])
            wrist.attach(ParkMesh.sphere(0.017 * k), skin, at: [-0.02 * k * side, -0.012 * k, 0.026 * k], scale: [1, 1.3, 1])

            shoulders.append(shoulder)
            elbows.append(elbow)
        }
    }

    private func buildHead(_ p: Palette, _ k: Float) {
        let dress = look == .sundress
        let skin = skinPaint

        head = torso.joint(at: [0, 0.29 * k, 0])
        let face = head.joint(at: [0, 0.185 * k, 0])

        part(face, skin) { $0.sheet(Self.headRows(k: k), closed: true, centres: Self.headCentres(k: k)) }

        for side: Float in [-1, 1] {
            face.attach(ParkMesh.sphere(0.04 * k), skin, at: [0.185 * k * side, -0.005 * k, -0.01 * k], scale: [0.45, 1, 0.75])

            // Big, shining eyes.
            let eye = face.joint(at: [0.068 * k * side, -0.004 * k, 0.15 * k])
            eye.attach(ParkMesh.sphere(0.036 * k), ParkPaint.glossy(p.eye, roughness: 0.08), scale: [0.8, 1.0, 0.5])
            eye.attach(ParkMesh.sphere(0.024 * k), ParkPaint.glossy(p.iris, roughness: 0.08), at: [0, -0.01 * k, 0.007 * k], scale: [0.8, 0.75, 0.5])
            eye.attach(ParkMesh.sphere(0.0115 * k), ParkPaint.glow(.white), at: [0.011 * k, 0.014 * k, 0.017 * k])
            eye.attach(ParkMesh.sphere(0.0055 * k), ParkPaint.glow(.white), at: [-0.012 * k, -0.014 * k, 0.018 * k])
            if dress {
                // Lashes: a soft line along the top and a flick at the corner.
                eye.attach(ParkMesh.sphere(0.036 * k), ParkPaint.flat(p.eye), at: [0, 0.032 * k, 0.003 * k], scale: [0.88, 0.2, 0.5])
                eye.attach(ParkMesh.box([0.018 * k, 0.005 * k, 0.005 * k]), ParkPaint.flat(p.eye),
                           at: [0.03 * k * side, 0.03 * k, 0.004 * k], turn: spin(0.6 * side, [0, 0, 1]))
            }
            eyes.append(eye)

            face.attach(ParkMesh.sphere(0.03 * k), ParkPaint.soft(p.blush, sheen: 0), at: [0.112 * k * side, -0.048 * k, 0.126 * k],
                        scale: [1.2, 0.6, 0.35], turn: spin(0.6 * side, [0, 1, 0]))
        }

        buildMoods(on: face, p, k)
        buildHair(on: face, p, k)
    }

    /// Everything on the face that changes with the mood, one group for each.
    private func buildMoods(on face: Entity, _ p: Palette, _ k: Float) {
        let lips = ParkPaint.soft(p.mouth, sheen: 0)
        let ink = ParkPaint.flat(p.eye)
        let browPaint = ParkPaint.soft(p.hair, sheen: 0.2)

        func brows(_ on: Entity, tilt: Float, height: Float = 0.058, thick: Float = 0.22) {
            for side: Float in [-1, 1] {
                on.attach(ParkMesh.sphere(0.02 * k), browPaint, at: [0.068 * k * side, height * k, 0.152 * k],
                          scale: [1.2, thick, 0.4], turn: spin(tilt * side, [0, 0, 1]))
            }
        }

        /// A mouth drawn as a line of beads; `curve` above zero smiles, below frowns.
        func mouth(_ on: Entity, curve: Float, y: Float = -0.072, half: Int = 3) {
            let width = Float(half + 1) * 0.0075
            for step in -half...half {
                let x = Float(step) * 0.0075
                let dip = (1 - (x / width) * (x / width)) * curve
                on.attach(ParkMesh.sphere(0.0045 * k), lips, at: [x * k, (y - dip) * k, (0.158 - abs(x) * 0.3) * k])
            }
        }

        // As they have always looked: a small smile, turned up at the corners.
        let normal = face.joint(at: .zero)
        brows(normal, tilt: -0.12)
        mouth(normal, curve: 0.008)
        moodFaces[.normal] = normal

        // Eyes squeezed shut into two arches, and a big open smile.
        let happy = face.joint(at: .zero)
        brows(happy, tilt: -0.12, height: 0.07)
        for side: Float in [-1, 1] {
            for step in -4...4 {
                let u = Float(step) / 4
                happy.attach(ParkMesh.sphere(0.0062 * k), ink,
                             at: [(0.068 * side + u * 0.03) * k, (0.002 + (1 - u * u) * 0.024) * k, 0.156 * k])
            }
        }
        happy.attach(ParkMesh.sphere(0.03 * k), ParkPaint.soft(UIColor(0x8E2F42), sheen: 0), at: [0, -0.08 * k, 0.15 * k], scale: [0.9, 0.62, 0.25])
        happy.attach(ParkMesh.sphere(0.017 * k), ParkPaint.soft(UIColor(0xF58B9A), sheen: 0), at: [0, -0.09 * k, 0.155 * k], scale: [0.9, 0.5, 0.2])
        moodFaces[.happy] = happy

        // Heart eyes, a wider smile, rosier cheeks.
        let love = face.joint(at: .zero)
        brows(love, tilt: -0.12, height: 0.068)
        let heartPaint = ParkPaint.glossy(UIColor(0xFF4F7E), roughness: 0.2)
        for side: Float in [-1, 1] {
            let middle: SIMD3<Float> = [0.068 * side * k, -0.004 * k, 0.156 * k]
            for lobe: Float in [-1, 1] {
                love.attach(ParkMesh.sphere(0.021 * k), heartPaint, at: middle + [lobe * 0.019 * k, 0.012 * k, 0], scale: [1, 1, 0.4])
            }
            love.attach(ParkMesh.box([0.037 * k, 0.037 * k, 0.01 * k]), heartPaint, at: middle + [0, -0.006 * k, 0], turn: spin(.pi / 4, [0, 0, 1]))
            love.attach(ParkMesh.sphere(0.03 * k), ParkPaint.soft(UIColor(0xF2708A), sheen: 0), at: [0.112 * k * side, -0.048 * k, 0.129 * k],
                        scale: [1.25, 0.65, 0.35], turn: spin(0.6 * side, [0, 1, 0]))
        }
        mouth(love, curve: 0.012, half: 4)
        moodFaces[.love] = love

        // Brows rising in the middle, a frown, and a tear on its way down.
        let sad = face.joint(at: .zero)
        brows(sad, tilt: -0.45, height: 0.064)
        mouth(sad, curve: -0.01, y: -0.086)
        let drop = sad.joint(at: [0.082 * k, -0.04 * k, 0.158 * k])
        drop.attach(ParkMesh.sphere(0.014 * k), ParkPaint.glossy(UIColor(0x9FDBFF), roughness: 0.05), scale: [0.75, 1.1, 0.5])
        tear = drop
        moodFaces[.sad] = sad

        // Thick brows pulled down in the middle, and a tight frown.
        let angry = face.joint(at: .zero)
        brows(angry, tilt: 0.5, height: 0.046, thick: 0.34)
        mouth(angry, curve: -0.012, y: -0.086, half: 2)
        moodFaces[.angry] = angry

        showMood()
    }

    private func buildHair(on face: Entity, _ p: Palette, _ k: Float) {
        let dress = look == .sundress
        let hair = ParkPaint.soft(p.hair, sheen: 0.6)

        part(face, hair) { $0.sheet(Self.hairRows(k: k, long: dress), closed: true, centres: Self.hairCentres(k: k)) }

        // A fringe of separate locks, each curving down over the forehead.
        let locks: [(x: Float, length: Float, sweep: Float)] = dress
            ? [(-0.11, 0.07, -0.02), (-0.065, 0.085, -0.01), (-0.02, 0.09, 0.0), (0.025, 0.09, 0.01), (0.07, 0.085, 0.015), (0.11, 0.07, 0.02)]
            : [(-0.1, 0.06, 0.03), (-0.055, 0.075, 0.035), (-0.01, 0.08, 0.04), (0.035, 0.075, 0.045), (0.08, 0.06, 0.04)]
        for lock in locks {
            let x = lock.x * k
            let top = SIMD3<Float>(x, 0.15 * k, 0.12 * k)
            part(face, hair) {
                $0.loft([(top, 0.026 * k, 0.014 * k),
                         (top + SIMD3<Float>(lock.sweep * 0.5, -lock.length * 0.5, 0.035) * k, 0.024 * k, 0.012 * k),
                         (top + SIMD3<Float>(lock.sweep, -lock.length, 0.045) * k, 0.012 * k, 0.007 * k)], segments: 10)
            }
        }

        if dress {
            // Long hair down the back, in loose waves, swaying from its own
            // joint, and a big bow at the back of the head.
            let back = face.joint(at: [0, -0.02 * k, -0.1 * k])
            part(back, hair) {
                $0.loft([([0, 0.08 * k, 0.0], 0.15 * k, 0.07 * k), ([0, -0.05 * k, -0.02 * k], 0.17 * k, 0.07 * k),
                         ([0, -0.2 * k, -0.035 * k], 0.16 * k, 0.055 * k), ([0, -0.32 * k, -0.03 * k], 0.13 * k, 0.04 * k)],
                        segments: 32, ripple: (12, 0.07))
            }
            longHair = back
            for side: Float in [-1, 1] {
                part(face, hair) {
                    $0.loft([([0.15 * k * side, 0.0, 0.06 * k], 0.035 * k, 0.03 * k), ([0.165 * k * side, -0.12 * k, 0.07 * k], 0.035 * k, 0.026 * k),
                             ([0.16 * k * side, -0.24 * k, 0.08 * k], 0.022 * k, 0.017 * k)], segments: 14, ripple: (5, 0.12))
                }
            }
            let bow = ParkPaint.soft(p.accent, sheen: 0.6)
            for side: Float in [-1, 1] {
                face.attach(ParkMesh.sphere(0.045 * k), bow, at: [0.045 * k * side, 0.13 * k, -0.15 * k],
                            scale: [1.3, 0.8, 0.5], turn: spin(0.25 * side, [0, 0, 1]))
            }
            face.attach(ParkMesh.sphere(0.022 * k), bow, at: [0, 0.13 * k, -0.165 * k])
        } else {
            // Tousled tufts on the crown.
            for (x, z, tilt) in [(-0.06, 0.02, -0.5), (0.03, 0.05, 0.3), (0.08, -0.04, 0.6), (-0.02, -0.07, 0.0)] as [(Float, Float, Float)] {
                face.attach(ParkMesh.sphere(0.045 * k), hair, at: [x * k, 0.195 * k, z * k], scale: [0.9, 0.5, 0.75],
                            turn: spin(tilt, [0, 0, 1]))
            }
        }
    }

    // MARK: Head shape

    private static func gauss(_ a: Float) -> Float { exp(-0.5 * a * a) }

    /// A point on a round, cute head: wider than it is tall, full in the
    /// cheeks, a small chin, a button nose.
    private static func skull(_ v: Float, _ u: Float, face: Bool) -> SIMD3<Float> {
        let unit = SIMD3<Float>(sin(v) * cos(u), cos(v), sin(v) * sin(u))
        var x = unit.x * 0.19, y = unit.y * 0.18, z = unit.z * 0.17
        let front = max(0, unit.z)
        if unit.y < 0 {
            let t = -unit.y
            x *= 1 - 0.16 * pow(t, 2)
            z *= 1 - 0.08 * t * t * (1 - front)
        }
        guard face else { return [x, y, z] }
        x *= 1 + 0.05 * gauss((y + 0.05) / 0.05) * abs(unit.x)
        z += 0.01 * gauss(x / 0.014) * gauss((y + 0.034) / 0.013) * pow(front, 4)
        z -= 0.004 * pow(front, 8)
        return [x, y, z]
    }

    private static let rowCount = 30
    private static let columns = 44

    private static func headRows(k: Float) -> [[SIMD3<Float>]] {
        (0...rowCount).map { i in
            let v = Float(i) / Float(rowCount) * .pi
            return (0..<columns).map { j in skull(v, Float(j) / Float(columns) * 2 * .pi, face: true) * k }
        }
    }

    private static func headCentres(k: Float) -> [SIMD3<Float>] {
        (0...rowCount).map { i in [0, cos(Float(i) / Float(rowCount) * .pi) * 0.1 * k, 0] }
    }

    /// How far down the head the hair comes, by direction.
    private static func hairline(_ u: Float, long: Bool) -> Float {
        let ahead = sin(u)
        if ahead > 0 { return long ? (1.95 - 1.15 * ahead) : (1.55 - 0.75 * ahead) }
        return long ? (1.95 + 0.35 * -ahead) : (1.55 + 0.5 * -ahead)
    }

    private static let hairRowCount = 16

    private static func hairRows(k: Float, long: Bool) -> [[SIMD3<Float>]] {
        (0...hairRowCount).map { i in
            (0..<columns).map { j in
                let u = Float(j) / Float(columns) * 2 * .pi
                let v = hairline(u, long: long) * Float(i) / Float(hairRowCount)
                var p = skull(v, u, face: false)
                let n = simd_normalize(p)
                var lift: Float = 0.016
                lift += 0.012 * gauss((v - 0.4) / 0.35)
                lift *= 1 + 0.25 * sin(Float(j) * 1.9 + Float(i) * 0.5) * sin(v * 2.5)
                p += n * lift
                return p * k
            }
        }
    }

    private static func hairCentres(k: Float) -> [SIMD3<Float>] {
        (0...hairRowCount).map { i in [0, cos(1.5 * Float(i) / Float(hairRowCount)) * 0.1 * k, 0] }
    }

    // MARK: Moving

    private static func wrap(_ a: Float) -> Float {
        var a = a
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }

    private static func bump(_ a: Float, _ width: Float) -> Float {
        let d = wrap(a) / width
        return exp(-0.5 * d * d)
    }

    /// Call once a frame with how fast the root is moving.
    func update(deltaTime dt: Float, speed: Float) {
        let k = size
        clock += dt

        // Strides lengthen with speed, so steps a second barely change.
        walking += ((speed > 0.05 ? 1 : 0) - walking) * min(1, dt * 6)
        reach += (min(1.15, max(0.45, speed / 1.0)) - reach) * min(1, dt * 4)
        // The same stride for both, whatever their size: a shorter stride
        // means more steps for the same ground, and she looked to be
        // hurrying along beside him.
        let strideLength = 0.82 * reach
        phase += dt * speed / strideLength * 2 * .pi
        let w = walking, r = reach
        holding += (holdTarget - holding) * min(1, dt * 4)

        // Pelvis rises over each foot, turns with each step, and at rest
        // shifts weight from foot to foot.
        let rise = (0.012 * cos(2 * phase) - 0.008) * w * r
        let sway = 0.01 * cos(phase) * w + 0.005 * sin(clock * 0.45) * (1 - w)
        hips.position = [sway, 0.4 * k + rise, 0]
        hips.orientation = spin(0.05 * sin(phase) * w * r, [0, 1, 0]) * spin(0.03 * sin(2 * phase) * w, [0, 0, 1])

        torso.position = [sway * 0.6, 0.44 * k + rise, 0]
        torso.orientation = spin(-0.03 * sin(phase) * w * r, [0, 1, 0]) * spin(0.02 * w, [1, 0, 0])
        torso.scale = [1, 1 + 0.01 * sin(clock * 1.9), 1]

        for side in 0..<2 {
            let p = phase + (side == 0 ? 0 : .pi)
            let hip = -(0.5 * sin(p) + 0.04) * w * r
            let knee = (1.0 * Self.bump(p + 0.2, 0.7) + 0.2 * Self.bump(p - (.pi / 2 + 0.6), 0.45)) * w * r + 0.03
            let stance = min(1, max(0, -cos(p) * 3))
            let flat = -(hip + knee)
            let swing = -0.1 * Self.bump(p - .pi / 2, 0.45) * w + 0.3 * Self.bump(p + .pi / 2 + 0.3, 0.4) * w * r
            thighs[side].orientation = spin(hip, [1, 0, 0])
            knees[side].orientation = spin(knee, [1, 0, 0])
            ankles[side].orientation = spin(stance * flat + (1 - stance) * swing, [1, 0, 0])
        }

        for side in 0..<2 {
            let outward: Float = side == 0 ? -1 : 1
            let p = phase + (side == 0 ? 0 : .pi)
            let swing = 0.42 * sin(p) * w * r + 0.03 * sin(clock * 1.3) * (1 - w)
            let free = spin(outward * 0.1, [0, 0, 1]) * spin(swing, [1, 0, 0])
            let elbowFree = -(0.18 + 0.25 * max(0, -sin(p)) * w * r)
            if side == holdingArm && holding > 0.01 {
                // Reaching across to the one beside you: arm out and a little
                // forward, elbow nearly straight, swinging gently together.
                let held = spin(outward * 0.42, [0, 0, 1]) * spin(-0.12 + 0.06 * sin(phase) * w, [1, 0, 0])
                shoulders[side].orientation = simd_slerp(free, held, holding)
                elbows[side].orientation = spin(elbowFree * (1 - holding) - 0.08 * holding, [1, 0, 0])
            } else {
                shoulders[side].orientation = free
                elbows[side].orientation = spin(elbowFree, [1, 0, 0])
            }
        }

        // Head steady; looks about when idle; turns a little towards the one
        // they are holding hands with.
        let towards: Float = holding * (holdingArm == 1 ? -0.35 : 0.35)
        head.orientation =
            spin(sin(clock * 0.37) * 0.25 * (1 - w) * (1 - holding) + 0.05 * sin(phase) * w + towards, [0, 1, 0])
            * spin(sin(clock * 0.53) * 0.05 * (1 - w) + sin(2 * phase) * 0.02 * w + (mood == .sad ? 0.16 : 0), [1, 0, 0])

        skirt?.orientation = spin(0.06 * sin(2 * phase) * w, [1, 0, 0]) * spin(-0.05 * sin(phase) * w, [0, 0, 1])
        longHair?.orientation = spin(0.1 * w + 0.04 * sin(2 * phase + 0.6) * w + 0.015 * sin(clock), [1, 0, 0])

        if clock > nextBlink + 0.13 { nextBlink = clock + .random(in: 2.5...5.5) }
        let blinking = clock > nextBlink
        for eye in eyes { eye.scale = [1, blinking ? 0.1 : 1, 1] }

        // The tear rolls down the cheek and starts again.
        if let tear {
            let fall = (clock * 0.45).truncatingRemainder(dividingBy: 1)
            tear.position.y = (-0.04 - fall * 0.075) * size
            tear.scale = .init(repeating: 1 - fall * fall)
        }

        applyEmote(dt)
    }

    /// Poses for the emote on top of the walk, blended in over a fifth of a
    /// second and out again at the end.
    private func applyEmote(_ dt: Float) {
        guard let current = emote, shoulders.count == 2, elbows.count == 2 else {
            body.position = .zero
            body.orientation = spin(0, [0, 1, 0])
            return
        }
        emoteTime += dt
        let t = emoteTime, d = current.duration
        guard t < d else {
            emote = nil
            body.position = .zero
            body.orientation = spin(0, [0, 1, 0])
            return
        }
        let f = min(1, t / 0.2) * min(1, (d - t) / 0.3)
        func pose(_ joint: Entity, _ target: simd_quatf) { joint.orientation = simd_slerp(joint.orientation, target, f) }
        var lift: Float = 0
        var turn: Float = 0

        switch current {
        case .wave:
            // The right hand up beside the face, palm out, waving side to
            // side from the elbow; the head tips towards it, friendly.
            let k = size
            let sway = sin(t * 11) * 0.045
            reach(0, to: [-0.3 * k + sway * k, 0.42 * k, 0.1 * k], pole: [-1, -0.5, -0.3], f)
            pose(head, spin(0.12, [0, 0, 1]) * spin(-0.06, [1, 0, 0]))
        case .love:
            // Both hands together in front of the chest, elbows out — a
            // heart made with your hands — and a big heart pops up overhead.
            let k = size
            for side in 0..<2 {
                let o: Float = side == 0 ? -1 : 1
                reach(side, to: [o * 0.028 * k, 0.13 * k, 0.16 * k], pole: [o, -0.6, -0.15], f)
            }
            pose(head, spin(sin(t * 2.6) * 0.1, [0, 0, 1]) * spin(-0.05, [1, 0, 0]))
            lift = abs(sin(t * 3.2)) * 0.02
        case .yay:
            // Two happy hops, arms flung up.
            for side in 0..<2 {
                let o: Float = side == 0 ? -1 : 1
                pose(shoulders[side], spin(o * (2.45 + sin(t * 14) * 0.15), [0, 0, 1]))
                pose(elbows[side], spin(o * 0.25, [0, 0, 1]))
            }
            lift = abs(sin(t / d * 2 * .pi)) * 0.16
        case .dance:
            // A twirl, arms swaying up and down in turn.
            for side in 0..<2 {
                let o: Float = side == 0 ? -1 : 1
                pose(shoulders[side], spin(o * (1.5 + sin(t * 7 + Float(side) * .pi) * 0.8), [0, 0, 1]))
                pose(elbows[side], spin(o * 0.5, [0, 0, 1]))
            }
            let u = min(1, t / d)
            turn = (u * u * (3 - 2 * u)) * 2 * .pi
            lift = abs(sin(t * 7)) * 0.03
            pose(head, spin(sin(t * 7) * 0.12, [0, 0, 1]))
        case .bow:
            // A polite Japanese bow from the waist, hands together in front.
            pose(torso, spin(0.6, [1, 0, 0]))
            pose(head, spin(0.2, [1, 0, 0]))
            for side in 0..<2 {
                let o: Float = side == 0 ? -1 : 1
                pose(shoulders[side], spin(-0.35, [1, 0, 0]) * spin(-o * 0.18, [0, 0, 1]))
                pose(elbows[side], spin(-0.5, [1, 0, 0]))
            }
        case .pat:
            // Leaning down, a hand on Ziggy's head, patting gently.
            let k = size
            pose(torso, spin(0.35, [1, 0, 0]))
            pose(head, spin(0.3, [1, 0, 0]))
            reach(0, to: [-0.06 * k, (0.02 + abs(sin(t * 9)) * 0.05) * k, 0.3 * k], pole: [-1, -0.2, -0.4], f)
        case .offer:
            // Leaning forward a little, holding a treat out low.
            let k = size
            pose(torso, spin(0.22, [1, 0, 0]))
            pose(head, spin(0.25, [1, 0, 0]))
            reach(0, to: [-0.08 * k, 0.02 * k, 0.3 * k], pole: [-1, -0.4, -0.3], f)
        case .toss:
            // Arm back over the shoulder, then flung forward and up, and
            // down again on the follow-through.
            let k = size
            let target: SIMD3<Float>
            if t < 0.35 { target = [-0.22, 0.42, -0.14] }
            else if t < 0.55 { target = [-0.16, 0.46, 0.24] }
            else { target = [-0.1, 0.12, 0.26] }
            reach(0, to: target * k, pole: [-1, -0.3, -0.2], f)
            pose(torso, spin(t < 0.35 ? 0.25 : -0.2, [0, 1, 0]) * spin(t < 0.35 ? -0.08 : 0.12, [1, 0, 0]))
        }
        body.position = [0, lift * f, 0]
        body.orientation = spin(turn, [0, 1, 0])
    }

    /// Points an arm so its hand reaches `target` (in the body's own space,
    /// facing +Z), bending the elbow out towards `pole`, blended in by `f`.
    /// Reaching for a point, rather than turning joints by set angles, is
    /// what keeps the hands where they belong on short, chubby arms.
    private func reach(_ side: Int, to target: SIMD3<Float>, pole: SIMD3<Float>, _ f: Float) {
        let k = size
        let shoulder = SIMD3<Float>(0.145 * k * (side == 0 ? -1 : 1), 0.205 * k, 0)
        let upper = 0.15 * k, lower = 0.165 * k
        let offset = target - shoulder
        let d = min(max(simd_length(offset), 0.02), (upper + lower) * 0.995)
        let dir = simd_normalize(offset)
        let bend = acos(min(1, max(-1, (upper * upper + d * d - lower * lower) / (2 * upper * d))))
        var out = pole - dir * simd_dot(pole, dir)
        if simd_length(out) < 0.0001 { out = [0, 0, -1] }
        out = simd_normalize(out)
        let upperDir = dir * cos(bend) + out * sin(bend)
        let elbow = shoulder + upperDir * upper
        let foreDir = simd_normalize(shoulder + dir * d - elbow)
        let down = SIMD3<Float>(0, -1, 0)
        let shoulderTurn = simd_quatf(from: down, to: upperDir)
        let elbowTurn = simd_quatf(from: down, to: shoulderTurn.inverse.act(foreDir))
        shoulders[side].orientation = simd_slerp(shoulders[side].orientation, shoulderTurn, f)
        elbows[side].orientation = simd_slerp(elbows[side].orientation, elbowTurn, f)
    }
}

extension UIColor {
    /// The same hue, lighter or darker.
    func withBrightness(_ factor: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: min(1, b * factor), alpha: a)
    }
}
