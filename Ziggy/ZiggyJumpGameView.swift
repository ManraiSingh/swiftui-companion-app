//
//  ZiggyJumpGameView.swift
//  Ziggy
//
//  Ziggy Jump — the one game in here you play on your own.
//
//  Ziggy trots along his platform while a day passes overhead. Crates come at
//  him. Tap and he hops; tap again while he is still going up and he hops
//  higher. Don't tap and he runs straight into one.
//
//  The rule the whole game rests on: short and middle crates go under a single
//  hop, tall ones flatly do not. Tall crates *must* be double-tapped. But the
//  bigger hop also keeps him airborne far longer, so spending it when it
//  wasn't needed is how you land on the next crate along.
//
//  Note on the double tap: the first tap launches immediately rather than
//  waiting to see whether a second is coming. Waiting would put a quarter of a
//  second of lag on every jump, which in a reaction game costs more than it
//  could ever buy.
//

import Combine
import SwiftUI
import UIKit

// MARK: - Engine

final class ZiggyJumpEngine: NSObject, ObservableObject {

    enum Phase {
        case ready, running, dying, over
        /// Race only: three, two, one. Both phones flip to racing from their
        /// own listener, milliseconds apart, and without this one player was
        /// already running while the other's screen was still appearing.
        case counting
        /// Race only: clipped a crate, frozen a moment before carrying on.
        case stumbling
        /// Race only: over the finish line.
        case finished
    }

    /// Solo and race share every bit of the physics and the animation. What
    /// differs is where the crates come from, what a hit costs you, and
    /// whether there is an end.
    enum Mode {
        case solo
        /// A course both phones built from the same seed.
        case race(RaceLevel)
    }

    enum Kind: CaseIterable { case short, middle, tall }

    struct Crate: Identifiable {
        let id = UUID()
        var x: CGFloat
        let width: CGFloat
        let height: CGFloat
        /// Only the last crate of an obstacle scores, so a cluster of three
        /// is worth one point rather than three.
        let counts: Bool
        var scored = false
    }

    // Tuned against the arithmetic rather than by feel. The number that
    // matters is how long Ziggy spends above a crate compared with how long
    // that crate takes to cross his hitbox — the difference is the window the
    // player actually has.
    //
    // An early pass had a 72ms window, which is not a game, it is a coin toss.
    enum Tuning {
        static let gravity: CGFloat = 2200
        static let jump: CGFloat = 700
        /// Added mid-rise by the second tap.
        static let boost: CGFloat = 300

        /// A single hop peaks at about 111pt. Short and middle sit under
        /// that; tall is deliberately above it.
        static let shortCrate: CGFloat = 44
        static let middleCrate: CGFloat = 60
        static let tallCrate: CGFloat = 120
        static let crateWidth: CGFloat = 42

        /// How much of the clearing window is kept back as the player's
        /// margin for error. Obstacles are built so they are comfortably
        /// clearable, not merely possible — without this, a cluster that
        /// technically fits leaves about 30ms to react, which is a coin toss.
        static let reactionMargin: CGFloat = 0.15

        static let startSpeed: CGFloat = 300
        /// Speed is the real difficulty lever. Because gaps are quoted in
        /// seconds, going faster doesn't crowd crates together — it shortens
        /// how long one is on screen before it reaches you.
        static let maxSpeed: CGFloat = 760

        static let spriteH: CGFloat = 86
        /// Baked into the art by the normaliser: where Ziggy's feet sit on
        /// his square canvas in the grounded poses.
        static let feetFraction: CGFloat = 0.856
        /// Well inside his outline. He is drawn side-on and is wider than he
        /// is tall mid-stretch, so a hitbox matching the art would kill you
        /// for a nose or a tail brushing a crate.
        static let hitHalfWidth: CGFloat = 20
        static let groundFraction: CGFloat = 0.79

        /// Points in one full morning-to-morning cycle.
        ///
        /// Counted in score rather than seconds, so the light is something
        /// you earn rather than something that happens to you: every run
        /// opens at dawn, and seeing dusk means you got there. Midday falls
        /// at roughly 50 points, dusk near 90, night around 128.
        static let dayLength: Double = 160
    }

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var score = 0
    @Published private(set) var best = 0
    @Published private(set) var isNewBest = false

    /// Points above the platform. Zero means standing on it.
    @Published private(set) var height: CGFloat = 0
    @Published private(set) var crates: [Crate] = []
    /// Total distance travelled — drives parallax, the trot and the sky.
    @Published private(set) var scroll: CGFloat = 0
    @Published private(set) var spin: Double = 0

    /// Seconds since he left the ground, and since he last touched it. The
    /// animation reads both: the push-off plays on a clock, everything after
    /// it follows the physics.
    @Published private(set) var airTime: CGFloat = 0
    @Published private(set) var groundTime: CGFloat = 0

    /// Always advancing, unlike `scroll`, which is still before the first tap.
    @Published private(set) var clock: CGFloat = 0

    // MARK: Race state

    private(set) var mode: Mode = .solo

    /// How far down the course this player has come. Solo has no such thing
    /// — there is no end to be a fraction of.
    @Published private(set) var distance: CGFloat = 0

    /// Ticks down while he is picking himself up after a clip.
    @Published private(set) var stumbleRemaining: CGFloat = 0

    /// Seconds left on the start countdown.
    @Published private(set) var countdown: CGFloat = 0

    /// He passes through crates until this runs out, so the one that just
    /// caught him cannot catch him again the instant he starts moving.
    @Published private(set) var mercyRemaining: CGFloat = 0

    /// Where the other player has got to. Purely something to look at — the
    /// two racers never collide.
    @Published private(set) var ghostDistance: CGFloat = 0

    private var ghostTarget: CGFloat = 0

    /// Seconds since the last report landed, so the correction can allow for
    /// how out of date it already is.
    private var ghostAge: CGFloat = 0

    /// Takes a position report from the other phone. See `moveGhost`, which
    /// is where the smoothing actually happens.
    func reportGhost(_ reported: CGFloat) {
        // The very first one snaps: easing in from zero would send the ghost
        // sprinting up the course from the start line.
        if ghostTarget == 0 { ghostDistance = reported }
        ghostTarget = reported
        ghostAge = 0
    }

    private var nextCrateIndex = 0

    var raceLevel: RaceLevel? {
        if case let .race(level) = mode { return level }
        return nil
    }

    var isRacing: Bool { raceLevel != nil }

    var raceProgress: Double {
        guard let level = raceLevel, level.length > 0 else { return 0 }
        return min(1, Double(distance / level.length))
    }

    var ghostProgress: Double {
        guard let level = raceLevel, level.length > 0 else { return 0 }
        return min(1, Double(ghostDistance / level.length))
    }

    private(set) var velocity: CGFloat = 0
    private(set) var speed = Tuning.startSpeed
    private var boostUsed = false
    private var untilNextCrate: CGFloat = 0
    private var size: CGSize = .zero
    private var recent: [Kind] = []

    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval = 0

    private static let bestKey = "ziggyJumpBest"

    override init() {
        super.init()
        best = UserDefaults.standard.integer(forKey: Self.bestKey)
    }

    // MARK: Geometry

    func configure(_ newSize: CGSize) {
        guard newSize.width > 0 else { return }
        size = newSize
    }

    var groundY: CGFloat { size.height * Tuning.groundFraction }
    var ziggyX: CGFloat { size.width * 0.26 }
    var screenWidth: CGFloat { size.width }
    var dayProgress: Double {
        // In a race the light doubles as a progress bar you can feel: dawn at
        // the gun, dusk at the finish, whoever wins.
        if isRacing { return raceProgress * 0.55 }
        return Double(score) / Tuning.dayLength
    }

    // MARK: Driving

    func begin() {
        guard link == nil else { return }
        let display = CADisplayLink(target: self, selector: #selector(step(_:)))
        display.add(to: .main, forMode: .common)
        link = display
        lastTick = CACurrentMediaTime()
    }

    func end() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ sender: CADisplayLink) {
        // Clamped, so returning from a stall doesn't sweep a crate straight
        // through him before anyone could react.
        let delta = min(CGFloat(sender.timestamp - lastTick), 1.0 / 20)
        lastTick = sender.timestamp
        guard delta > 0 else { return }
        tick(delta)
    }

    private func tick(_ delta: CGFloat) {

        clock += delta
        if mercyRemaining > 0 { mercyRemaining = max(0, mercyRemaining - delta) }

        if isRacing { moveGhost(delta) }

        switch phase {

        case .ready:
            // Held still until the first tap. The floor used to keep moving
            // here, but with Ziggy sitting on it he looked dragged along
            // rather than waiting.
            break

        case .running:
            scroll += speed * delta
            distance += speed * delta
            advanceCrates(delta)
            applyGravity(delta)
            if isRacing { feedFromCourse() } else { spawnIfDue(delta) }
            checkCollision()
            if let level = raceLevel, distance >= level.length { cross() }

        case .counting:
            countdown -= delta
            if countdown <= 0 {
                countdown = 0
                phase = .running
            }

        case .stumbling:
            // The world holds still while he picks himself up. That pause is
            // the whole cost of a hit in a race — time lost, not the run.
            stumbleRemaining -= delta
            if stumbleRemaining <= 0 {
                stumbleRemaining = 0
                phase = .running
            }

        case .dying:
            applyGravity(delta)
            spin += Double(delta) * 260
            if height < -size.height { finish() }

        case .over, .finished:
            break
        }
    }

    /// Hands crates to the live list as they come into view.
    ///
    /// Read off the course rather than rolled, which is exactly what keeps the
    /// two phones showing the same thing: `distance` is the only input, and it
    /// advances at a fixed speed on both sides.
    private func feedFromCourse() {

        guard let level = raceLevel, size.width > 0 else { return }

        while nextCrateIndex < level.crates.count {
            let next = level.crates[nextCrateIndex]
            let screenX = ziggyX + (next.x - distance)
            guard screenX < size.width + 90 else { break }
            crates.append(Crate(
                x: screenX, width: next.width, height: next.height, counts: true
            ))
            nextCrateIndex += 1
        }
    }

    /// Predict, then correct — rather than chase.
    ///
    /// Reports arrive a few times a second and are already several hundred
    /// milliseconds old by the time Firestore delivers them. Easing straight
    /// toward one means the ghost coasts to a near-stop between updates and
    /// then lurches when the next lands, which is exactly what made the race
    /// look broken.
    ///
    /// But both racers are on the same course at the same fixed speed, so
    /// where the other one is between reports isn't a mystery — it's simple
    /// arithmetic. So the ghost runs forward on its own, and each report is
    /// compared against where it *implies* they are now, allowing for how
    /// stale it is. The correction then only has to absorb the difference a
    /// stumble makes, which is gentle enough not to show.
    /// Simulated against realistic report gaps and latency, this cut the
    /// average lag from about 255pt to 140pt and the worst frame-to-frame
    /// jolt from ~1200pt/s² to ~220 — the stutter, gone.
    ///
    /// `ghostAge` counts only from when a report *arrived*, deliberately not
    /// including a guess at how long it spent in transit. Crediting it with
    /// an assumed 250ms more than halves the average error on paper, but when
    /// the real latency is lower than the guess the ghost runs up to 310pt
    /// *ahead* of where they are — so during their stumble you would watch
    /// them sail past you and then snap back. Being honestly a little behind
    /// beats being confidently wrong.
    private func moveGhost(_ delta: CGFloat) {

        ghostAge += delta
        ghostDistance += speed * delta

        let implied = ghostTarget + speed * ghostAge
        ghostDistance += (implied - ghostDistance) * min(1, delta * 1.5)
    }

    private func cross() {
        guard phase != .finished else { return }
        phase = .finished
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Begins a race on a course both phones have built from one seed.
    func startRace(_ level: RaceLevel) {
        mode = .race(level)
        speed = RaceLevel.speed
        distance = 0
        ghostDistance = 0
        nextCrateIndex = 0
        crates = []
        score = 0
        height = 0
        velocity = 0
        spin = 0
        scroll = 0
        stumbleRemaining = 0
        mercyRemaining = 0
        ghostTarget = 0
        ghostAge = 0
        isNewBest = false
        countdown = 3.2
        phase = .counting
    }

    private func applyGravity(_ delta: CGFloat) {

        if height > 0 { airTime += delta } else { groundTime += delta }

        guard height > 0 || velocity != 0 else { return }

        let wasAirborne = height > 0
        velocity -= Tuning.gravity * delta
        height += velocity * delta

        if phase != .dying, height <= 0 {
            height = 0
            velocity = 0
            boostUsed = false
            if wasAirborne { groundTime = 0 }
        }
    }

    private func advanceCrates(_ delta: CGFloat) {

        for index in crates.indices {
            crates[index].x -= speed * delta

            guard crates[index].counts, !crates[index].scored else { continue }
            if crates[index].x + crates[index].width < ziggyX - Tuning.hitHalfWidth {
                crates[index].scored = true
                score += 1
                // Held flat in a race: two people running at different speeds
                // down one course makes a nonsense of the finish line.
                if !isRacing {
                    speed = min(Tuning.maxSpeed, Tuning.startSpeed + CGFloat(score) * 8)
                }
            }
        }
        crates.removeAll { $0.x + $0.width < -120 }
    }

    // MARK: Obstacles

    /// The widest obstacle a single hop can actually clear right now.
    ///
    /// Straight out of the jump equation: solve for the two times at which he
    /// is level with the crate top, and multiply the gap between them by the
    /// speed. Everything the generator builds is measured against this, so a
    /// cluster can never be wider than he can get over — the run gets harder
    /// because it gets faster, never because it got unfair.
    private func clearable(over crateHeight: CGFloat) -> CGFloat {
        let discriminant = Tuning.jump * Tuning.jump - 2 * Tuning.gravity * crateHeight
        guard discriminant > 0 else { return 0 }
        let secondsAbove = 2 * sqrt(discriminant) / Tuning.gravity
        // The margin is held back in seconds, not points, so the window stays
        // the same length however fast the run has got.
        return (secondsAbove - Tuning.reactionMargin) * speed - 2 * Tuning.hitHalfWidth
    }

    /// Weighted by score, then filtered so the same kind can't come three
    /// times running.
    ///
    /// Genuine randomness produces long identical runs, and a player reads
    /// those as a pattern. Refusing the third repeat is what makes it *feel*
    /// random, which is the thing actually being asked for.
    private func pickKind() -> Kind {

        var pool: [Kind] = [.short, .short, .short]
        if score >= 3 { pool += [.middle, .middle] }
        if score >= 6 { pool += [.tall, .tall] }
        if score >= 18 { pool += [.tall, .middle] }

        let stuck = recent.count >= 2 && recent[0] == recent[1]
        let choices = stuck ? pool.filter { $0 != recent[0] } : pool

        return (choices.isEmpty ? pool : choices).randomElement() ?? .short
    }

    private func spawnIfDue(_ delta: CGFloat) {

        untilNextCrate -= speed * delta
        guard untilNextCrate <= 0, size.width > 0 else { return }

        let kind = pickKind()
        recent.append(kind)
        if recent.count > 2 { recent.removeFirst() }

        var x = size.width + 70

        switch kind {

        case .short:
            // Clusters are what stop it feeling like the same obstacle over
            // and over. How many fit is decided by the physics, not a guess.
            let room = Int(clearable(over: Tuning.shortCrate) / Tuning.crateWidth)
            let count = Int.random(in: 1...max(1, min(3, room)))
            for step in 0..<count {
                crates.append(Crate(
                    x: x, width: Tuning.crateWidth,
                    height: Tuning.shortCrate, counts: step == count - 1
                ))
                x += Tuning.crateWidth
            }

        case .middle:
            let room = Int(clearable(over: Tuning.middleCrate) / Tuning.crateWidth)
            let count = room >= 2 && Bool.random() ? 2 : 1
            for step in 0..<count {
                crates.append(Crate(
                    x: x, width: Tuning.crateWidth,
                    height: Tuning.middleCrate, counts: step == count - 1
                ))
                x += Tuning.crateWidth
            }

        case .tall:
            crates.append(Crate(
                x: x, width: Tuning.crateWidth + 4,
                height: Tuning.tallCrate, counts: true
            ))
        }

        // Gaps are quoted in seconds of travel, so they stay proportionate at
        // every speed.
        //
        // The floor of 1.15 is what makes a boosted hop safe. Boosting keeps
        // him airborne 0.91s rather than 0.64s, but he takes off well before
        // the crate, so by the time he lands only about 0.46s of that gap has
        // been spent. 1.15 clears that at every speed in the range with room
        // to spare, without thinning the crates out to nothing.
        untilNextCrate = speed * CGFloat.random(in: 1.15...2.3)
    }

    private func checkCollision() {

        // Still shaking it off — he passes straight through.
        guard mercyRemaining <= 0 else { return }

        let left = ziggyX - Tuning.hitHalfWidth
        let right = ziggyX + Tuning.hitHalfWidth

        for crate in crates {
            let overlaps = crate.x < right && crate.x + crate.width > left
            // Four points of forgiveness: clipping the very top corner should
            // feel like a near miss, not a death.
            guard overlaps, height < crate.height - 4 else { continue }
            if isRacing { stumble() } else { die() }
            return
        }
    }

    /// A clip costs you time, not the run.
    ///
    /// He stops where he stands, blinks, and carries on from that exact spot.
    /// Nobody gets sent back to the start of a race they are halfway down.
    ///
    /// The mercy window deliberately outlasts the freeze, so the crate that
    /// caught him is well behind before he can be caught by it again — the
    /// world is stationary while he is down, so it would otherwise still be
    /// sitting on top of him the moment he stood up.
    private func stumble() {
        phase = .stumbling
        stumbleRemaining = 0.85
        mercyRemaining = 2.3
        height = 0
        velocity = 0
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: Input

    func tap() {

        switch phase {

        case .ready:
            phase = .running
            untilNextCrate = size.width * 0.6
            launch()

        case .running:
            if height <= 0 {
                launch()
            } else if velocity > 0, !boostUsed {
                // The second tap. Only on the way up — once he's falling the
                // jump is spent.
                boostUsed = true
                velocity += Tuning.boost
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }

        case .counting, .stumbling, .dying, .over, .finished:
            break
        }
    }

    private func launch() {
        velocity = Tuning.jump
        boostUsed = false
        airTime = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Ending

    private func die() {
        phase = .dying
        velocity = 420
        spin = 0
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func finish() {
        phase = .over
        isNewBest = score > best
        if isNewBest {
            best = score
            UserDefaults.standard.set(best, forKey: Self.bestKey)
        }
        ZiggyGameCenter.shared.submit(score: score)
    }

    /// Solo only. A race that has finished goes back to its lobby instead,
    /// because the next course has to be agreed with the other phone.
    func retry() {
        mode = .solo
        score = 0
        isNewBest = false
        height = 0
        velocity = 0
        spin = 0
        boostUsed = false
        speed = Tuning.startSpeed
        crates = []
        recent = []
        untilNextCrate = 0
        scroll = 0
        distance = 0
        ghostDistance = 0
        nextCrateIndex = 0
        stumbleRemaining = 0
        mercyRemaining = 0
        phase = .ready
    }
}

// MARK: - Screen

/// Everything the playfield needs in order to be a race rather than a solo run.
///
/// Bundled into one optional so solo play is untouched: `race == nil` and not
/// a line of the single-player path behaves differently.
struct RaceHooks {
    let level: RaceLevel
    let ghostDistance: CGFloat
    let onProgress: (CGFloat) -> Void
    let onFinish: () -> Void
}

struct ZiggyJumpGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    var race: RaceHooks?

    /// Position reports go out on this rather than every frame — sixty writes
    /// a second would be absurd for something nobody can collide with.
    private let reportTimer = Timer
        .publish(every: 0.35, on: .main, in: .common)
        .autoconnect()

    @StateObject private var engine = ZiggyJumpEngine()

    // Observed rather than owned — it is a singleton that outlives the screen.
    @ObservedObject private var gameCenter = ZiggyGameCenter.shared

    @State private var showLeaderboard = false

    private var sky: Sky { Sky.at(engine.dayProgress) }

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                SkyBackdrop(
                    sky: sky,
                    scroll: engine.scroll,
                    groundY: engine.groundY
                )

                finishLine
                crates
                contactShadow
                // Behind the real one, so yours is always the Ziggy on top.
                ghost
                ziggy

                // The whole screen is the button. Everything interactive sits
                // above this, so the close and leaderboard buttons still take
                // their own taps.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { engine.tap() }

                header

                if engine.isRacing { raceBar } else { scoreBadge }

                if !engine.isRacing, engine.phase == .ready { readyCard }
                if !engine.isRacing, engine.phase == .over { overCard }
                if engine.phase == .counting { countdownOverlay }
                if engine.phase == .finished { finishedOverlay }
            }
            .onAppear {
                engine.configure(geometry.size)
                engine.begin()
                gameCenter.authenticate()
                if let race { engine.startRace(race.level) }
            }
            .onChange(of: geometry.size) { _, new in
                engine.configure(new)
            }
            .onChange(of: race?.ghostDistance ?? 0) { _, new in
                engine.reportGhost(new)
            }
            .onChange(of: engine.phase) { _, new in
                if new == .finished { race?.onFinish() }
            }
            .onReceive(reportTimer) { _ in
                guard let race, engine.isRacing else { return }
                race.onProgress(engine.distance)
            }
            .onDisappear { engine.end() }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showLeaderboard) {
            GameCenterLeaderboard(leaderboardID: ZiggyGameCenter.jumpLeaderboardID)
        }
    }

    // MARK: World

    private var crates: some View {
        ForEach(engine.crates) { crate in
            CrateView(height: crate.height)
                .frame(width: crate.width, height: crate.height)
                .position(
                    x: crate.x + crate.width / 2,
                    y: engine.groundY - crate.height / 2
                )
        }
    }

    /// The other racer, drawn through rather than solid.
    ///
    /// Shown at their true position and nowhere else. An earlier version
    /// pinned them to the screen edge once the gap got wide, so you would
    /// always see *something* — but a Ziggy stuck to the bezel, not reacting
    /// to the crates going past underneath, just looks broken. They fade out
    /// as they approach the edge and are gone beyond it. The bar at the top
    /// is what carries the gap when they are out of sight.
    @ViewBuilder
    private var ghost: some View {

        if engine.isRacing, engine.screenWidth > 0 {

            let x = engine.ziggyX + (engine.ghostDistance - engine.distance)
            let margin: CGFloat = 70

            if x > -margin, x < engine.screenWidth + margin {

                // Full strength through the middle, fading over the last
                // stretch at either side so they leave rather than vanish.
                let edge = min(x + margin, engine.screenWidth + margin - x)
                let fade = min(1, max(0, edge / 120))

                Image(Self.trot[Int(max(0, engine.ghostDistance) / 28) % Self.trot.count])
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: ZiggyJumpEngine.Tuning.spriteH,
                        height: ZiggyJumpEngine.Tuning.spriteH
                    )
                    .opacity(0.42 * fade)
                    .position(x: x, y: groundedCentreY)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Where the sprite's centre goes when his feet are on the floor.
    private var groundedCentreY: CGFloat {
        engine.groundY
            - (ZiggyJumpEngine.Tuning.feetFraction - 0.5) * ZiggyJumpEngine.Tuning.spriteH
    }

    @ViewBuilder
    private var finishLine: some View {

        if let level = engine.raceLevel {

            let x = engine.ziggyX + (level.length - engine.distance)

            if x > -80, x < engine.screenWidth + 80 {
                FinishBanner()
                    .frame(width: 46, height: 200)
                    .position(x: x, y: engine.groundY - 100)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Pins him to the floor, and does the job the glow can't in daylight.
    ///
    /// At midday he is a white dog against a pale sky, and the night glow is
    /// invisible — a shadow underneath is what keeps him from floating off
    /// the background. It shrinks and fades as he climbs.
    private var contactShadow: some View {

        let lift = min(1, engine.height / 130)

        return Ellipse()
            .fill(.black.opacity(0.24 * (1 - lift * 0.75)))
            .frame(width: 52 * (1 - lift * 0.4), height: 10 * (1 - lift * 0.4))
            .position(x: engine.ziggyX, y: engine.groundY + 5)
            .opacity(engine.phase == .dying ? 0 : 1)
            .allowsHitTesting(false)
    }

    private var ziggy: some View {

        Image(spriteName)
            .resizable()
            .scaledToFit()
            // Square canvas, so this fits exactly and no frame is nudged
            // sideways by letterboxing — which is what makes a sprite
            // sequence shimmer.
            .frame(
                width: ZiggyJumpEngine.Tuning.spriteH,
                height: ZiggyJumpEngine.Tuning.spriteH
            )
            .scaleEffect(x: 1 + squash * 0.09, y: 1 - squash * 0.11, anchor: .bottom)
            // Only worth having after dark, and it fades out with the night.
            .shadow(
                color: sky.orb.color.opacity(0.30 * sky.night),
                radius: 14
            )
            .opacity(blink)
            .rotationEffect(.degrees(engine.spin))
            .position(x: engine.ziggyX, y: spriteCentreY - idleBob)
            .animation(nil, value: engine.height)
    }

    /// Mario's trick. The flicker is both the feedback that you were clipped
    /// and the warning that the protection is about to run out.
    private var blink: Double {
        guard engine.mercyRemaining > 0 else { return 1 }
        return sin(Double(engine.clock) * 26) > 0 ? 0.28 : 1
    }

    private var spriteCentreY: CGFloat {
        let feet = engine.groundY - engine.height
        return feet - (ZiggyJumpEngine.Tuning.feetFraction - 0.5)
            * ZiggyJumpEngine.Tuning.spriteH
    }

    /// The pose, picked from the physics rather than from a loop.
    ///
    /// A loop playing at a fixed rate over the top of the movement is exactly
    /// what makes sprite work look pasted on. Here the frame *is* the state,
    /// so the animation and the jump can never drift apart.
    private var spriteName: String {

        if engine.phase == .dying { return "z6" }

        // Down on his front, gathering himself.
        if engine.phase == .stumbling { return "z2" }

        // Stood on the line waiting for the gun.
        if engine.phase == .counting { return "z1" }

        // Waiting to start. z1 is the only real sit in the set, and it only
        // works while the world is still — which is why `.ready` freezes it.
        if engine.phase == .ready { return "z1" }

        if engine.height <= 0 {
            if engine.groundTime < 0.09 { return "z3" }
            return Self.trot[Int(engine.scroll / 28) % Self.trot.count]
        }

        if engine.airTime < 0.05 { return "z4" }

        if engine.velocity > 240 { return "z5" }
        if engine.velocity > -240 { return "z6" }
        return "z7"
    }

    /// Three standing poses with the legs in different places.
    ///
    /// Stepped off distance travelled, not off a timer, so the legs speed up
    /// exactly as the ground does. Run a leg cycle on its own clock and the
    /// feet slide against the floor at speed — the moonwalk you see in cheap
    /// endless runners.
    private static let trot = ["z3", "z7", "z2"]

    /// A little give on contact. Small on purpose — the crouch frame does the
    /// work, this only stops the landing feeling weightless.
    private var squash: CGFloat {
        guard engine.height <= 0, engine.groundTime < 0.12 else { return 0 }
        return 1 - engine.groundTime / 0.12
    }

    /// A breath while he waits. Only on the start screen; once running, the
    /// trot frames supply their own bounce and doing both reads as a wobble.
    private var idleBob: CGFloat {
        guard engine.phase == .ready else { return 0 }
        return sin(engine.clock * 2.1) * 2.0
    }

    // MARK: Furniture

    private var header: some View {

        VStack {
            HStack {

                Button { dismiss() } label: {
                    glyph("xmark", bright: true)
                }

                Spacer()

                Button { showLeaderboard = true } label: {
                    glyph("rosette", bright: gameCenter.isAuthenticated)
                }
                .disabled(!gameCenter.isAuthenticated)
            }
            .padding(.horizontal, 18)
            .padding(.top, 58)

            Spacer()
        }
    }

    private func glyph(_ name: String, bright: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(bright ? 0.95 : 0.35))
            .frame(width: 40, height: 40)
            .background(.black.opacity(0.30), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
    }

    private var scoreBadge: some View {

        VStack {
            HStack(spacing: 9) {

                Text("\(engine.score)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 1, height: 17)

                Text("BEST \(engine.best)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(.black.opacity(0.30), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            .padding(.top, 116)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    /// Both racers on one track.
    ///
    /// Earns its place because the ghost gets clamped to a screen edge once
    /// the gap is bigger than a phone — at that point the only honest read on
    /// who is winning is here.
    private var raceBar: some View {

        VStack {

            VStack(spacing: 7) {

                GeometryReader { bar in

                    let width = bar.size.width

                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(.white.opacity(0.16))
                            .frame(height: 5)

                        Capsule()
                            .fill(.white.opacity(0.85))
                            .frame(width: max(5, width * engine.raceProgress), height: 5)

                        marker(engine.ghostProgress, width, mine: false)
                        marker(engine.raceProgress, width, mine: true)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 14)

                HStack(spacing: 0) {

                    Text("YOU")
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    Text(engine.raceProgress >= engine.ghostProgress ? "AHEAD" : "BEHIND")
                        .foregroundStyle(
                            engine.raceProgress >= engine.ghostProgress
                                ? .white.opacity(0.85)
                                : .white.opacity(0.45)
                        )

                    Spacer()

                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.white.opacity(0.85))
                }
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.black.opacity(0.32), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            .padding(.horizontal, 30)
            .padding(.top, 112)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func marker(_ progress: Double, _ width: CGFloat, mine: Bool) -> some View {
        Circle()
            .fill(mine ? Color.white : Color.white.opacity(0.45))
            .frame(width: mine ? 11 : 9, height: mine ? 11 : 9)
            .overlay(
                Circle().stroke(.black.opacity(mine ? 0.35 : 0), lineWidth: 1.5)
            )
            .offset(x: max(0, min(width - 11, CGFloat(progress) * width - 5.5)))
    }

    private var countdownOverlay: some View {

        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()

            Text(engine.countdown > 1 ? "\(Int(engine.countdown.rounded(.up)) - 1)" : "GO")
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                // Keyed on the whole number so it pops once per count rather
                // than scaling continuously as the timer drains.
                .id(Int(engine.countdown.rounded(.up)))
                .transition(.scale(scale: 1.5).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: Int(engine.countdown.rounded(.up)))
        }
        .allowsHitTesting(false)
    }

    /// Crossing the line used to leave the screen frozen while Firestore was
    /// asked who won, which read as a hang. Now it says what happened.
    private var finishedOverlay: some View {

        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 8) {

                Image("z6")
                    .resizable().scaledToFit()
                    .frame(width: 84, height: 84)

                Text("Finished")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(engine.ghostProgress >= 1
                     ? "Checking who got there first…"
                     : "Waiting for them to cross…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))

                ProgressView()
                    .tint(.white)
                    .padding(.top, 2)
            }
        }
        .allowsHitTesting(false)
    }

    private var readyCard: some View {

        VStack {
            Spacer()

            VStack(spacing: 5) {

                Text("Tap to hop")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Double tap for the tall ones")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .glassCard()
            // Below the platform line. Centred any higher and it sits on top
            // of Ziggy, who runs at 26% across.
            .padding(.bottom, 40)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var overCard: some View {

        ZStack {

            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 13) {

                Image("z7")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)

                VStack(spacing: 2) {

                    Text(engine.isNewBest ? "New best" : "Clipped it")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(engine.score == 1 ? "1 crate" : "\(engine.score) crates")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                }

                HStack(spacing: 10) {
                    tally("SCORE", engine.score)
                    tally("BEST", engine.best)
                }

                VStack(spacing: 8) {

                    Button {
                        engine.retry()
                    } label: {
                        Text("Try again")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 0.16, green: 0.12, blue: 0.10))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(CrateView.face)
                            )
                    }

                    if gameCenter.isAuthenticated {
                        Button {
                            showLeaderboard = true
                        } label: {
                            Text("Leaderboard")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(.white.opacity(0.22), lineWidth: 1.5)
                                )
                        }
                    }
                }
                .padding(.top, 2)
            }
            .glassCard()
            .padding(.horizontal, 48)
        }
        .transition(.opacity)
    }

    private func tally(_ label: String, _ value: Int) -> some View {

        VStack(spacing: 1) {

            Text("\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }
}

// MARK: - Crate

/// Not private: the title screen runs a little demo of the game, and it
/// should be jumping the same crate you will be.
struct CrateView: View {

    /// Warm and constant all day. Everything around it changes colour with
    /// the sky, so the one thing that can kill you is the one thing that
    /// always looks the same.
    static let face = Color(red: 0.99, green: 0.74, blue: 0.40)
    static let deep = Color(red: 0.86, green: 0.47, blue: 0.26)
    static let edge = Color(red: 0.30, green: 0.16, blue: 0.14)

    let height: CGFloat

    var body: some View {

        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Self.face, Self.deep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Self.edge, lineWidth: 2)
            )
            .overlay {
                // Split into crate-sized sections, so a tall one reads as a
                // stack to clear rather than one stretched box.
                let sections = max(1, Int((height / 42).rounded()))
                VStack(spacing: 0) {
                    ForEach(0..<sections, id: \.self) { index in
                        Color.clear
                            .frame(maxHeight: .infinity)
                            .overlay(alignment: .bottom) {
                                if index < sections - 1 {
                                    Rectangle()
                                        .fill(Self.edge.opacity(0.7))
                                        .frame(height: 2)
                                }
                            }
                    }
                }
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(.white.opacity(0.32))
                    .frame(height: 3)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
            }
            .shadow(color: Self.deep.opacity(0.45), radius: 9)
    }
}

// MARK: - Finish line

private struct FinishBanner: View {

    var body: some View {

        VStack(spacing: 0) {

            Canvas { context, size in
                let columns = 4
                let rows = 5
                let cellW = size.width / CGFloat(columns)
                let cellH = size.height / CGFloat(rows)
                for row in 0..<rows {
                    for column in 0..<columns {
                        let dark = (row + column) % 2 == 0
                        context.fill(
                            Path(CGRect(
                                x: CGFloat(column) * cellW, y: CGFloat(row) * cellH,
                                width: cellW + 0.5, height: cellH + 0.5
                            )),
                            with: .color(dark
                                ? Color.black.opacity(0.82)
                                : Color.white.opacity(0.95))
                        )
                    }
                }
            }
            .frame(height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 5)
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }
}

// MARK: - Backdrop

/// Sky, sun or moon, stars, hills and the platform, in one drawing pass.
///
/// It redraws every frame because the hills and floor scroll and the light
/// changes, so this is a single Canvas rather than several dozen views.
///
/// Not private: the menu stands on the same scenery, so that walking into
/// Ziggy Jump feels like arriving somewhere rather than reading a list.
struct SkyBackdrop: View {

    let sky: Sky
    let scroll: CGFloat
    let groundY: CGFloat

    /// Scattered on the golden angle, so the eye never finds a row in them.
    private static let stars: [(CGFloat, CGFloat, CGFloat)] = (0..<70).map { index in
        let a = Double(index) * 2.399963
        return (
            CGFloat(0.5 + 0.49 * sin(a)),
            CGFloat(Double(index) / 70.0),
            CGFloat(index % 5 == 0 ? 1.9 : 1.1)
        )
    }

    var body: some View {

        Canvas { context, size in

            let horizon = groundY

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [sky.top.color, sky.mid.color, sky.low.color]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: horizon)
                )
            )

            // Sun and moon are the same disc in the same place, recoloured —
            // which is what makes the changeover at dusk feel continuous.
            let p = Sky.orbPosition
            let centre = CGPoint(x: p.x * size.width, y: p.y * size.height)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - 68, y: centre.y - 68, width: 136, height: 136)),
                with: .radialGradient(
                    Gradient(colors: [sky.orb.color.opacity(0.26), .clear]),
                    center: centre, startRadius: 6, endRadius: 68
                )
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - 26, y: centre.y - 26, width: 52, height: 52)),
                with: .color(sky.orb.color)
            )

            if sky.night > 0.02 {
                for (fx, fy, r) in Self.stars {
                    let y = fy * horizon * 0.86
                    guard y < horizon - 30 else { continue }
                    let base = r > 1.5 ? 0.85 : 0.45
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: fx * size.width - r, y: y - r,
                            width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(base * sky.night))
                    )
                }
            }

            // Two ridges at different speeds, which is what sells the depth.
            hills(&context, size: size, horizon: horizon,
                  offset: scroll * 0.14, amplitude: 34, step: 190,
                  colour: sky.hillFar.color, drop: 96)

            hills(&context, size: size, horizon: horizon,
                  offset: scroll * 0.32, amplitude: 26, step: 128,
                  colour: sky.hillNear.color, drop: 52)

            // The platform, graded rather than flat so the bottom of the
            // screen has depth instead of reading as a dead band.
            context.fill(
                Path(CGRect(x: 0, y: horizon,
                            width: size.width, height: size.height - horizon)),
                with: .linearGradient(
                    Gradient(colors: [
                        sky.ground.color,
                        RGB.lerp(sky.ground, RGB(r: 0.02, g: 0.02, b: 0.05), 0.55).color
                    ]),
                    startPoint: CGPoint(x: 0, y: horizon),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.fill(
                Path(CGRect(x: 0, y: horizon - 2, width: size.width, height: 3)),
                with: .color(sky.edge.color)
            )

            // Dashes rushing past, so speed is visible even between crates.
            let dash: CGFloat = 26
            let gap: CGFloat = 46
            var x = -(scroll.truncatingRemainder(dividingBy: dash + gap))
            while x < size.width {
                context.fill(
                    Path(CGRect(x: x, y: horizon + 13, width: dash, height: 2)),
                    with: .color(.white.opacity(0.13))
                )
                x += dash + gap
            }
        }
        .ignoresSafeArea()
    }

    private func hills(
        _ context: inout GraphicsContext,
        size: CGSize,
        horizon: CGFloat,
        offset: CGFloat,
        amplitude: CGFloat,
        step: CGFloat,
        colour: Color,
        drop: CGFloat
    ) {
        let baseline = horizon - drop

        func ridge(_ x: CGFloat) -> CGFloat {
            let phase = (x + offset) / step
            return baseline + sin(phase) * amplitude + sin(phase * 0.5) * amplitude * 0.45
        }

        var path = Path()
        path.move(to: CGPoint(x: 0, y: horizon))

        var x: CGFloat = 0
        while x <= size.width {
            path.addLine(to: CGPoint(x: x, y: ridge(x)))
            x += 8
        }

        // The loop steps in 8s and almost never lands exactly on the right
        // edge, so it used to stop a few points short and then cut straight
        // down to the horizon — a notch in the ridge against the bezel.
        // Close on the real height at the edge first.
        path.addLine(to: CGPoint(x: size.width, y: ridge(size.width)))
        path.addLine(to: CGPoint(x: size.width, y: horizon))
        path.closeSubpath()
        context.fill(path, with: .color(colour))
    }
}

// MARK: -

private extension View {

    /// One dark chip for every label on screen.
    ///
    /// The sky runs from noon blue to midnight indigo, so text that flipped
    /// between dark and light would be caught out somewhere in the middle.
    /// A dark scrim with pale type is legible at both ends.
    func glassCard() -> some View {
        padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }
}

#Preview {
    ZiggyJumpGameView(petVM: PetViewModel())
}
