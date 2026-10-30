//
//  ZiggyTour.swift
//  Ziggy
//
//  Being shown round: the screen dims, each thing lights up in turn, and a
//  little bubble says what it does. The park and the home screen each have a
//  tour of their own, and both are drawn here.
//
//  A control marks itself with `.tourSpot(_:)`. Frames rather than anchors,
//  because home's tour has to sit over the tab bar, which is outside the tab
//  that holds the controls, and an anchor can't be read from out there.
//

import SwiftUI

struct TourSpots<Tip: Hashable>: PreferenceKey {
    static var defaultValue: [Tip: CGRect] { [:] }
    static func reduce(value: inout [Tip: CGRect], nextValue: () -> [Tip: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks this for a tour to point at.
    func tourSpot<Tip: Hashable>(_ tip: Tip) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: TourSpots<Tip>.self, value: [tip: proxy.frame(in: .global)])
        })
    }
}

struct TourStep<Tip: Hashable> {
    /// What it points at; with neither this nor `place`, the bubble sits in
    /// the middle of the screen.
    var tip: Tip?
    /// For something that can't mark itself, like a tab in the tab bar.
    var place: ((CGSize) -> CGRect?)?
    var round = false
    let title: String
    let text: String
    let picture: AnyView

    init(tip: Tip? = nil, place: ((CGSize) -> CGRect?)? = nil, round: Bool = false,
         title: String, text: String, picture: some View) {
        self.tip = tip
        self.place = place
        self.round = round
        self.title = title
        self.text = text
        self.picture = AnyView(picture)
    }
}

/// The screen dimmed, the current control spotlit, and its bubble beside it.
/// Put it over everything, so nothing sits on top of the spotlight.
struct TourOverlay<Tip: Hashable>: View {

    let steps: [TourStep<Tip>]
    let spots: [Tip: CGRect]
    @Binding var step: Int?
    let finish: () -> Void

    private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)
    private let ink = Color(red: 0.36, green: 0.22, blue: 0.29)
    private let bubbleWidth: CGFloat = 290

    var body: some View {
        GeometryReader { proxy in
            if let index = step, index < steps.count {
                let current = steps[index]
                let spot = current.tip.flatMap { spots[$0] } ?? current.place?(proxy.size)
                let hole = spot?.insetBy(dx: -8, dy: -8)
                // Round things get a round spotlight; the rest often carry a
                // label, which a circle would clip.
                let corner = hole.map { current.round ? min($0.width, $0.height) / 2 : min(min($0.width, $0.height) / 2, 24) } ?? 0
                ZStack(alignment: .topLeading) {
                    Path { p in
                        p.addRect(CGRect(origin: .zero, size: proxy.size))
                        if let hole {
                            p.addRoundedRect(in: hole, cornerSize: CGSize(width: corner, height: corner))
                        }
                    }
                    .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                    .onTapGesture { next() }

                    if let hole {
                        RoundedRectangle(cornerRadius: corner)
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

    private func bubble(_ current: TourStep<Tip>, index: Int) -> some View {
        let last = index == steps.count - 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                current.picture
                Text(current.title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(pink)
            }
            Text(current.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                Text("\(index + 1) of \(steps.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(pink.opacity(0.75))
                    .monospacedDigit()
                Spacer()
                if !last {
                    Button("Skip") { finish() }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.5))
                        .padding(.trailing, 4)
                }
                Button { next() } label: {
                    Text(last ? "Let's go!" : "Next")
                        .fixedSize()
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
