//
//  ZiggyParkTour.swift
//  Ziggy
//
//  The first walk in the park, shown round.
//
//  The first time you set off, the park dims and each control lights up in
//  turn with a little bubble saying what it does: the pad you walk with,
//  looking around, your moves, playing with Ziggy, talking and leaving notes
//  when your partner is about, and Surprise me. Tap anywhere or Next to go
//  on; Skip ends it. Once it has been seen it never comes back.
//
//  Each control marks itself with `.parkTip(_:)`, so the spotlight finds it
//  wherever it ends up on screen.
//

import SwiftUI

/// A control the tour points at.
enum ParkTip: Hashable {
    case stick, emotes, tricks, voice, note, surprise
}

struct ParkTipAnchors: PreferenceKey {
    static let defaultValue: [ParkTip: Anchor<CGRect>] = [:]
    static func reduce(value: inout [ParkTip: Anchor<CGRect>], nextValue: () -> [ParkTip: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks this control for the tour to point at.
    func parkTip(_ tip: ParkTip) -> some View {
        anchorPreference(key: ParkTipAnchors.self, value: .bounds) { [tip: $0] }
    }
}

struct ParkTourStep {
    /// What it points at; nil sits the bubble in the middle of the screen.
    let tip: ParkTip?
    let symbol: String
    let title: String
    let text: String

    /// The tour for this walk. Talking and notes only when there is someone
    /// to talk to or leave them for.
    static func steps(together: Bool, partner: String?) -> [ParkTourStep] {
        let them = partner.flatMap { $0.isEmpty ? nil : $0 } ?? "your love"
        var steps = [
            ParkTourStep(tip: .stick, symbol: "figure.walk", title: "Off for a walk!",
                         text: "Push this pad to walk and Ziggy trots along beside you. Push it right up and hold to keep walking on your own."),
            ParkTourStep(tip: nil, symbol: "hand.draw.fill", title: "Look around",
                         text: "Drag anywhere on the park to turn and look, and pinch to zoom in close."),
            ParkTourStep(tip: .emotes, symbol: "face.smiling.inverse", title: "Say it with a move",
                         text: "Tap yourself to wave, dance, bow or send some love."),
            ParkTourStep(tip: .tricks, symbol: "pawprint.fill", title: "Play with Ziggy",
                         text: "Tap Ziggy to pet him, give him a treat, play catch, or ask for a trick."),
        ]
        if together {
            steps.append(ParkTourStep(tip: .voice, symbol: "mic.fill", title: "Talk while you walk",
                                      text: "Turn your mic on to chat with \(them) as you stroll together."))
            steps.append(ParkTourStep(tip: .note, symbol: "envelope.badge.fill", title: "Hide a love note",
                                      text: "Leave a note anywhere in the park, and \(them) will find it on their walk."))
        }
        steps.append(ParkTourStep(tip: .surprise, symbol: "sparkles", title: "Surprise me",
                                  text: "Tap for a little surprise: fireworks, bubbles, a rainbow… or Ziggy gets the zoomies!"))
        return steps
    }
}

/// The dimmed park with the current control spotlit and its bubble beside it.
struct ParkTourOverlay: View {

    let steps: [ParkTourStep]
    let anchors: [ParkTip: Anchor<CGRect>]
    @Binding var step: Int?
    let finish: () -> Void

    private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)
    private let ink = Color(red: 0.36, green: 0.22, blue: 0.29)
    private let bubbleWidth: CGFloat = 290

    var body: some View {
        GeometryReader { proxy in
            if let index = step, index < steps.count {
                let current = steps[index]
                let hole = current.tip.flatMap { anchors[$0] }.map { proxy[$0].insetBy(dx: -8, dy: -8) }
                ZStack(alignment: .topLeading) {
                    Path { p in
                        p.addRect(CGRect(origin: .zero, size: proxy.size))
                        if let hole {
                            p.addRoundedRect(in: hole, cornerSize: CGSize(width: min(hole.width, hole.height) / 2,
                                                                           height: min(hole.width, hole.height) / 2))
                        }
                    }
                    .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                    .onTapGesture { next() }

                    if let hole {
                        RoundedRectangle(cornerRadius: min(hole.width, hole.height) / 2)
                            .stroke(.white, lineWidth: 2.5)
                            .frame(width: hole.width, height: hole.height)
                            .phaseAnimator([1.0, 1.08]) { ring, scale in
                                ring.scaleEffect(scale).opacity(2.2 - scale * 1.5)
                            } animation: { _ in .easeInOut(duration: 0.8) }
                            .position(x: hole.midX, y: hole.midY)
                            .allowsHitTesting(false)
                    }

                    bubble(current, index: index)
                        .id(index)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .frame(width: bubbleWidth)
                        .modifier(Placement(hole: hole, size: proxy.size, width: bubbleWidth))
                }
            }
        }
        .ignoresSafeArea()
    }

    private func bubble(_ current: ParkTourStep, index: Int) -> some View {
        let last = index == steps.count - 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: current.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(LinearGradient(colors: [Color(red: 1, green: 0.6, blue: 0.72), pink],
                                               startPoint: .top, endPoint: .bottom), in: Circle())
                Text(current.title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(pink)
            }
            Text(current.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? pink : pink.opacity(0.22))
                        .frame(width: i == index ? 16 : 6, height: 6)
                }
                Spacer()
                if !last {
                    Button("Skip") { finish() }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.5))
                        .padding(.trailing, 4)
                }
                Button { next() } label: {
                    Text(last ? "Let's go! 🐾" : "Next")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(pink, in: Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(pink.opacity(0.25), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
    }

    private func next() {
        guard let index = step else { return }
        if index + 1 < steps.count {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { step = index + 1 }
        } else {
            finish()
        }
    }

    /// Puts the bubble below a control near the top of the screen, above one
    /// near the bottom, and in the middle when there is nothing to point at
    /// — kept on screen, with a little tail pointing at the control.
    private struct Placement: ViewModifier {
        let hole: CGRect?
        let size: CGSize
        let width: CGFloat

        func body(content: Content) -> some View {
            if let hole {
                let x = min(max(hole.midX, width / 2 + 16), size.width - width / 2 - 16)
                let below = hole.midY < size.height / 2
                let tail = Triangle()
                    .fill(.white)
                    .frame(width: 22, height: 12)
                    .rotationEffect(.degrees(below ? 0 : 180))
                    .offset(x: hole.midX - x)
                VStack(spacing: -1) {
                    if below { tail }
                    content
                    if !below { tail }
                }
                .frame(width: width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
                .offset(x: x - size.width / 2)
                .padding(.top, below ? hole.maxY + 6 : 0)
                .padding(.bottom, below ? 0 : size.height - hole.minY + 6)
            } else {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private struct Triangle: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: r.midX, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                p.closeSubpath()
            }
        }
    }
}
