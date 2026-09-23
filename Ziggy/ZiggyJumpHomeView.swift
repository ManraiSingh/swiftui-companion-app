//
//  ZiggyJumpHomeView.swift
//  Ziggy
//
//  The front door to Ziggy Jump.
//
//  It grew big enough to need one. Solo and race want different things from
//  the same screen — one wants your best score, the other wants a lobby and a
//  partner — and putting both behind a single tap meant guessing which you
//  came for.
//
//  The screen stands on the game's own scenery rather than a flat colour: the
//  same sky, the same drifting hills, the same platform, with Ziggy sitting on
//  it waiting. Walking in should feel like arriving somewhere, not like
//  opening a menu. The light turns slowly while you decide.
//

import SwiftUI

struct ZiggyJumpHomeView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    /// False when this is a tab rather than something presented over the top
    /// of another screen — there is nothing to close your way out of.
    var showsClose = true

    @State private var showSolo = false
    @State private var showRace = false
    @State private var best = UserDefaults.standard.integer(forKey: "ziggyJumpBest")

    /// Where the platform sits. High enough that the two cards land on the
    /// dark ground below it rather than floating in the sky.
    private let groundFraction: CGFloat = 0.63

    /// Which drawing of Ziggy belongs to this instant.
    ///
    /// The same four-frame jump the game plays — launch, rising, hanging,
    /// falling — picked off velocity rather than off a timer. Holding one
    /// pose for the whole arc is what made the first version of this look
    /// like a cardboard cut-out being lifted on a string.
    private static func frame(
        airborne: Bool,
        airTime: Double,
        velocity: CGFloat,
        scroll: CGFloat
    ) -> String {

        guard airborne else {
            return trot[Int(scroll / 28) % trot.count]
        }

        if airTime < 0.05 { return "z4" }
        if velocity > 240 { return "z5" }
        if velocity > -240 { return "z6" }
        return "z7"
    }

    /// The three frames of Ziggy's trot, the same ones the game runs.
    private static let trot = ["z3", "z7", "z2"]

    // The demo runs the game's own numbers rather than an approximation of
    // them, so the arc on this screen is the arc you get when you play.
    private let gravity: CGFloat = 2200
    private let jumpVelocity: CGFloat = 700
    private let runSpeed: CGFloat = 300
    private let spriteSize: CGFloat = 92
    private let crateHeight: CGFloat = 44
    private let crateWidth: CGFloat = 46

    /// How long one jump lasts, straight off the physics: up and back down
    /// again is `2v/g`. A shade over six tenths of a second.
    private var airTime: Double { Double(2 * jumpVelocity / gravity) }

    var body: some View {

        ZStack {

            scenery

            // The sky moves, so the heading cannot rely on what is behind it
            // — the moon drifts straight through the lettering otherwise.
            // A wash at the top gives the title and the close button their
            // own ground without putting a bar across the picture.
            LinearGradient(
                colors: [.black.opacity(0.45), .black.opacity(0.14), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {

                header

                // A heading, not a label floating in the scene.
                //
                // It used to be drawn inside the scenery, which meant Ziggy
                // climbed through it every time he jumped. Up here it sits
                // above the action by construction, and the run below has the
                // whole middle of the screen to itself.
                VStack(spacing: 3) {

                    Text("Ziggy Jump")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.38), radius: 14, y: 6)

                    Text("Run. Jump. Don't stop.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                }
                .padding(.top, 4)

                Spacer(minLength: 0)

                VStack(spacing: 11) {

                    card(
                        badge: "1P",
                        title: "Single player",
                        detail: best > 0
                            ? "Endless run. Your best is \(best)."
                            : "Endless run. See how far you get.",
                        accent: Color(red: 0.99, green: 0.74, blue: 0.40)
                    ) {
                        showSolo = true
                    }

                    card(
                        badge: "2P",
                        title: "Race your partner",
                        detail: "One course, two phones. First to the flag.",
                        accent: Color(red: 0.62, green: 0.82, blue: 1.00)
                    ) {
                        showRace = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, showsClose ? 42 : 18)
            }
        }
        .fullScreenCover(isPresented: $showSolo) {
            ZiggyJumpGameView(petVM: petVM)
        }
        .fullScreenCover(isPresented: $showRace) {
            ZiggyJumpRaceView(petVM: petVM)
        }
        .onChange(of: showSolo) { _, isShowing in
            // The solo screen owns the record, so pick it up again on the way
            // out rather than leaving the card quoting a stale number.
            if !isShowing {
                best = UserDefaults.standard.integer(forKey: "ziggyJumpBest")
            }
        }
    }

    // MARK: Scenery

    /// The live world behind the menu.
    ///
    /// `TimelineView(.animation)` rather than a display link: this screen has
    /// no simulation to run, it only needs a clock to read the drift and the
    /// light off, and SwiftUI stops it on its own when the view goes away.
    private var scenery: some View {

        GeometryReader { geometry in

            let groundY = geometry.size.height * groundFraction

            TimelineView(.animation) { timeline in

                let time = timeline.date.timeIntervalSinceReferenceDate

                // One crate every `cycle` seconds, and a jump timed so the
                // top of the arc lands over it. Everything is read off the
                // clock rather than stepped, so there is no state to keep and
                // nothing to reset — the loop is wherever the second says.
                let spacing: CGFloat = 520
                let cycle = Double(spacing / runSpeed)
                let phase = time.truncatingRemainder(dividingBy: cycle) / cycle

                let ziggyX = geometry.size.width * 0.38
                let entryX = geometry.size.width + 70
                let crateX = entryX - CGFloat(phase) * spacing

                // When the crate arrives, and therefore when to be highest.
                let meets = Double((entryX - ziggyX) / spacing)
                let half = airTime / cycle / 2
                let leaves = meets - half
                let lands = meets + half

                let airborne = phase > leaves && phase < lands
                let t = airborne ? (phase - leaves) * cycle : 0

                // The real parabola, not a sine: it leaves fast, hangs at the
                // top and drops away. That difference is the whole reason a
                // jump reads as weight rather than as a bounce.
                let lift = airborne
                    ? jumpVelocity * CGFloat(t) - 0.5 * gravity * CGFloat(t * t)
                    : 0
                let velocity = airborne
                    ? jumpVelocity - gravity * CGFloat(t)
                    : 0

                ZStack {

                    SkyBackdrop(
                        sky: Sky.at(time / 46),
                        scroll: CGFloat(time) * runSpeed,
                        groundY: groundY
                    )

                    CrateView(height: crateHeight)
                        .frame(width: crateWidth, height: crateHeight)
                        .position(x: crateX, y: groundY - crateHeight / 2)

                    Image(Self.frame(
                        airborne: airborne,
                        airTime: t,
                        velocity: velocity,
                        scroll: CGFloat(time) * runSpeed
                    ))
                        .resizable()
                        .scaledToFit()
                        .frame(width: spriteSize, height: spriteSize)
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
                        .position(
                            x: ziggyX,
                            y: groundY - (0.856 - 0.5) * spriteSize - lift
                        )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Furniture

    private var header: some View {

        HStack {

            if showsClose {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.32), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                }
            }

            Spacer()
        }
        .frame(height: 40)
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func card(
        badge: String,
        title: String,
        detail: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 14) {

                Text(badge)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.16))
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.72)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 3) {

                    Text(title)
                        .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.32))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.46))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZiggyJumpHomeView(petVM: PetViewModel())
}
