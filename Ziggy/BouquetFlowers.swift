//
//  BouquetFlowers.swift
//  Ziggy
//
//  The flowers themselves.
//
//  Drawn rather than shipped as artwork or borrowed from the emoji font: they
//  stay crisp at any size, cost nothing to download, and — the reason that
//  actually matters — they can be laid out as a bouquet rather than sitting in
//  a row like a set of icons.
//
//  Each one is a whole stem with its head at the top and the cut end at the
//  bottom of its box, so a stem turned about its base fans out from the tie
//  the way a real one does.
//

import SwiftUI

enum BouquetFlower: Int, CaseIterable, Identifiable {

    case pinkTulip, yellowTulip, whiteDaisy, redDahlia
    case pinkPeony, whiteCosmos, orangePoppy, craspedia
    case lavender, babysBreath, redBud, blushAnemone
    case leafSprig, eucalyptus

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .pinkTulip:    return "Tulip"
        case .yellowTulip:  return "Tulip"
        case .whiteDaisy:   return "Daisy"
        case .redDahlia:    return "Dahlia"
        case .pinkPeony:    return "Peony"
        case .whiteCosmos:  return "Cosmos"
        case .orangePoppy:  return "Poppy"
        case .craspedia:    return "Billy"
        case .lavender:     return "Lavender"
        case .babysBreath:  return "Gyp"
        case .redBud:       return "Bud"
        case .blushAnemone: return "Anemone"
        case .leafSprig:    return "Leaf"
        case .eucalyptus:   return "Euc"
        }
    }

    /// Natural size, in points, at scale 1.
    var size: CGSize {
        switch self {
        case .pinkTulip:    return CGSize(width: 46, height: 150)
        case .yellowTulip:  return CGSize(width: 54, height: 138)
        case .whiteDaisy:   return CGSize(width: 52, height: 128)
        case .redDahlia:    return CGSize(width: 56, height: 120)
        case .pinkPeony:    return CGSize(width: 64, height: 126)
        case .whiteCosmos:  return CGSize(width: 58, height: 132)
        case .orangePoppy:  return CGSize(width: 60, height: 124)
        case .craspedia:    return CGSize(width: 50, height: 146)
        case .lavender:     return CGSize(width: 34, height: 152)
        case .babysBreath:  return CGSize(width: 48, height: 140)
        case .redBud:       return CGSize(width: 30, height: 118)
        case .blushAnemone: return CGSize(width: 58, height: 116)
        case .leafSprig:    return CGSize(width: 44, height: 122)
        case .eucalyptus:   return CGSize(width: 40, height: 144)
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .pinkTulip:    Tulip(petal: BouquetPalette.blush, deep: BouquetPalette.blushDeep)
        case .yellowTulip:  OpenTulip(petal: BouquetPalette.marigold, deep: BouquetPalette.marigoldDeep)
        case .whiteDaisy:   RoundBloom(petal: BouquetPalette.cream, centre: BouquetPalette.yolk, petals: 9, dark: false)
        case .redDahlia:    RoundBloom(petal: BouquetPalette.crimson, centre: BouquetPalette.yolk, petals: 12, dark: false)
        case .pinkPeony:    CupBloom(petal: BouquetPalette.rose, centre: BouquetPalette.ink)
        case .whiteCosmos:  RoundBloom(petal: BouquetPalette.paper, centre: BouquetPalette.yolk, petals: 7, dark: false)
        case .orangePoppy:  OpenTulip(petal: BouquetPalette.amber, deep: BouquetPalette.amberDeep)
        case .craspedia:    BallSprig()
        case .lavender:     Spike(colour: BouquetPalette.lilac)
        case .babysBreath:  Gyp()
        case .redBud:       Bud()
        case .blushAnemone: CupBloom(petal: BouquetPalette.shell, centre: BouquetPalette.ink)
        case .leafSprig:    LeafSprig()
        case .eucalyptus:   Eucalyptus()
        }
    }
}

// MARK: - Palette

enum BouquetPalette {

    static let stem       = Color(red: 0.36, green: 0.51, blue: 0.35)
    static let stemDeep   = Color(red: 0.26, green: 0.39, blue: 0.27)
    static let leaf       = Color(red: 0.44, green: 0.60, blue: 0.40)
    static let sage       = Color(red: 0.64, green: 0.72, blue: 0.60)

    static let blush      = Color(red: 0.96, green: 0.72, blue: 0.76)
    static let blushDeep  = Color(red: 0.90, green: 0.60, blue: 0.66)
    static let rose       = Color(red: 0.97, green: 0.80, blue: 0.80)
    static let shell      = Color(red: 0.99, green: 0.90, blue: 0.88)
    static let crimson    = Color(red: 0.80, green: 0.22, blue: 0.24)
    static let marigold   = Color(red: 0.98, green: 0.80, blue: 0.30)
    static let marigoldDeep = Color(red: 0.94, green: 0.68, blue: 0.20)
    static let amber      = Color(red: 0.96, green: 0.62, blue: 0.22)
    static let amberDeep  = Color(red: 0.88, green: 0.48, blue: 0.16)
    static let yolk       = Color(red: 0.98, green: 0.78, blue: 0.22)
    static let lilac      = Color(red: 0.76, green: 0.68, blue: 0.86)
    static let cream      = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let paper      = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let ink        = Color(red: 0.20, green: 0.16, blue: 0.16)

    /// A soft warm edge for pale petals.
    ///
    /// A white flower on cream paper is a white flower on cream paper — the
    /// daisy and the gyp came out as a yellow dot and a bare stem. This is
    /// what gives them a shape to read against the wrap.
    static let edge       = Color(red: 0.84, green: 0.80, blue: 0.74)

    /// The papers a bouquet can be wrapped in.
    static let wraps: [(name: String, paper: Color, shade: Color)] = [
        ("Kraft",  Color(red: 0.91, green: 0.83, blue: 0.71), Color(red: 0.84, green: 0.74, blue: 0.60)),
        ("Cream",  Color(red: 0.98, green: 0.95, blue: 0.90), Color(red: 0.93, green: 0.89, blue: 0.82)),
        ("Blush",  Color(red: 0.97, green: 0.87, blue: 0.86), Color(red: 0.93, green: 0.79, blue: 0.79)),
        ("Sage",   Color(red: 0.84, green: 0.87, blue: 0.79), Color(red: 0.75, green: 0.80, blue: 0.70)),
        ("Sky",    Color(red: 0.84, green: 0.89, blue: 0.94), Color(red: 0.74, green: 0.82, blue: 0.89)),
        ("Charcoal", Color(red: 0.36, green: 0.35, blue: 0.36), Color(red: 0.28, green: 0.27, blue: 0.29))
    ]

    static let ribbons: [String] = [
        "#B0413E", "#D98C8C", "#C9A227", "#6E8B6B",
        "#8C7BA6", "#3F5E7A", "#F2E8DA", "#3A3A3C"
    ]
}

// MARK: - Shared pieces

/// A stem running from the bottom of the box up to where a head sits.
private struct Stem: View {

    var lean: CGFloat = 0
    var colour: Color = BouquetPalette.stem
    var headY: CGFloat

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            Path { path in
                path.move(to: CGPoint(x: w * 0.5, y: h))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.5 + lean, y: h * headY),
                    control: CGPoint(x: w * 0.5 + lean * 0.3, y: h * (headY + 0.4))
                )
            }
            .stroke(colour, style: StrokeStyle(lineWidth: max(w * 0.055, 1.6), lineCap: .round))
        }
    }
}

/// A single leaf, used along stems.
private struct Blade: View {

    var colour: Color = BouquetPalette.leaf

    var body: some View {
        BladeShape().fill(colour)
    }
}

private struct BladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tulips

private struct Tulip: View {

    let petal: Color
    let deep: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: 0.30).frame(width: w, height: h)

                Blade()
                    .frame(width: w * 0.42, height: h * 0.22)
                    .rotationEffect(.degrees(-18))
                    .position(x: w * 0.30, y: h * 0.60)

                TulipCup()
                    .fill(petal)
                    .frame(width: w * 0.82, height: h * 0.30)
                    .overlay(
                        TulipCup()
                            .fill(deep)
                            .frame(width: w * 0.28, height: h * 0.30)
                    )
                    .position(x: w * 0.5, y: h * 0.18)
            }
        }
    }
}

private struct TulipCup: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.22),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.32, y: rect.minY),
                          control: CGPoint(x: rect.width * 0.10, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.height * 0.16),
                          control: CGPoint(x: rect.width * 0.42, y: rect.height * 0.10))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.68, y: rect.minY),
                          control: CGPoint(x: rect.width * 0.58, y: rect.height * 0.10))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.22),
                          control: CGPoint(x: rect.width * 0.90, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A tulip seen wide open, petals splayed.
private struct OpenTulip: View {

    let petal: Color
    let deep: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: 0.32).frame(width: w, height: h)

                Blade()
                    .frame(width: w * 0.44, height: h * 0.24)
                    .rotationEffect(.degrees(20))
                    .scaleEffect(x: -1)
                    .position(x: w * 0.70, y: h * 0.62)

                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Petal()
                            .fill(index == 1 ? deep : petal)
                            .frame(width: w * 0.44, height: h * 0.30)
                            .rotationEffect(.degrees(Double(index - 1) * 34))
                            .offset(y: index == 1 ? -h * 0.02 : 0)
                    }
                }
                .position(x: w * 0.5, y: h * 0.19)
            }
        }
    }
}

private struct Petal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.height * 0.30))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.height * 0.30))
        path.closeSubpath()
        return path
    }
}

// MARK: - Round blooms

/// Daisies, cosmos, dahlias — petals arranged round a centre.
private struct RoundBloom: View {

    let petal: Color
    let centre: Color
    let petals: Int
    let dark: Bool

    /// Pale petals need a line round them; saturated ones read on their own.
    private var edge: Color {
        dark ? .clear : BouquetPalette.edge.opacity(0.9)
    }

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height
            let head = w * 0.92

            ZStack {
                Stem(headY: 0.34).frame(width: w, height: h)

                Blade()
                    .frame(width: w * 0.38, height: h * 0.20)
                    .rotationEffect(.degrees(-22))
                    .position(x: w * 0.32, y: h * 0.64)

                ZStack {
                    ForEach(0..<petals, id: \.self) { index in
                        Ellipse()
                            .fill(petal)
                            .overlay(Ellipse().stroke(edge, lineWidth: max(head * 0.014, 0.6)))
                            .frame(width: head * 0.26, height: head * 0.50)
                            .offset(y: -head * 0.24)
                            .rotationEffect(.degrees(Double(index) / Double(petals) * 360))
                    }

                    Circle()
                        .fill(centre)
                        .frame(width: head * 0.30, height: head * 0.30)
                }
                .frame(width: head, height: head)
                .position(x: w * 0.5, y: h * 0.22)
            }
        }
    }
}

/// A wide, shallow bloom with a dark eye — peonies and anemones.
private struct CupBloom: View {

    let petal: Color
    let centre: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height
            let head = w * 0.94

            ZStack {
                Stem(headY: 0.36).frame(width: w, height: h)

                Blade()
                    .frame(width: w * 0.36, height: h * 0.20)
                    .rotationEffect(.degrees(24))
                    .scaleEffect(x: -1)
                    .position(x: w * 0.68, y: h * 0.66)

                ZStack {
                    ForEach(0..<7, id: \.self) { index in
                        Ellipse()
                            .fill(petal)
                            .overlay(Ellipse().stroke(BouquetPalette.edge.opacity(0.85),
                                                      lineWidth: max(head * 0.013, 0.6)))
                            .frame(width: head * 0.46, height: head * 0.54)
                            .offset(y: -head * 0.26)
                            .rotationEffect(.degrees(Double(index) / 7 * 360))
                    }

                    Circle()
                        .fill(petal)
                        .overlay(Circle().stroke(BouquetPalette.edge.opacity(0.7),
                                                 lineWidth: max(head * 0.012, 0.5)))
                        .frame(width: head * 0.44, height: head * 0.44)

                    Circle()
                        .fill(centre)
                        .frame(width: head * 0.20, height: head * 0.20)
                }
                .frame(width: head, height: head)
                .position(x: w * 0.5, y: h * 0.24)
            }
        }
    }
}

// MARK: - Sprigs

/// Craspedia: little yellow drumsticks on branching stems.
private struct BallSprig: View {

    private let heads: [(CGFloat, CGFloat, CGFloat)] = [
        (0.50, 0.10, 0.30), (0.20, 0.24, 0.24), (0.80, 0.20, 0.26),
        (0.34, 0.40, 0.22), (0.68, 0.42, 0.22)
    ]

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                ForEach(Array(heads.enumerated()), id: \.offset) { _, head in
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.5, y: h))
                        path.addQuadCurve(
                            to: CGPoint(x: w * head.0, y: h * head.1),
                            control: CGPoint(x: w * 0.5, y: h * 0.6)
                        )
                    }
                    .stroke(BouquetPalette.stem,
                            style: StrokeStyle(lineWidth: max(w * 0.035, 1.2), lineCap: .round))

                    Circle()
                        .fill(BouquetPalette.marigold)
                        .frame(width: w * head.2, height: w * head.2)
                        .position(x: w * head.0, y: h * head.1)
                }
            }
        }
    }
}

/// Lavender: a spike of small blooms.
private struct Spike: View {

    let colour: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: 0.30).frame(width: w, height: h)

                ForEach(0..<10, id: \.self) { index in
                    let t = Double(index) / 10
                    Ellipse()
                        .fill(colour.opacity(index % 2 == 0 ? 1 : 0.8))
                        .frame(width: w * 0.44, height: w * 0.30)
                        .position(
                            x: w * (index.isMultiple(of: 2) ? 0.36 : 0.64),
                            y: h * (0.06 + t * 0.26)
                        )
                }
            }
        }
    }
}

/// Baby's breath: a haze of tiny white dots.
private struct Gyp: View {

    private let dots: [(CGFloat, CGFloat, CGFloat)] = [
        (0.50, 0.06, 0.14), (0.28, 0.14, 0.11), (0.72, 0.12, 0.12),
        (0.40, 0.22, 0.10), (0.62, 0.24, 0.11), (0.16, 0.28, 0.09),
        (0.84, 0.30, 0.09), (0.50, 0.32, 0.10), (0.32, 0.38, 0.08),
        (0.70, 0.40, 0.08)
    ]

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.5, y: h))
                        path.addQuadCurve(
                            to: CGPoint(x: w * dot.0, y: h * dot.1),
                            control: CGPoint(x: w * 0.5, y: h * 0.62)
                        )
                    }
                    .stroke(BouquetPalette.sage,
                            style: StrokeStyle(lineWidth: max(w * 0.022, 0.8), lineCap: .round))
                }

                ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                    Circle()
                        .fill(BouquetPalette.paper)
                        .overlay(Circle().stroke(BouquetPalette.edge, lineWidth: 0.8))
                        .frame(width: w * dot.2, height: w * dot.2)
                        .position(x: w * dot.0, y: h * dot.1)
                }
            }
        }
    }
}

/// A closed bud on a slim stem.
private struct Bud: View {

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: 0.22).frame(width: w, height: h)

                Blade()
                    .frame(width: w * 0.55, height: h * 0.18)
                    .rotationEffect(.degrees(-26))
                    .position(x: w * 0.28, y: h * 0.56)

                Capsule()
                    .fill(BouquetPalette.crimson)
                    .frame(width: w * 0.62, height: h * 0.22)
                    .position(x: w * 0.5, y: h * 0.14)
            }
        }
    }
}

/// A pair of leaves on a stem.
private struct LeafSprig: View {

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(lean: 0, colour: BouquetPalette.stemDeep, headY: 0.14)
                    .frame(width: w, height: h)

                ForEach(0..<3, id: \.self) { index in
                    let y = 0.24 + Double(index) * 0.20
                    Blade(colour: BouquetPalette.leaf)
                        .frame(width: w * 0.60, height: h * 0.20)
                        .rotationEffect(.degrees(-26))
                        .position(x: w * 0.24, y: h * y)

                    Blade(colour: BouquetPalette.leaf)
                        .frame(width: w * 0.60, height: h * 0.20)
                        .rotationEffect(.degrees(26))
                        .scaleEffect(x: -1)
                        .position(x: w * 0.76, y: h * (y + 0.07))
                }
            }
        }
    }
}

/// Eucalyptus: round leaves alternating up a slim branch.
private struct Eucalyptus: View {

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(lean: 0, colour: BouquetPalette.sage, headY: 0.10)
                    .frame(width: w, height: h)

                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(BouquetPalette.sage)
                        .frame(width: w * 0.46, height: w * 0.40)
                        .position(
                            x: w * (index.isMultiple(of: 2) ? 0.30 : 0.70),
                            y: h * (0.12 + Double(index) * 0.11)
                        )
                }
            }
        }
    }
}
