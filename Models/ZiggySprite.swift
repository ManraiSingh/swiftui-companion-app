//
//  ZiggySprite.swift
//  Ziggy
//
//  Ziggy, wearing whatever he has been given.
//
//  Everywhere that used to draw `Image(pet.moodImage)` draws this instead, so
//  a skin turns up on the home card, the Play Center, onboarding and the
//  widget without any of them knowing that skins exist.
//
//  The accessories are vector rather than image assets for the same reason the
//  rest of the app's small art is: one drawing has to hold up on a 500pt hero
//  and a 40pt widget corner, and shipping a PNG large enough for the first
//  makes the second soft.
//

import SwiftUI

// MARK: - The sprite

/// Ziggy in a given mood, with the current skin on top.
struct ZiggySprite: View {

    /// The stock mood image name, e.g. `ziggy_happie`.
    let mood: String

    /// What he is wearing. Nil draws him plain.
    var skin: ZiggySkin = .none

    var body: some View {
        // A square box, because every sprite is square and the anchors are
        // fractions of that square. Letting it be any other shape would put
        // the hat somewhere else on every screen.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in

                    let side = min(geo.size.width, geo.size.height)
                    let anchor = ZiggyAnchor.forSprite(mood)

                    // How far a tall hat would stick out of the top of the
                    // box, as a fraction of it. A top hat and a party hat both
                    // do, and the box is what every caller has sized — so
                    // rather than let them be sliced off, the whole thing is
                    // scaled down by exactly that much and pinned to the
                    // bottom. Ziggy shrinks only when he is wearing something
                    // tall, and only by as much as the hat needs.
                    let fit = headroom(anchor)

                    ZStack {

                        Image(spriteName)
                            .resizable()
                            .scaledToFit()

                        if let piece = skin.accessory {

                            let w = side * anchor.headWidth * piece.widthRatio
                            let h = w * piece.aspect

                            ZiggyAccessoryView(piece: piece, width: w)
                                .frame(width: w, height: h)
                                // Bottom edge on the crown, then sunk in by
                                // its own sink so it sits on him rather than
                                // hovering above.
                                .position(
                                    x: side * anchor.x,
                                    y: side * anchor.y - h / 2 + h * piece.sink
                                )
                        }
                    }
                    .frame(width: side, height: side)
                    .scaleEffect(fit, anchor: .bottom)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
    }

    /// The scale that just fits the accessory inside the square.
    ///
    /// Returns 1 when nothing is worn, or when what is worn sits low enough to
    /// clear the top edge on its own — which is most of them.
    private func headroom(_ anchor: ZiggyAnchor) -> CGFloat {

        guard let piece = skin.accessory else { return 1 }

        // The accessory's height as a fraction of the box.
        let h = anchor.headWidth * piece.widthRatio * piece.aspect

        // How much of it ends up above y = 0.
        let overhang = max(0, h * (1 - piece.sink) - anchor.y)

        return CGFloat(1 / (1 + overhang))
    }

    /// A skin may one day carry a whole alternate Ziggy. Until one does, this
    /// is just the mood.
    private var spriteName: String {
        guard let set = skin.spriteSet else { return mood }
        return "\(set)_\(mood)"
    }
}

// MARK: - The accessories

/// One accessory, drawn in a box `width` across.
struct ZiggyAccessoryView: View {

    let piece: ZiggyAccessory
    let width: CGFloat

    private var w: CGFloat { width }
    private var h: CGFloat { width * piece.aspect }

    var body: some View {
        ZStack {
            switch piece {
            case .bow:         bow
            case .crown:       crown
            case .partyHat:    partyHat
            case .beanie:      beanie
            case .flowerCrown: flowerCrown
            case .halo:        halo
            case .headphones:  headphones
            case .cap:         cap
            case .topHat:      topHat
            case .sprout:      sprout
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: Palette
    //
    // Deliberately a few saturated colours against Ziggy's cream. Anything
    // close to his own fur disappears into him at widget size.

    private let pink   = Color(red: 0.96, green: 0.42, blue: 0.58)
    private let pinkHi = Color(red: 0.99, green: 0.64, blue: 0.75)
    private let gold   = Color(red: 0.98, green: 0.78, blue: 0.24)
    private let goldHi = Color(red: 1.00, green: 0.90, blue: 0.55)
    private let navy   = Color(red: 0.22, green: 0.26, blue: 0.42)
    private let teal   = Color(red: 0.24, green: 0.68, blue: 0.68)
    private let cream  = Color(red: 0.99, green: 0.97, blue: 0.93)
    private let leaf   = Color(red: 0.36, green: 0.68, blue: 0.40)
    private let ink    = Color(red: 0.24, green: 0.20, blue: 0.22)

    // MARK: Pieces

    private var bow: some View {
        ZStack {
            // Loops
            Ellipse().fill(pink)
                .frame(width: w * 0.42, height: h * 0.74)
                .rotationEffect(.degrees(-24))
                .position(x: w * 0.27, y: h * 0.46)
            Ellipse().fill(pink)
                .frame(width: w * 0.42, height: h * 0.74)
                .rotationEffect(.degrees(24))
                .position(x: w * 0.73, y: h * 0.46)

            // Highlights, so it is not a flat blob at small sizes
            Ellipse().fill(pinkHi.opacity(0.75))
                .frame(width: w * 0.16, height: h * 0.30)
                .rotationEffect(.degrees(-24))
                .position(x: w * 0.24, y: h * 0.36)

            // Knot
            Circle().fill(pinkHi)
                .frame(width: w * 0.24, height: w * 0.24)
                .position(x: w * 0.5, y: h * 0.52)
        }
    }

    private var crown: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: w * 0.04, y: h * 0.92))
                p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.34))
                p.addLine(to: CGPoint(x: w * 0.26, y: h * 0.60))
                p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.14))
                p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.60))
                p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.34))
                p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.92))
                p.closeSubpath()
            }
            .fill(
                LinearGradient(colors: [goldHi, gold],
                               startPoint: .top, endPoint: .bottom)
            )

            ForEach(0..<3, id: \.self) { i in
                Circle().fill(pink)
                    .frame(width: w * 0.11, height: w * 0.11)
                    .position(x: w * (0.27 + Double(i) * 0.23), y: h * 0.76)
            }
        }
    }

    private var partyHat: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: w * 0.5, y: h * 0.06))
                p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.90))
                p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.90))
                p.closeSubpath()
            }
            .fill(teal)

            // Stripes, clipped to the cone by drawing them inside the mask.
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(cream.opacity(0.85))
                    .frame(width: w * (0.30 + Double(i) * 0.22), height: h * 0.055)
                    .position(x: w * 0.5, y: h * (0.42 + Double(i) * 0.19))
            }

            Circle().fill(pink)
                .frame(width: w * 0.26, height: w * 0.26)
                .position(x: w * 0.5, y: h * 0.06)
        }
        .mask {
            // Keeps the stripes inside the cone without hand-fitting each one.
            Path { p in
                p.move(to: CGPoint(x: w * 0.5, y: h * -0.14))
                p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.90))
                p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.90))
                p.closeSubpath()
            }
            .fill(.black)
            .overlay {
                Circle()
                    .fill(.black)
                    .frame(width: w * 0.26, height: w * 0.26)
                    .position(x: w * 0.5, y: h * 0.06)
            }
        }
    }

    private var beanie: some View {
        ZStack {
            // Dome
            Path { p in
                p.addArc(
                    center: CGPoint(x: w * 0.5, y: h * 0.72),
                    radius: w * 0.46,
                    startAngle: .degrees(180), endAngle: .degrees(360),
                    clockwise: false
                )
                p.closeSubpath()
            }
            .fill(navy)

            // Turned-up band
            RoundedRectangle(cornerRadius: h * 0.10, style: .continuous)
                .fill(teal)
                .frame(width: w * 0.98, height: h * 0.30)
                .position(x: w * 0.5, y: h * 0.76)

            Circle().fill(cream)
                .frame(width: w * 0.24, height: w * 0.24)
                .position(x: w * 0.5, y: h * 0.16)
        }
    }

    private var flowerCrown: some View {
        ZStack {
            Capsule().fill(leaf)
                .frame(width: w, height: h * 0.30)
                .position(x: w * 0.5, y: h * 0.72)

            ForEach(0..<5, id: \.self) { i in
                let cx = w * (0.12 + Double(i) * 0.19)
                let colours: [Color] = [pink, cream, gold, pinkHi, cream]
                ZStack {
                    ForEach(0..<5, id: \.self) { petal in
                        Ellipse()
                            .fill(colours[i])
                            .frame(width: w * 0.055, height: w * 0.10)
                            .offset(y: -w * 0.045)
                            .rotationEffect(.degrees(Double(petal) * 72))
                    }
                    Circle().fill(gold)
                        .frame(width: w * 0.045, height: w * 0.045)
                }
                .position(x: cx, y: h * (i % 2 == 0 ? 0.44 : 0.56))
            }
        }
    }

    private var halo: some View {
        Ellipse()
            .stroke(
                LinearGradient(colors: [goldHi, gold],
                               startPoint: .leading, endPoint: .trailing),
                lineWidth: max(1.5, h * 0.30)
            )
            .frame(width: w * 0.9, height: h * 0.7)
            .position(x: w * 0.5, y: h * 0.5)
            .shadow(color: gold.opacity(0.7), radius: w * 0.06)
    }

    private var headphones: some View {
        ZStack {
            // Band
            Path { p in
                p.addArc(
                    center: CGPoint(x: w * 0.5, y: h * 0.74),
                    radius: w * 0.40,
                    startAngle: .degrees(190), endAngle: .degrees(350),
                    clockwise: false
                )
            }
            .stroke(navy, style: StrokeStyle(lineWidth: max(1.5, w * 0.09), lineCap: .round))

            ForEach(0..<2, id: \.self) { i in
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(pink)
                    .frame(width: w * 0.20, height: h * 0.46)
                    .position(x: i == 0 ? w * 0.09 : w * 0.91, y: h * 0.74)
            }
        }
    }

    private var cap: some View {
        ZStack {
            // Peak first, so the dome laps over it.
            Ellipse().fill(pink.opacity(0.9))
                .frame(width: w * 0.66, height: h * 0.34)
                .position(x: w * 0.74, y: h * 0.80)

            Path { p in
                p.addArc(
                    center: CGPoint(x: w * 0.46, y: h * 0.82),
                    radius: w * 0.42,
                    startAngle: .degrees(180), endAngle: .degrees(360),
                    clockwise: false
                )
                p.closeSubpath()
            }
            .fill(pink)

            Circle().fill(cream)
                .frame(width: w * 0.10, height: w * 0.10)
                .position(x: w * 0.46, y: h * 0.44)
        }
    }

    private var topHat: some View {
        ZStack {
            RoundedRectangle(cornerRadius: w * 0.04, style: .continuous)
                .fill(navy)
                .frame(width: w * 0.62, height: h * 0.72)
                .position(x: w * 0.5, y: h * 0.40)

            Ellipse().fill(pink)
                .frame(width: w * 0.64, height: h * 0.14)
                .position(x: w * 0.5, y: h * 0.66)

            Ellipse().fill(navy)
                .frame(width: w, height: h * 0.20)
                .position(x: w * 0.5, y: h * 0.84)
        }
    }

    private var sprout: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: w * 0.5, y: h * 0.98))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.30),
                    control: CGPoint(x: w * 0.34, y: h * 0.64)
                )
            }
            .stroke(leaf, style: StrokeStyle(lineWidth: max(1, w * 0.10), lineCap: .round))

            Ellipse().fill(leaf)
                .frame(width: w * 0.52, height: w * 0.30)
                .rotationEffect(.degrees(-28))
                .position(x: w * 0.30, y: h * 0.42)

            Ellipse().fill(leaf.opacity(0.85))
                .frame(width: w * 0.46, height: w * 0.26)
                .rotationEffect(.degrees(26))
                .position(x: w * 0.72, y: h * 0.26)
        }
    }
}
