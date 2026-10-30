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
//  wherever it ends up on screen. The spotlight itself is `TourOverlay`.
//

import SwiftUI

/// A control the tour points at.
enum ParkTip: Hashable {
    case stick, moods, moves, tricks, voice, note, surprise
}

extension View {
    /// Marks this control for the tour to point at.
    func parkTip(_ tip: ParkTip) -> some View { tourSpot(tip) }
}

@available(iOS 18.0, *)
enum ParkTourStep {

    /// The tour for this walk. Talking and notes only when there is someone
    /// to talk to or leave them for.
    static func steps(together: Bool, partner: String?, look: ParkLook) -> [TourStep<ParkTip>] {
        let them = partner.flatMap { $0.isEmpty ? nil : $0 } ?? "your love"
        func step(_ tip: ParkTip?, _ art: ParkTourArt.Scene, _ title: String, _ text: String) -> TourStep<ParkTip> {
            TourStep(tip: tip, round: tip == .stick, title: title, text: text, picture: ParkTourArt(scene: art, look: look))
        }
        var steps = [
            step(.stick, .walk, "Off for a walk!", "Push this pad to walk and Ziggy trots along beside you. Push it right up and hold to keep walking on your own."),
            step(nil, .look, "Look around", "Drag anywhere on the park to turn and look, and pinch to zoom in close."),
            step(.moods, .moods, "How are you feeling?", "Tap your face to show how you feel. It stays on your face, and your partner sees it."),
            step(.moves, .moves, "Say it with a move", "Tap the hand to wave or blow a kiss."),
            step(.tricks, .play, "Play with Ziggy", "Tap Ziggy to ask for a trick. With Ziggy Forever you can pet him, give him a treat and play catch."),
        ]
        if together {
            steps.append(step(.voice, .talk, "Talk while you walk", "Turn your mic on to chat with \(them) as you stroll together."))
            steps.append(step(.note, .note, "Hide a love note", "Leave a note anywhere in the park, and \(them) will find it on their walk."))
        }
        steps.append(step(.surprise, .surprise, "Surprise me", "Tap for a little surprise: fireworks, bubbles, a rainbow… or Ziggy gets the zoomies!"))
        return steps
    }
}

// MARK: - The little pictures

/// The picture beside each step: you, drawn as in the emote menu, doing the
/// thing the step is about.
@available(iOS 18.0, *)
struct ParkTourArt: View {

    enum Scene { case walk, look, moods, moves, play, talk, note, surprise }

    let scene: Scene
    let look: ParkLook
    private let s: CGFloat = 64
    private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)
    private let cream = Color(red: 1, green: 0.96, blue: 0.9)

    var body: some View {
        ZStack {
            switch scene {
            case .walk:
                ForEach(0..<3, id: \.self) { i in
                    paw.rotationEffect(.degrees(70))
                        .offset(x: s * (0.03 + CGFloat(i) * 0.15), y: s * (i % 2 == 0 ? 0.3 : 0.2))
                }
                ParkChibi(look: look, eyes: .happy, mouth: .smile, size: s * 0.56)
                    .offset(x: -s * 0.17, y: s * 0.02)
            case .look:
                Circle().fill(Color(red: 1, green: 0.84, blue: 0.5))
                    .frame(width: s * 0.2, height: s * 0.2)
                    .offset(x: s * 0.24, y: -s * 0.27)
                Ellipse().fill(Color(red: 0.64, green: 0.84, blue: 0.53))
                    .frame(width: s * 1.3, height: s * 0.6)
                    .offset(x: s * 0.1, y: s * 0.4)
                tree.offset(x: s * 0.24, y: -s * 0.02)
                ParkChibi(look: look, eyes: .open, mouth: .smile, size: s * 0.5)
                    .offset(x: -s * 0.2, y: s * 0.16)
            case .moods:
                ParkChibi(look: look, mood: .love, size: s * 0.8)
            case .moves:
                ParkEmoteIllustration(emote: .wave, look: look, size: s * 0.86)
            case .play:
                ParkChibi(look: look, eyes: .happy, mouth: .open, size: s * 0.54)
                    .offset(x: -s * 0.17, y: s * 0.12)
                ball.offset(x: s * 0.24, y: -s * 0.24)
                ParkBoneShape().fill(cream)
                    .overlay(ParkBoneShape().stroke(Color(red: 0.83, green: 0.68, blue: 0.52), lineWidth: 1))
                    .frame(width: s * 0.34, height: s * 0.16)
                    .rotationEffect(.degrees(-20))
                    .offset(x: s * 0.24, y: s * 0.26)
            case .talk:
                ParkChibi(look: look, eyes: .happy, mouth: .open, size: s * 0.48)
                    .offset(x: -s * 0.21, y: s * 0.2)
                ParkChibi(look: look == .casual ? .sundress : .casual, eyes: .happy, mouth: .smile, size: s * 0.48)
                    .offset(x: s * 0.23, y: s * 0.2)
                speechBubble.offset(y: -s * 0.25)
            case .note:
                ParkChibi(look: look, eyes: .happy, mouth: .smile, size: s * 0.5)
                    .offset(y: -s * 0.2)
                envelope.offset(y: s * 0.17)
            case .surprise:
                confetti
                gift.offset(y: s * 0.15)
            }
        }
        .frame(width: s, height: s)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .background(RoundedRectangle(cornerRadius: 18).fill(backdrop))
    }

    private var backdrop: Color {
        switch scene {
        case .walk, .surprise: return Color(red: 1, green: 0.9, blue: 0.82)
        case .look: return Color(red: 0.8, green: 0.91, blue: 0.98)
        case .moods, .moves, .note: return Color(red: 1, green: 0.88, blue: 0.92)
        case .play: return Color(red: 0.87, green: 0.94, blue: 0.8)
        case .talk: return Color(red: 0.91, green: 0.87, blue: 0.99)
        }
    }

    private var paw: some View {
        ZStack {
            Ellipse().fill(pink).frame(width: s * 0.09, height: s * 0.075).offset(y: s * 0.025)
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(pink).frame(width: s * 0.04, height: s * 0.04)
                    .offset(x: s * CGFloat(i - 1) * 0.045, y: -s * (i == 1 ? 0.045 : 0.03))
            }
        }
    }

    /// A tennis ball, its two curved seams clipped to the ball.
    private var ball: some View {
        let d = s * 0.27
        return ZStack {
            Circle().fill(Color(red: 0.86, green: 0.91, blue: 0.36))
            Path { p in
                p.move(to: CGPoint(x: d * 0.14, y: 0))
                p.addQuadCurve(to: CGPoint(x: d * 0.14, y: d), control: CGPoint(x: d * 0.5, y: d * 0.5))
                p.move(to: CGPoint(x: d * 0.86, y: 0))
                p.addQuadCurve(to: CGPoint(x: d * 0.86, y: d), control: CGPoint(x: d * 0.5, y: d * 0.5))
            }
            .stroke(.white, lineWidth: 1.5)
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
    }

    private var tree: some View {
        ZStack {
            Capsule().fill(Color(red: 0.5, green: 0.33, blue: 0.26))
                .frame(width: s * 0.06, height: s * 0.26)
                .offset(y: s * 0.15)
            Circle().fill(Color(red: 0.98, green: 0.72, blue: 0.81)).frame(width: s * 0.26, height: s * 0.26).offset(x: -s * 0.08)
            Circle().fill(Color(red: 1, green: 0.8, blue: 0.87)).frame(width: s * 0.26, height: s * 0.26).offset(x: s * 0.08, y: -s * 0.03)
            Circle().fill(Color(red: 0.96, green: 0.64, blue: 0.76)).frame(width: s * 0.2, height: s * 0.2).offset(y: s * 0.06)
        }
    }

    private var speechBubble: some View {
        ZStack {
            Capsule().fill(.white).frame(width: s * 0.42, height: s * 0.28)
            ParkHeartShape().fill(pink).frame(width: s * 0.15, height: s * 0.14)
        }
    }

    private var envelope: some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.05).fill(cream).frame(width: s * 0.66, height: s * 0.44)
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: s * 0.33, y: s * 0.24))
                p.addLine(to: CGPoint(x: s * 0.66, y: 0))
            }
            .stroke(Color(red: 0.85, green: 0.7, blue: 0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .frame(width: s * 0.66, height: s * 0.44)
            ParkHeartShape().fill(pink).frame(width: s * 0.17, height: s * 0.16).offset(y: s * 0.05)
        }
    }

    private var gift: some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.05).fill(pink)
                .frame(width: s * 0.5, height: s * 0.38)
                .offset(y: s * 0.08)
            RoundedRectangle(cornerRadius: s * 0.04).fill(Color(red: 1, green: 0.55, blue: 0.68))
                .frame(width: s * 0.58, height: s * 0.14)
                .offset(y: -s * 0.12)
            Rectangle().fill(Color(red: 1, green: 0.84, blue: 0.5))
                .frame(width: s * 0.1, height: s * 0.52)
                .offset(y: s * 0.01)
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse().stroke(Color(red: 1, green: 0.84, blue: 0.5), lineWidth: s * 0.05)
                    .frame(width: s * 0.17, height: s * 0.11)
                    .rotationEffect(.degrees(side * -25))
                    .offset(x: side * s * 0.1, y: -s * 0.23)
            }
        }
    }

    private var confetti: some View {
        let colours = [pink, Color(red: 1, green: 0.74, blue: 0.3), Color(red: 0.45, green: 0.75, blue: 0.93),
                       Color(red: 0.55, green: 0.8, blue: 0.45), Color(red: 0.72, green: 0.56, blue: 0.93)]
        let spots: [(CGFloat, CGFloat)] = [(-0.34, -0.14), (-0.2, -0.32), (0.02, -0.38), (0.22, -0.3), (0.35, -0.12)]
        return ForEach(0..<5, id: \.self) { i in
            RoundedRectangle(cornerRadius: 1).fill(colours[i])
                .frame(width: s * 0.06, height: s * 0.11)
                .rotationEffect(.degrees(Double(i) * 47 - 40))
                .offset(x: s * spots[i].0, y: s * spots[i].1)
        }
    }
}
