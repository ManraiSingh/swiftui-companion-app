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

    var body: some View {

        ZStack {

            scenery

            VStack(spacing: 0) {

                header

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

                ZStack {

                    SkyBackdrop(
                        sky: Sky.at(time / 46),
                        scroll: CGFloat(time * 42),
                        groundY: groundY
                    )

                    Image("z1")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 148, height: 148)
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
                        .position(
                            x: geometry.size.width * 0.5,
                            y: groundY - (0.856 - 0.5) * 148
                                + CGFloat(sin(time * 1.9)) * 2.6
                        )

                    Text("Ziggy Jump")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                        .position(
                            x: geometry.size.width * 0.5,
                            y: groundY - 196
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
