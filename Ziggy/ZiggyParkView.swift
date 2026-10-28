//
//  ZiggyParkView.swift
//  Ziggy
//
//  The park: a little world to take Ziggy for a walk in, together.
//
//  Each of you steers yourself with the thumb pad at the bottom of the
//  screen, and looks around by dragging anywhere else (`ZiggyParkControls`).
//  You can talk as you walk (`ZiggyParkVoice`), and set off a surprise
//  for the two of you (`ZiggyParkFun`). Your partner's phone
//  tells this one where they are (`ZiggyParkLink`), and Ziggy trots along
//  with whoever is in the park — ahead of you while you walk, turning round
//  to look up at you when you stop. The thumb pad always walks you the way
//  the camera is facing, so up is always "away from me".
//

import RealityKit
import SwiftUI

// MARK: - The world

/// Owns the scene and the per-frame loop. SwiftUI only writes `input`, turns
/// the camera and asks for tricks; everything that moves is worked out here.
@available(iOS 18.0, *)
final class ZiggyParkWorld {

    enum Company: Equatable {
        /// No relationship on this phone, so nobody to share the park with.
        case solo
        case waiting
        case together(name: String)
    }

    // Built when first needed — after the loading screen is up — rather
    // than while the screen is still opening.
    lazy var ziggy = Ziggy3D()
    let link = ZiggyParkLink()
    let voice = ZiggyParkVoice()
    private let fun = ParkFun()
    private let animals = ParkAnimals()

    private let camera = PerspectiveCamera()
    private let scenery = ParkScenery()
    private lazy var me = ParkPerson3D(look: .casual)
    private lazy var partner = ParkPerson3D(look: .sundress)

    /// Thumb pad, -1...1 on each axis. Up on screen is negative y.
    var input: SIMD2<Float> = .zero

    /// Walking on by itself, the thumb pad locked forward. You steer by
    /// swinging the camera, the way auto-run works in games.
    var autoWalk = false

    /// Called when your partner arrives or leaves. Not every frame.
    var onCompanyChange: ((Company) -> Void)?

    /// Called with the name of each part of the walk as you arrive in it.
    var onAreaChange: ((String) -> Void)?
    private var area = ""

    /// Called when a surprise starts, yours or your partner's.
    var onSurprise: ((ParkSurprise) -> Void)?

    /// The animal close enough to say hello to, whenever that changes.
    var onNearbyFriend: ((ParkFriend?) -> Void)?
    /// You said hello to an animal.
    var onGreet: ((ParkFriend) -> Void)?
    private var nearby: (index: Int, friend: ParkFriend)?

    /// The note for you that you are standing at, whenever that changes.
    var onNearbyNote: ((ParkNote?) -> Void)?
    /// The way to the closest note waiting for you: who left it, how far,
    /// which way (degrees from straight ahead on screen) and how many there
    /// are. Nil when there are none. Only sent when it changes enough to see.
    var onNoteCompass: (((name: String, metres: Int, bearing: Double, count: Int)?) -> Void)?
    /// Your partner found one of your notes.
    var onNoteFound: (() -> Void)?
    private let notes = ParkNotes()
    private var waitingForMe = 0
    private var nearbyNote: ParkNote?
    private var lastCompass: (metres: Int, bearing: Int, count: Int)?
    private var lastSurprise: ParkSurprise?

    /// How long Ziggy has been failing to catch you up, and how far off he
    /// was a moment ago.
    private var ziggyStuck: Float = 0
    private var ziggyWasAway: Float = 0

    /// Seconds of zoomies left, and how far round you Ziggy has run.
    private var zoomies: Float = 0
    private var zoomAngle: Float = 0


    // A straight third-person view: low behind your shoulder, looking ahead
    // along the way you are walking rather than down at the ground.
    private var orbitYaw: Float = 0.54 + .pi
    private var orbitPitch: Float = 0.2
    private var orbitDistance: Float = 4.6

    /// The camera direction the thumb pad is read against. Frozen while your
    /// thumb is down: if it followed the camera as the camera swung in
    /// behind you, every slightly-off push would bend your path into a curve.
    private var steeringYaw: Float = 0
    private var steering = false

    /// Little hearts that float up when you hold hands.
    private var hearts: [(entity: ModelEntity, age: Float)] = []
    private var nextHeart: Float = 0

    /// How long you have been standing still, and when Ziggy will next
    /// amuse himself while he waits for you.
    private var idleTime: Float = 0
    private var nextIdleTrick: Float = 5

    /// Seconds left before the camera starts settling back in behind you
    /// after you have swung it round by hand.
    private var lookingAround: Float = 0

    /// How far back the camera actually is: the orbit distance, unless a
    /// building is in the way, in which case it comes in closer.
    private var cameraReach: Float = 4.6
    private var cameraFocus: SIMD3<Float> = [50, 1.15, 38]

    // You start in Hanami Park, just out of the torii tunnel, looking down
    // the path towards the heart-shaped lake, with Ziggy at your side. The
    // first garden, the canal and the town are back through the tunnel.
    private var meMove = ParkMover(position: [50, 0, 38], heading: 0.54)
    private var partnerMove = ParkMover(position: [50.8, 0, 38], heading: 0.54)
    private var ziggyMove = ParkMover(position: [50.4, 0, 37.8], heading: 0.54)

    private var myLook: ParkLook = ParkLook(rawValue: UserDefaults.standard.integer(forKey: "ZiggyPark.look")) ?? .casual
    private var choseLook = false

    /// Choosing who you are before the walk: the two of you stand side by
    /// side facing the camera, with Ziggy in front, until you pick.
    private(set) var choosing = true
    private var previews: [ParkPerson3D] = []
    private var pickRing: Entity?
    private(set) var picked: ParkLook = .casual
    /// Where the camera is swinging round to, after choosing.
    private var cameraYawGoal: Float?
    /// Which way you turn to do an emote: towards your partner if they are
    /// close, otherwise the way the camera is looking.
    private var emoteFacing: Float?
    private var partnerWasHere = false
    private var company: Company = .solo

    private var subscription: EventSubscription?

    /// A relaxed, unhurried stroll.
    private let walkSpeed: Float = 1.35
    /// Ziggy next to the people: a little puppy, about knee to hip high.
    private let ziggySize: Float = 0.36

    private var skyLight: Entity?

    // Golden hour, then dusk, then night, then dawn, round and round.
    private let sunLight = DirectionalLight()
    private let fillLight = DirectionalLight()
    /// A few real lights that move to whichever lamps are nearest you,
    /// fading out of one lamp before fading in at the next.
    private var lampLights: [(light: PointLight, spot: SIMD3<Float>?, level: Float, wanted: Bool)] = []
    private var nightAmount: Float = 0
    private var nextLampPick: Float = 0
    private var skyExponent: Float = 0.4

    // MARK: Building

    func build(into content: inout RealityViewCameraContent, progress: @escaping (Float) -> Void) async {

        content.camera = .virtual

        // Let the loading screen draw before any heavy lifting starts.
        try? await Task.sleep(for: .milliseconds(30))

        // The world first, in pieces, while the loading screen shows how far
        // along it is; only then is it put on screen, all at once.
        await scenery.build(progress: progress)

        let scene = Entity()
        content.add(scene)

        scene.addChild(scenery.root)
        animals.build(in: scenery.hanami)
        scene.addChild(animals.root)
        buildLights(scene)

        ziggy.root.scale = .init(repeating: ziggySize)
        scene.addChild(ziggy.root)
        scene.addChild(me.root)
        scene.addChild(partner.root)
        partner.root.isEnabled = false
        scene.addChild(fun.root)
        scene.addChild(notes.root)
        apply(meMove, to: me.root)
        apply(ziggyMove, to: ziggy.root)
        buildChoosing(scene)

        camera.camera.fieldOfViewInDegrees = 52
        camera.camera.near = 0.05
        camera.camera.far = 1000
        scene.addChild(camera)
        placeCamera(dt: 1)

        // Light from the whole sky — blue from above, warm off the sand
        // below — so the shaded side of everything is soft rather than flat.
        if let sky = await ParkSkyLight.make(zenith: UIColor(0xA7A8E6), horizon: UIColor(0xFFD9B8), ground: UIColor(0xA6CC7E)) {
            scene.addChild(sky)
            ParkSkyLight.apply(sky, to: scene)
            me.onRebuild = { ParkSkyLight.apply(sky, to: $0) }
            partner.onRebuild = { ParkSkyLight.apply(sky, to: $0) }
            skyLight = sky
        }

        link.onTrick = { [weak self] trick in self?.ziggy.perform(trick) }
        link.onEmote = { [weak self] e in
            guard let self, self.partnerWasHere else { return }
            self.partner.play(e)
            self.effects(of: e, on: self.partnerMove.position)
        }
        link.onNotes = { [weak self] all in
            guard let self else { return }
            self.notes.show(all)
            self.waitingForMe = all.filter { !$0.mine }.count
        }
        link.onNoteFound = { [weak self] in self?.onNoteFound?() }
        link.onSurprise = { [weak self] surprise, spot, facing in
            self?.play(surprise, at: [spot.x, 0, spot.y], facing: facing)
        }
        fun.onPresentOpened = { [weak self] in
            guard let self, !self.ziggy.isDoingTrick else { return }
            self.ziggy.perform(.flip)
        }
        link.start()
        company = link.isLinked ? .waiting : .solo
        onCompanyChange?(company)

        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            let dt = Float(event.deltaTime)
            MainActor.assumeIsolated { self?.tick(min(dt, 1 / 20)) }
        }
    }

    func leave() {
        voice.leave()
        link.stop()
        subscription?.cancel()
        subscription = nil
    }

    private func buildLights(_ scene: Entity) {
        // Golden hour: a low, warm sun from the side, so faces glow and
        // shadows stretch long across the grass. By night the same light
        // becomes moonlight: dim, cool and blue.
        sunLight.light.intensity = 3900
        sunLight.light.color = UIColor(0xFFCB95)
        sunLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 18, depthBias: 1.5)
        sunLight.look(at: .zero, from: [-9, 6, 4], relativeTo: nil)
        scene.addChild(sunLight)

        // A soft lavender fill from the other side, the colour of the sky.
        fillLight.light.intensity = 900
        fillLight.light.color = UIColor(0xCDBEFF)
        fillLight.look(at: .zero, from: [7, 4, -3], relativeTo: nil)
        scene.addChild(fillLight)

        // Real lights for the lamps nearest you, so at night they light the
        // path and the people walking under them, not just glow.
        // Six, not one per lamp: every real light is paid for on every
        // pixel of the screen, and six around you look the same as a hundred.
        for _ in 0..<6 {
            let lamp = PointLight()
            lamp.light.intensity = 0
            lamp.light.color = UIColor(0xFFC27A)
            lamp.light.attenuationRadius = 9
            lamp.isEnabled = false
            scene.addChild(lamp)
            lampLights.append((lamp, nil, 0, false))
        }
    }

    /// 0 at golden hour, 1 at night: a minute of sunset, dusk drawing in,
    /// a long night, then dawn and round again.
    private static func night(at time: Float) -> Float {
        let t = time.truncatingRemainder(dividingBy: 330)
        func ease(_ x: Float) -> Float { let c = min(1, max(0, x)); return c * c * (3 - 2 * c) }
        if t < 55 { return 0 }
        if t < 100 { return ease((t - 55) / 45) }
        if t < 280 { return 1 }
        return 1 - ease((t - 280) / 50)
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Float) -> UIColor {
        func channel(_ c: UInt32, _ shift: UInt32) -> CGFloat { CGFloat((c >> shift) & 0xFF) / 255 }
        let k = CGFloat(t)
        return UIColor(red: channel(a, 16) * (1 - k) + channel(b, 16) * k,
                       green: channel(a, 8) * (1 - k) + channel(b, 8) * k,
                       blue: channel(a, 0) * (1 - k) + channel(b, 0) * k, alpha: 1)
    }

    private func updateTimeOfDay(_ dt: Float) {
        // Read from the real time of day rather than counted from when you
        // opened the park, so both phones are at the same moment of the
        // evening: the same sunset, the same night, together.
        let now = Float(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 330))
        let n = Self.night(at: now)
        nightAmount = n

        sunLight.light.intensity = 3900 + (420 - 3900) * n
        sunLight.light.color = Self.mix(0xFFCB95, 0x9FB4FF, n)
        fillLight.light.intensity = 900 + (420 - 900) * n
        fillLight.light.color = Self.mix(0xCDBEFF, 0x5E6FC8, n)
        scenery.setNight(n)

        // Dim the light from the sky itself as the evening goes.
        let exponent: Float = 0.4 + (-1.9 - 0.4) * n
        if abs(exponent - skyExponent) > 0.02, let sky = skyLight, var ibl = sky.components[ImageBasedLightComponent.self] {
            ibl.intensityExponent = exponent
            sky.components.set(ibl)
            skyExponent = exponent
        }

        // Every half second, work out which lamps are nearest you. A light
        // already on one of them stays; the others fade out where they are
        // and only then move on to a lamp that needs one, so nothing pops.
        nextLampPick -= dt
        if nextLampPick <= 0 {
            nextLampPick = 0.5
            let here = meMove.position
            var nearest = scenery.lightSpots
                .sorted { simd_distance_squared($0, here) < simd_distance_squared($1, here) }
                .prefix(lampLights.count)
                .map { $0 }
            for i in lampLights.indices {
                if let spot = lampLights[i].spot, let k = nearest.firstIndex(of: spot) {
                    lampLights[i].wanted = true
                    nearest.remove(at: k)
                } else {
                    lampLights[i].wanted = false
                }
            }
            for i in lampLights.indices where !lampLights[i].wanted && lampLights[i].level < 0.01 && !nearest.isEmpty {
                let spot = nearest.removeFirst()
                lampLights[i].spot = spot
                lampLights[i].light.position = spot
                lampLights[i].wanted = true
            }
        }
        for i in lampLights.indices {
            let goal: Float = lampLights[i].wanted ? 1 : 0
            lampLights[i].level += (goal - lampLights[i].level) * min(1, dt * 2.5)
            if !lampLights[i].wanted && lampLights[i].level < 0.01 { lampLights[i].level = 0 }
            let lamp = lampLights[i].light
            let on = n > 0.03 && lampLights[i].level > 0
            if lamp.isEnabled != on { lamp.isEnabled = on }
            lamp.light.intensity = 36000 * n * lampLights[i].level
        }
    }

    // MARK: Things SwiftUI asks for

    /// Says hello to whichever animal is beside you.
    func greetNearby() {
        guard let nearby else { return }
        let spot = animals.greet(nearby.index, from: meMove.position)
        fun.hearts(at: spot, count: 7)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if !ziggy.isDoingTrick { ziggy.perform(.spin) }
        onGreet?(nearby.friend)
    }

    /// Whether there is anyone to leave notes for.
    var canLeaveNotes: Bool { link.isLinked }

    /// Leaves a note floating just in front of you.
    func leaveNote(_ text: String) {
        let facing = SIMD3<Float>(sin(meMove.heading), 0, cos(meMove.heading))
        let spot = scenery.constrain(meMove.position + facing * 0.9, radius: 0.3)
        link.send(note: text, at: [spot.x, spot.z])
        fun.hearts(at: spot + [0, 1, 0], count: 6)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Opens the note you are standing at: it bursts into hearts and is
    /// gone from the park for you both.
    func openNearbyNote() -> ParkNote? {
        guard let note = nearbyNote else { return nil }
        if let at = notes.open(note.id) { fun.celebrate(at: at) }
        link.open(note: note.id)
        nearbyNote = nil
        onNearbyNote?(nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return note
    }

    func orbit(by drag: CGSize) {
        lookingAround = 2.5
        orbitYaw -= Float(drag.width) * 0.008
        orbitPitch = min(1.2, max(0.04, orbitPitch + Float(drag.height) * 0.005))
    }

    func zoom(to distance: Float) {
        orbitDistance = min(14, max(2.5, distance))
    }

    var zoomDistance: Float { orbitDistance }

    func perform(_ trick: Ziggy3DTrick) {
        guard !ziggy.isDoingTrick else { return }
        ziggy.perform(trick)
        link.send(trick: trick)
    }

    /// Something fun, picked at random — never the same one twice running.
    func surprise() {
        let choice = ParkSurprise.allCases.filter { $0 != lastSurprise }.randomElement() ?? .confetti
        play(choice, at: meMove.position, facing: orbitYaw)
        link.send(surprise: choice, at: [meMove.position.x, meMove.position.z], facing: orbitYaw)
    }

    private func play(_ surprise: ParkSurprise, at spot: SIMD3<Float>, facing: Float) {
        lastSurprise = surprise
        fun.play(surprise, at: spot, facing: facing)
        if surprise == .zoomies {
            zoomies = 5.5
            zoomAngle = atan2(ziggyMove.position.x - meMove.position.x, ziggyMove.position.z - meMove.position.z)
        }
        onSurprise?(surprise)
    }

    // MARK: Choosing who you are

    private var facing: SIMD3<Float> { [sin(meMove.heading), 0, cos(meMove.heading)] }
    /// The camera's right while it faces you, during choosing.
    private var choosingRight: SIMD3<Float> { [facing.z, 0, -facing.x] }

    private func buildChoosing(_ scene: Entity) {
        picked = myLook
        me.root.isEnabled = false
        for look in ParkLook.allCases {
            let person = ParkPerson3D(look: look)
            let side: Float = look == .casual ? -1 : 1
            person.root.position = meMove.position + choosingRight * (side * 0.5)
            person.root.orientation = spin(meMove.heading + side * -0.15, [0, 1, 0])
            scene.addChild(person.root)
            previews.append(person)
        }
        // A soft pink glow on the ground under whoever is picked.
        let ring = Entity()
        ring.attach(ParkMesh.sphere(0.42), ParkPaint.clear(UIColor(0xFF8FB0), opacity: 0.45, roughness: 1), scale: [1, 0.02, 1])
        ring.attach(ParkMesh.sphere(0.3), ParkPaint.glow(UIColor(0xFFC2D4)), scale: [1, 0.015, 1])
        scene.addChild(ring)
        pickRing = ring
        // Ziggy in front of the two of them, looking up.
        ziggyMove.position = meMove.position + facing * 0.55
        ziggyMove.heading = meMove.heading
        apply(ziggyMove, to: ziggy.root)
        // The camera out in front, looking back at them.
        orbitYaw = meMove.heading
        orbitPitch = 0.12
        orbitDistance = 4.6
        cameraFocus = meMove.position + [0, 0.45, 0]
    }

    /// Picks who you will be; they give a happy little hop.
    func pick(_ look: ParkLook) {
        picked = look
        previews.first { $0.look == look }?.play(.yay)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Done choosing: you become who you picked, and the camera swings
    /// round behind you for the walk.
    func startWalking() {
        guard choosing else { return }
        choosing = false
        myLook = picked
        choseLook = true
        UserDefaults.standard.set(picked.rawValue, forKey: "ZiggyPark.look")
        me.wear(picked)
        me.root.isEnabled = true
        for person in previews { person.root.removeFromParent() }
        previews = []
        pickRing?.removeFromParent()
        pickRing = nil
        ziggyMove.position = scenery.constrain(meMove.position + choosingRight * -0.5 + facing * 0.3, radius: 0.16)
        cameraYawGoal = meMove.heading + .pi
        orbitPitch = 0.2
        orbitDistance = 4.6
        me.play(.wave)
    }

    private func tickChoosing(_ dt: Float) {
        let chosen = previews.first { $0.look == picked }
        for person in previews { person.update(deltaTime: dt, speed: 0) }
        if let chosen, let ring = pickRing {
            ring.position = chosen.root.position + [0, 0.012, 0]
            ring.scale = .init(repeating: 1 + sin(Float(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 100)) * 3) * 0.05)
        }
        ziggy.update(deltaTime: dt, speed: 0)
        scenery.update(deltaTime: dt, viewer: meMove.position)
        animals.update(deltaTime: dt, viewer: meMove.position, viewerSpeed: 0, night: nightAmount) { [scenery] p, radius in
            scenery.constrain(p, radius: radius)
        }
        fun.update(deltaTime: dt)
        notes.update(deltaTime: dt)
        updateTimeOfDay(dt)
        placeCamera(dt: dt)
    }

    // MARK: Emotes

    /// Does an emote, and your partner sees you do it.
    func emote(_ e: ParkEmote) {
        guard !choosing else { return }
        me.play(e)
        if partnerWasHere && simd_distance(partnerMove.position, meMove.position) < 6 {
            let toThem = partnerMove.position - meMove.position
            emoteFacing = atan2(toThem.x, toThem.z)
        } else {
            // The camera looks along -(sin yaw, cos yaw).
            emoteFacing = orbitYaw + .pi
        }
        link.send(emote: e)
        effects(of: e, on: meMove.position)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Hearts for love, confetti for yay — and Ziggy joins in.
    private func effects(of e: ParkEmote, on spot: SIMD3<Float>) {
        let head = spot + [0, 1.55, 0]
        switch e {
        case .love:
            fun.bigHeart(at: head + [0, 0.25, 0])
            fun.hearts(at: head, count: 5)
            if !ziggy.isDoingTrick { ziggy.perform(.sit) }
        case .yay:
            fun.sprinkle(at: head + [0, 0.3, 0])
            if !ziggy.isDoingTrick { ziggy.perform(.flip) }
        case .dance:
            fun.hearts(at: head, count: 3)
            if !ziggy.isDoingTrick { ziggy.perform(.spin) }
        case .wave, .bow:
            break
        }
    }

    // MARK: Every frame

    private func tick(_ dt: Float) {
        if choosing {
            tickChoosing(dt)
            return
        }
        // You. The thumb pad is read relative to the camera as it was when
        // your thumb went down, so holding it steady walks you in a straight
        // line even while the camera swings round behind you.
        let stick = autoWalk ? SIMD2<Float>(0, -1) : input
        let pushing = simd_length(stick) > 0.08
        if pushing && !steering { steeringYaw = orbitYaw }
        // On auto-walk you steer with the camera, so the direction follows it.
        if autoWalk { steeringYaw = orbitYaw }
        steering = pushing
        let away = SIMD3<Float>(-sin(steeringYaw), 0, -cos(steeringYaw))
        let right = SIMD3<Float>(cos(steeringYaw), 0, -sin(steeringYaw))
        var wanted = pushing ? right * stick.x - away * stick.y : .zero
        if simd_length(wanted) > 1 { wanted = simd_normalize(wanted) }
        meMove.ease(toward: wanted * walkSpeed, rate: 5, dt: dt)
        meMove.position = scenery.constrain(meMove.position, radius: 0.2)
        meMove.faceTravel(dt: dt)

        let here = ParkCity.area(at: [meMove.position.x, meMove.position.z])
        if here != area {
            area = here
            onAreaChange?(here)
        }

        // Your partner, wherever their phone says they are right now. Only
        // ever them: nobody walks beside you until they open the park.
        let there = link.partnerIfHere()
        if let there {
            let target = SIMD3<Float>(there.position.x, 0, there.position.y)
            if !partnerWasHere || simd_distance(target, partnerMove.position) > 4 {
                // Just arrived, or far out after a long gap: appear there
                // rather than run across the park.
                partnerMove.position = target
                partnerMove.heading = there.heading
            }
            partner.root.isEnabled = true
            // Eased onto where they are, closely: their own phone has already
            // walked them round every tree and lamp post, so there is nothing
            // to steer round here, only network jitter to smooth out.
            let pull = min(1, dt * 9)
            partnerMove.position += (target - partnerMove.position) * pull
            partnerMove.velocity = SIMD3(there.velocity.x, 0, there.velocity.y)
            if !partnerMove.faceTravel(dt: dt) {
                partnerMove.turn(toward: there.heading, rate: 8, dt: dt)
            }
            partner.wear(there.look)

            // Two people in the same outfit: one of you swaps, decided by
            // device ID so both phones agree on who.
            if !choseLook, there.look == myLook, let theirID = link.partnerID, link.myID > theirID {
                myLook = myLook.next
                me.wear(myLook)
            }

            // You cannot walk through them.
            separate(&meMove, from: partnerMove.position, by: 0.42)
        } else {
            partner.root.isEnabled = false
            partnerMove.velocity = .zero
        }
        partnerWasHere = there != nil

        link.send(
            position: [meMove.position.x, meMove.position.z],
            velocity: [meMove.velocity.x, meMove.velocity.z],
            heading: meMove.heading,
            look: myLook
        )

        let nextCompany: Company
        if let there {
            nextCompany = .together(name: there.name)
        } else {
            nextCompany = link.isLinked ? .waiting : .solo
        }
        if nextCompany != company {
            company = nextCompany
            onCompanyChange?(company)
        }

        // Ziggy walks with you, at your side and half a step ahead, the way a
        // dog on a walk does. When your partner is close he walks between
        // the two of you instead. He walks at your pace; he only breaks into
        // a trot when he has fallen properly behind. When you stop he stops
        // beside you and turns to look up.
        let partnerClose = partnerWasHere && simd_distance(partnerMove.position, meMove.position) < 3.5
        let middle = partnerClose ? (meMove.position + partnerMove.position) / 2 : meMove.position
        let facing = SIMD3<Float>(sin(meMove.heading), 0, cos(meMove.heading))
        let myLeft = SIMD3<Float>(facing.z, 0, -facing.x)
        let spot = partnerClose
            ? middle + facing * 0.55
            : meMove.position + myLeft * 0.45 + facing * 0.2

        var ziggyWants: SIMD3<Float> = .zero
        zoomies = max(0, zoomies - dt)
        if zoomies > 0 && !ziggy.isDoingTrick {
            // Round and round you, as fast as his legs will go.
            zoomAngle += dt * 2.4
            let lap = meMove.position + [sin(zoomAngle) * 1.8, 0, cos(zoomAngle) * 1.8]
            ziggyWants = arrive(ziggyMove.position, at: lap, top: 4.2, slack: 0.05)
        } else if !ziggy.isDoingTrick {
            let behind = simd_distance(ziggyMove.position, spot)
            let pace = meMove.speed > 0.1 ? meMove.speed * 1.08 : walkSpeed * 0.6
            let top = behind > 3 ? walkSpeed * 1.5 : max(pace, 0.5)
            // When you are standing still he only shuffles over if he has
            // ended up well out of place, so he settles instead of fidgeting.
            if meMove.speed > 0.1 || behind > 0.9 {
                ziggyWants = arrive(ziggyMove.position, at: spot, top: top, slack: 0.15)
            }
        }
        ziggyMove.ease(toward: ziggyWants, rate: 5, dt: dt)
        ziggyMove.position = scenery.constrain(ziggyMove.position, radius: 0.16)

        // He runs straight for you, so a fence or a corner can leave him
        // stuck on the far side — turning off the canal into the torii
        // tunnel, say. Like a pet in a game, if he is stuck or far behind he
        // pops back in at your side, with a little puff of hearts.
        let ziggyAway = simd_distance(ziggyMove.position, meMove.position)
        ziggyStuck = ziggyAway > 3 && ziggyAway > ziggyWasAway - dt * 0.4 ? ziggyStuck + dt : 0
        ziggyWasAway = ziggyAway
        if ziggyAway > 10 || ziggyStuck > 1.6 {
            ziggyMove.position = scenery.constrain(meMove.position - facing * 0.9 + myLeft * 0.5, radius: 0.16)
            ziggyMove.velocity = .zero
            ziggyMove.heading = meMove.heading
            ziggyStuck = 0
            ziggyWasAway = 0
            fun.hearts(at: ziggyMove.position + [0, 0.35, 0], count: 4)
        }
        if !ziggyMove.faceTravel(dt: dt) {
            let look = middle - ziggyMove.position
            ziggyMove.turn(toward: atan2(look.x, look.z), rate: 3, dt: dt)
        }
        separate(&ziggyMove, from: meMove.position, by: 0.3)
        if partnerWasHere { separate(&ziggyMove, from: partnerMove.position, by: 0.3) }

        // Side by side, you hold hands: each of you reaches for the other
        // with the hand on their side. Both phones work this out the same
        // way, so you both see it.
        let together = partnerWasHere && simd_distance(partnerMove.position, meMove.position) < 1.25
        if together {
            me.holdHands(arm: side(of: partnerMove.position, from: meMove))
            partner.holdHands(arm: side(of: meMove.position, from: partnerMove))
        } else {
            me.holdHands(arm: nil)
            partner.holdHands(arm: nil)
        }
        updateHearts(dt, show: together, above: (meMove.position + partnerMove.position) / 2)

        // Doing an emote, you turn to whoever it is for — your partner, or
        // whatever the camera is looking at. The turn is your real heading,
        // so your partner's phone sees you turn to them too.
        if let facing = emoteFacing, me.isEmoting, meMove.speed < 0.35 {
            meMove.turn(toward: facing, rate: 8, dt: dt)
        } else {
            emoteFacing = nil
        }
        apply(meMove, to: me.root)
        apply(partnerMove, to: partner.root)
        apply(ziggyMove, to: ziggy.root)

        // Setting off walking ends an emote.
        if meMove.speed > 0.35 && me.isEmoting { me.stopEmote() }
        me.update(deltaTime: dt, speed: meMove.speed)
        partner.update(deltaTime: dt, speed: partnerMove.speed)
        // His legs are scaled down with him, so they need more steps to
        // cover the same ground.
        ziggy.update(deltaTime: dt, speed: ziggyMove.speed / ziggySize)

        // Stand still for a little while and Ziggy entertains himself: a
        // spin, a sit, a roll in the grass. Only on this phone, just for fun.
        // Not on the bridge, where a roll would look like he had fallen
        // through the planks.
        let onBridge = ParkScenery.height(atX: ziggyMove.position.x, z: ziggyMove.position.z) > 0.02
        if meMove.speed < 0.05 && ziggyMove.speed < 0.05 && !onBridge {
            idleTime += dt
            if idleTime > nextIdleTrick && !ziggy.isDoingTrick {
                ziggy.perform([Ziggy3DTrick.spin, .sit, .sit, .flip].randomElement() ?? .sit)
                nextIdleTrick = idleTime + Float.random(in: 6...10)
            }
        } else {
            idleTime = 0
            nextIdleTrick = Float.random(in: 4...6)
        }
        scenery.update(deltaTime: dt, viewer: meMove.position)
        animals.update(deltaTime: dt, viewer: meMove.position, viewerSpeed: meMove.speed, night: nightAmount) { [scenery] p, radius in
            scenery.constrain(p, radius: radius)
        }
        notes.update(deltaTime: dt)
        updateNotes()
        let close = animals.nearest(to: meMove.position)
        if close?.index != nearby?.index {
            let changed = close?.friend != nearby?.friend
            nearby = close
            if changed { onNearbyFriend?(close?.friend) }
        }
        fun.update(deltaTime: dt)
        updateTimeOfDay(dt)

        // Your partner's voice a little softer the further away along the
        // path they are.
        voice.setPartnerDistance(partnerWasHere ? simd_distance(meMove.position, partnerMove.position) : nil)

        // Third person: the camera settles in behind you as you walk
        // forward, unless you have just swung it round to look at something.
        // Only the forward part of the thumb pad turns it — steering sideways
        // with the camera chasing you round would walk you in circles.
        if let goal = cameraYawGoal {
            var turn = goal - orbitYaw
            while turn > .pi { turn -= 2 * .pi }
            while turn < -.pi { turn += 2 * .pi }
            orbitYaw += turn * min(1, dt * 2.5)
            if abs(turn) < 0.01 || lookingAround > 0 { cameraYawGoal = nil }
        }
        lookingAround = max(0, lookingAround - dt)
        let forwardPush = autoWalk ? 1 : max(0, -input.y)
        if lookingAround == 0, meMove.speed > 0.3, forwardPush > 0.2 {
            var turn = (meMove.heading + .pi) - orbitYaw
            while turn > .pi { turn -= 2 * .pi }
            while turn < -.pi { turn += 2 * .pi }
            orbitYaw += turn * min(1, dt * 2.2 * forwardPush)
        }
        placeCamera(dt: dt)
    }

    /// Orbits you, at chest height, so you are the middle of the screen. It
    /// eases after you rather than being welded on, so the world swings past
    /// smoothly.
    private func placeCamera(dt: Float) {
        // Aimed just above your head, so you sit in the lower middle of the
        // screen with the way ahead in view.
        let focusGoal = meMove.position + [0, (choosing ? 0.45 : 1.15) + ParkScenery.height(atX: meMove.position.x, z: meMove.position.z), 0]
        cameraFocus += (focusGoal - cameraFocus) * min(1, dt * 8)
        let direction = SIMD3<Float>(
            sin(orbitYaw) * cos(orbitPitch),
            sin(orbitPitch),
            cos(orbitYaw) * cos(orbitPitch)
        )
        // Like a game camera: step out from you towards where the camera
        // wants to be, and stop short of the first wall in the way, rather
        // than ending up inside a building looking at its insides.
        var clear = orbitDistance
        let steps = 24
        for step in 1...steps {
            let d = orbitDistance * Float(step) / Float(steps)
            if scenery.blocksView(cameraFocus + direction * d) {
                clear = max(1.0, d - orbitDistance / Float(steps) - 0.3)
                break
            }
        }
        // In quickly, so a wall never fills the screen; back out gently.
        cameraReach += (clear - cameraReach) * min(1, dt * (clear < cameraReach ? 14 : 3))
        let offset = direction * cameraReach
        camera.look(at: cameraFocus, from: cameraFocus + offset, relativeTo: nil)
    }

    // MARK: Hand in hand

    /// Which arm a person facing `mover.heading` would reach out with to hold
    /// hands with someone standing at `other`: 1 for the arm on their +x side.
    private func side(of other: SIMD3<Float>, from mover: ParkMover) -> Int {
        let localX = SIMD3<Float>(cos(mover.heading), 0, -sin(mover.heading))
        return simd_dot(other - mover.position, localX) > 0 ? 1 : 0
    }

    private func updateHearts(_ dt: Float, show: Bool, above: SIMD3<Float>) {
        if hearts.isEmpty, let parent = me.root.parent {
            var shape = MeshBatch()
            shape.blob([-0.022, 0, 0], [0.026, 0.026, 0.012], rings: 6, segments: 10)
            shape.blob([0.022, 0, 0], [0.026, 0.026, 0.012], rings: 6, segments: 10)
            shape.tube(base: [0, -0.052, 0], height: 0.045, radius: 0, topRadius: 0.042, segments: 12)
            let paints = [UIColor(0xFF5C7C), UIColor(0xFF8FAB), UIColor(0xFFB3C7)]
            for i in 0..<12 {
                guard let heart = shape.entity(ParkPaint.glow(paints[i % paints.count])) else { break }
                heart.isEnabled = false
                parent.addChild(heart)
                hearts.append((heart, 99))
            }
        }
        nextHeart -= dt
        if show && nextHeart <= 0, let free = hearts.firstIndex(where: { $0.age > 2.6 }) {
            nextHeart = 0.75
            hearts[free].age = 0
            hearts[free].entity.position = above + [Float.random(in: -0.15...0.15), 1.3, Float.random(in: -0.1...0.1)]
            hearts[free].entity.isEnabled = true
        }
        for i in hearts.indices where hearts[i].entity.isEnabled {
            hearts[i].age += dt
            let t = hearts[i].age
            if t > 2.6 { hearts[i].entity.isEnabled = false; continue }
            hearts[i].entity.position.y += dt * 0.32
            hearts[i].entity.position.x += sin(t * 3 + Float(i)) * dt * 0.08
            let grow = min(1, t * 3) * (t > 1.8 ? max(0, (2.6 - t) / 0.8) : 1)
            hearts[i].entity.scale = .init(repeating: grow * 1.2)
            // Always turned to face the camera.
            hearts[i].entity.orientation = spin(orbitYaw, [0, 1, 0])
        }
    }

    // MARK: Love notes

    private func updateNotes() {
        let here = notes.nearestForMe(to: meMove.position, within: 1.8)
        if here?.id != nearbyNote?.id {
            nearbyNote = here
            onNearbyNote?(here)
        }
        guard let target = notes.closestForMe(to: meMove.position) else {
            if lastCompass != nil { lastCompass = nil; onNoteCompass?(nil) }
            return
        }
        let gap = target.position - SIMD2(meMove.position.x, meMove.position.z)
        let metres = Int(simd_length(gap).rounded())
        // The camera looks along -(sin yaw, cos yaw); turn that into an
        // angle on screen, clockwise from straight up.
        var bearing = atan2(gap.x, gap.y) - atan2(-sin(orbitYaw), -cos(orbitYaw))
        while bearing > .pi { bearing -= 2 * .pi }
        while bearing < -.pi { bearing += 2 * .pi }
        let degrees = Int(-bearing * 180 / .pi / 10) * 10
        let next = (metres: metres, bearing: degrees, count: waitingForMe)
        if lastCompass?.metres != next.metres || lastCompass?.bearing != next.bearing || lastCompass?.count != next.count {
            lastCompass = next
            onNoteCompass?((target.name, metres, Double(degrees), waitingForMe))
        }
    }

    // MARK: Helpers

    private func apply(_ mover: ParkMover, to entity: Entity) {
        // Up and over the bridge; level ground everywhere else.
        entity.position = mover.position + [0, ParkScenery.height(atX: mover.position.x, z: mover.position.z), 0]
        entity.orientation = simd_quatf(angle: mover.heading, axis: [0, 1, 0])
    }

    /// A velocity that heads for `target` and slows down on arrival instead
    /// of overshooting and turning round.
    private func arrive(_ from: SIMD3<Float>, at target: SIMD3<Float>, top: Float, slack: Float) -> SIMD3<Float> {
        var gap = target - from
        gap.y = 0
        let distance = simd_length(gap)
        if distance < slack { return .zero }
        return gap / distance * min(top, (distance - slack) * 3.5)
    }

    private func separate(_ mover: inout ParkMover, from other: SIMD3<Float>, by limit: Float) {
        var away = mover.position - other
        away.y = 0
        let gap = simd_length(away)
        if gap < limit && gap > 0.0001 {
            mover.position = other + away / gap * limit
        }
    }
}

// MARK: - Moving things about

/// Where someone is, how fast they are going and which way they face. The
/// same rules for all three, so you, your partner and Ziggy all set off,
/// stop and turn the same way.
private struct ParkMover {

    var position: SIMD3<Float>
    var velocity: SIMD3<Float> = .zero

    /// Angle about Y. Every model faces +Z, so 0 faces the starting camera
    /// and pi faces into the park.
    var heading: Float

    var speed: Float { simd_length(SIMD2(velocity.x, velocity.z)) }

    mutating func ease(toward wanted: SIMD3<Float>, rate: Float, dt: Float) {
        velocity += (wanted - velocity) * min(1, dt * rate)
        position += velocity * dt
    }

    /// Turns to face the way they are going. False when standing still, so
    /// the caller can decide what they look at instead.
    @discardableResult
    mutating func faceTravel(dt: Float) -> Bool {
        guard speed > 0.08 else { return false }
        turn(toward: atan2(velocity.x, velocity.z), rate: 10, dt: dt)
        return true
    }

    /// Turns the short way round.
    mutating func turn(toward angle: Float, rate: Float, dt: Float) {
        var change = angle - heading
        while change > .pi { change -= 2 * .pi }
        while change < -.pi { change += 2 * .pi }
        heading += change * min(1, dt * rate)
    }
}

// MARK: - The screen

@available(iOS 18.0, *)
struct ZiggyParkView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var world: ZiggyParkWorld
    @State private var company: ZiggyParkWorld.Company = .solo
    @State private var pinchStart: Float?
    @State private var areaBanner: String?
    @State private var surpriseToast: ParkSurprise?
    @State private var toast: String?
    @State private var nearbyFriend: ParkFriend?
    @State private var nearbyNote: ParkNote?
    @State private var openNote: ParkNote?
    @State private var compass: (name: String, metres: Int, bearing: Double, count: Int)?
    @State private var writing = false
    @State private var draft = ""
    @State private var autoWalk = false
    @State private var choosing = true
    @State private var picked: ParkLook = .casual
    @State private var loadProgress: Float = 0
    @State private var loaded = false

    private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)

    init(world: ZiggyParkWorld = ZiggyParkWorld()) {
        _world = State(initialValue: world)
    }

    var body: some View {
        ZStack {
            RealityView { content in
                world.onCompanyChange = { next in company = next }
                world.onAreaChange = { name in
                    withAnimation(.easeOut(duration: 0.4)) { areaBanner = name }
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        if areaBanner == name { withAnimation(.easeIn(duration: 0.6)) { areaBanner = nil } }
                    }
                }
                world.onSurprise = { surprise in
                    withAnimation(.spring(duration: 0.4, bounce: 0.4)) { surpriseToast = surprise }
                    Task {
                        try? await Task.sleep(for: .seconds(2.6))
                        if surpriseToast == surprise { withAnimation(.easeIn(duration: 0.4)) { surpriseToast = nil } }
                    }
                }
                world.onNearbyFriend = { friend in
                    withAnimation(.spring(duration: 0.35, bounce: 0.35)) { nearbyFriend = friend }
                }
                world.onGreet = { friend in show(friend.fact) }
                world.onNearbyNote = { note in
                    withAnimation(.spring(duration: 0.35, bounce: 0.35)) { nearbyNote = note }
                }
                world.onNoteCompass = { next in
                    withAnimation(.easeOut(duration: 0.25)) { compass = next }
                }
                world.onNoteFound = {
                    show("\(partnerName ?? "Your partner") found your note!")
                }
                await world.build(into: &content) { fraction in loadProgress = fraction }
                picked = world.picked
                withAnimation(.easeInOut(duration: 0.6)) { loaded = true }
            }
            .ignoresSafeArea()
            .onDisappear { world.leave() }
            .onChange(of: autoWalk) { _, on in world.autoWalk = on }

            // The thumb pad at the bottom walks; anywhere else looks around.
            ParkTouchPad(
                onStick: { world.input = $0 },
                onLook: { world.orbit(by: $0) },
                onPinch: { pinch in
                    guard let pinch else { pinchStart = nil; return }
                    let start = pinchStart ?? world.zoomDistance
                    pinchStart = start
                    world.zoom(to: start / Float(pinch))
                },
                autoWalk: $autoWalk
            )
            .ignoresSafeArea()
            .opacity(choosing ? 0 : 1)
            .allowsHitTesting(!choosing)

            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    roundButton("xmark") { dismiss() }
                    Spacer()
                    companyChip
                        .padding(.top, 8)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        ParkEmoteMenu(look: picked) { world.emote($0) }
                            .zIndex(2)
                        ParkTrickMenu { world.perform($0) }
                            .zIndex(1)
                        if company != .solo {
                            ParkVoicePanel(voice: world.voice, partnerName: partnerName)
                        }
                    }
                }

                Spacer()
                    .allowsHitTesting(false)

                HStack(alignment: .bottom) {
                    if company != .solo {
                        ParkLeaveNoteButton {
                            draft = ""
                            writing = true
                        }
                    }
                    Spacer()
                    ParkSurpriseButton { world.surprise() }
                }
                .padding(.bottom, 52)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .opacity(choosing ? 0 : 1)
            .allowsHitTesting(!choosing)

            if choosing && loaded {
                ParkChooseCard(picked: picked) { look in
                    withAnimation(.spring(duration: 0.3)) { picked = look }
                    world.pick(look)
                } go: {
                    world.startWalking()
                    withAnimation(.easeInOut(duration: 0.45)) { choosing = false }
                }
                .transition(.opacity)
            }

            if choosing && loaded {
                VStack {
                    HStack {
                        roundButton("xmark") { dismiss() }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            // The way to a note, names, surprises and little messages, just
            // under the top bar and clear of the buttons down the right.
            VStack(spacing: 8) {
                if let compass {
                    ParkNoteCompass(name: compass.name.isEmpty ? (partnerName ?? "your love") : compass.name,
                                    metres: compass.metres, bearing: compass.bearing, count: compass.count)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                if let areaBanner {
                    Text(areaBanner)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                if let toast {
                    Text(toast)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(pink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.94), in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                        .padding(.horizontal, 70)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                if let surpriseToast {
                    Label(surpriseToast.title, systemImage: surpriseToast.symbol)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(pink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.94), in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 62)
            .allowsHitTesting(false)

            // Opening a note, or saying hello to an animal, just above the
            // thumb pad. A note always comes first.
            if openNote == nil {
                VStack {
                    Spacer()
                    if let nearbyNote {
                        ParkOpenNoteButton(name: nearbyNote.name.isEmpty ? (partnerName ?? "your love") : nearbyNote.name) {
                            if let note = world.openNearbyNote() {
                                withAnimation(.spring(duration: 0.4)) { openNote = note }
                            }
                        }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else if let nearbyFriend {
                        ParkPetButton(friend: nearbyFriend) { world.greetNearby() }
                            .id(nearbyFriend)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 210)
            }

            if let openNote {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeIn(duration: 0.25)) { self.openNote = nil } }
                    .transition(.opacity)
                ParkNoteCard(note: openNote) { withAnimation(.easeIn(duration: 0.25)) { self.openNote = nil } }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            if !loaded {
                ParkLoadingCover(progress: loadProgress)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .alert("Leave a note here", isPresented: $writing) {
            TextField("Something sweet…", text: $draft)
            Button("Leave it") {
                let text = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
                guard !text.isEmpty else { return }
                world.leaveNote(text)
                show("Hidden! \(partnerName ?? "Your partner") will find it on their walk")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will float right here until \(partnerName ?? "your partner") walks by and finds it.")
        }
    }

    private func show(_ text: String) {
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if toast == text { withAnimation(.easeIn(duration: 0.4)) { toast = nil } }
        }
    }

    private var partnerName: String? {
        if case .together(let name) = company { return name }
        return nil
    }

    /// Small, so the world stays the thing you look at.
    private var companyChip: some View {
        let (symbol, text): (String, String) = {
            switch company {
            case .solo: return ("pawprint.fill", "Walking with Ziggy")
            case .waiting: return ("hourglass", "Waiting for your partner")
            case .together(let name): return ("heart.fill", name.isEmpty ? "Walking together" : "\(name) is here")
            }
        }()
        return Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.93, green: 0.36, blue: 0.53))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.85), in: Capsule())
            .animation(.easeInOut, value: company)
            .allowsHitTesting(false)
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.22), in: Circle())
        }
    }
}

// MARK: - Loading

/// Shown while the world is built: Ziggy bouncing on a sunset background,
/// and a bar that fills as each part of the garden and town is finished.
private struct ParkLoadingCover: View {

    let progress: Float
    @State private var hop = false
    private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.55, green: 0.56, blue: 0.86), Color(red: 0.98, green: 0.72, blue: 0.78),
                                    Color(red: 1.0, green: 0.86, blue: 0.70)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Image("ziggy_happie")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .offset(y: hop ? -18 : 0)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: hop ? 24 : 10)
                    .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: hop)

                Text("Getting the garden ready…")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.45))
                    Capsule()
                        .fill(pink)
                        .frame(width: 220 * CGFloat(max(0.04, progress)))
                        .animation(.easeOut(duration: 0.25), value: progress)
                }
                .frame(width: 220, height: 10)

                Spacer()
                Text("Lanterns, cherry blossom and a very excited puppy")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 36)
            }
        }
        .onAppear { hop = true }
    }
}

#Preview {
    if #available(iOS 18.0, *) {
        ZiggyParkView()
    }
}
