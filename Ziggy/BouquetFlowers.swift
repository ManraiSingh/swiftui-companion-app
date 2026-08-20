//
//  BouquetFlowers.swift
//  Ziggy
//
//  The flowers themselves.
//
//  Drawn rather than shipped as artwork or borrowed from the emoji font: they
//  stay crisp at any size, cost nothing to download, they can be recoloured a
//  stem at a time, and — the reason that actually matters — they can be laid
//  out as a bouquet rather than sitting in a row like a set of icons.
//
//  Each is a whole stem with its head at the top and the cut end at the bottom
//  of its box, so a stem turned about its base fans out from the tie the way a
//  real one does.
//
//  Every bloom is petals in rings, with a deeper edge and a lighter heart. A
//  single flat ellipse reads as clip art; the ring, the inner ring and the
//  shading are what make it look drawn.
//

import SwiftUI

enum BouquetFlower: Int, CaseIterable, Identifiable {

    case rose, ranunculus, pinkTulip, yellowTulip
    case whiteDaisy, redDahlia, pinkPeony, whiteCosmos
    case orangePoppy, sunflower, hydrangea, sweetPea
    case craspedia, lavender, babysBreath, blushAnemone
    case leafSprig, eucalyptus

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .rose:         return "Rose"
        case .ranunculus:   return "Ranunculus"
        case .pinkTulip:    return "Tulip"
        case .yellowTulip:  return "Tulip"
        case .whiteDaisy:   return "Daisy"
        case .redDahlia:    return "Dahlia"
        case .pinkPeony:    return "Peony"
        case .whiteCosmos:  return "Cosmos"
        case .orangePoppy:  return "Poppy"
        case .sunflower:    return "Sunflower"
        case .hydrangea:    return "Hydrangea"
        case .sweetPea:     return "Sweet pea"
        case .craspedia:    return "Billy"
        case .lavender:     return "Lavender"
        case .babysBreath:  return "Gyp"
        case .blushAnemone: return "Anemone"
        case .leafSprig:    return "Leaf"
        case .eucalyptus:   return "Eucalyptus"
        }
    }

    /// Greenery keeps its own colour. A mint-green fern is a novelty; a
    /// recoloured rose is just a different rose.
    var takesColour: Bool {
        switch self {
        case .leafSprig, .eucalyptus, .babysBreath: return false
        default: return true
        }
    }

    var defaultTint: Color {
        switch self {
        case .rose:         return BouquetPalette.rosePink
        case .ranunculus:   return BouquetPalette.apricot
        case .pinkTulip:    return BouquetPalette.blush
        case .yellowTulip:  return BouquetPalette.marigold
        case .whiteDaisy:   return BouquetPalette.cream
        case .redDahlia:    return BouquetPalette.crimson
        case .pinkPeony:    return BouquetPalette.rose
        case .whiteCosmos:  return BouquetPalette.paper
        case .orangePoppy:  return BouquetPalette.amber
        case .sunflower:    return BouquetPalette.marigold
        case .hydrangea:    return BouquetPalette.periwinkle
        case .sweetPea:     return BouquetPalette.lilac
        case .craspedia:    return BouquetPalette.marigold
        case .lavender:     return BouquetPalette.lilac
        case .babysBreath:  return BouquetPalette.paper
        case .blushAnemone: return BouquetPalette.shell
        case .leafSprig:    return BouquetPalette.leaf
        case .eucalyptus:   return BouquetPalette.sage
        }
    }

    /// Natural size, in points, at scale 1.
    var size: CGSize {
        switch self {
        case .rose:         return CGSize(width: 62, height: 138)
        case .ranunculus:   return CGSize(width: 58, height: 130)
        case .pinkTulip:    return CGSize(width: 48, height: 150)
        case .yellowTulip:  return CGSize(width: 56, height: 140)
        case .whiteDaisy:   return CGSize(width: 56, height: 132)
        case .redDahlia:    return CGSize(width: 60, height: 126)
        case .pinkPeony:    return CGSize(width: 68, height: 130)
        case .whiteCosmos:  return CGSize(width: 60, height: 136)
        case .orangePoppy:  return CGSize(width: 62, height: 128)
        case .sunflower:    return CGSize(width: 70, height: 144)
        case .hydrangea:    return CGSize(width: 66, height: 128)
        case .sweetPea:     return CGSize(width: 52, height: 134)
        case .craspedia:    return CGSize(width: 52, height: 146)
        case .lavender:     return CGSize(width: 36, height: 152)
        case .babysBreath:  return CGSize(width: 50, height: 140)
        case .blushAnemone: return CGSize(width: 62, height: 122)
        case .leafSprig:    return CGSize(width: 46, height: 124)
        case .eucalyptus:   return CGSize(width: 42, height: 146)
        }
    }

    @ViewBuilder
    func view(tint: Color? = nil) -> some View {

        let c = takesColour ? (tint ?? defaultTint) : defaultTint

        switch self {
        case .rose:         SpiralRose(petal: c)
        case .ranunculus:   Layered(petal: c, rings: 3, perRing: 9, eye: BouquetPalette.yolk)
        case .pinkTulip:    Tulip(petal: c)
        case .yellowTulip:  OpenTulip(petal: c)
        case .whiteDaisy:   Daisy(petal: c, centre: BouquetPalette.yolk, petals: 12, slim: true)
        case .redDahlia:    Layered(petal: c, rings: 2, perRing: 12, eye: BouquetPalette.yolk)
        case .pinkPeony:    Peony(petal: c, eye: BouquetPalette.ink)
        case .whiteCosmos:  Daisy(petal: c, centre: BouquetPalette.yolk, petals: 8, slim: false)
        case .orangePoppy:  OpenTulip(petal: c)
        case .sunflower:    Daisy(petal: c, centre: BouquetPalette.cocoa, petals: 16, slim: true)
        case .hydrangea:    Hydrangea(petal: c)
        case .sweetPea:     SweetPea(petal: c)
        case .craspedia:    BallSprig(colour: c)
        case .lavender:     Spike(colour: c)
        case .babysBreath:  Gyp()
        case .blushAnemone: Peony(petal: c, eye: BouquetPalette.ink)
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

    static let blush      = Color(red: 0.96, green: 0.72, blue: 0.78)
    static let rosePink   = Color(red: 0.93, green: 0.52, blue: 0.58)
    static let rose       = Color(red: 0.97, green: 0.79, blue: 0.82)
    static let shell      = Color(red: 0.99, green: 0.90, blue: 0.88)
    static let crimson    = Color(red: 0.82, green: 0.24, blue: 0.28)
    static let marigold   = Color(red: 0.98, green: 0.79, blue: 0.32)
    static let apricot    = Color(red: 0.97, green: 0.70, blue: 0.48)
    static let amber      = Color(red: 0.96, green: 0.60, blue: 0.24)
    static let yolk       = Color(red: 0.98, green: 0.76, blue: 0.24)
    static let cocoa      = Color(red: 0.42, green: 0.29, blue: 0.20)
    static let lilac      = Color(red: 0.76, green: 0.68, blue: 0.88)
    static let periwinkle = Color(red: 0.68, green: 0.75, blue: 0.92)
    static let cream      = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let paper      = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let ink        = Color(red: 0.22, green: 0.17, blue: 0.16)

    /// A soft warm edge for pale petals. A white flower on cream paper is a
    /// white flower on cream paper — the daisy was a yellow dot on a bare
    /// stem until it had one.
    static let edge       = Color(red: 0.82, green: 0.78, blue: 0.72)

    /// Colours a single stem can be changed to.
    static let tints: [String] = [
        "#F2B8C6", "#ED8598", "#D93E4E", "#F6A96B", "#F5C542",
        "#FBF6EC", "#C7B2E6", "#8FA9E8", "#7FB98C", "#E8A0C4",
        "#B0413E", "#5E7BA6"
    ]

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

extension Color {
    /// A deeper version of a petal colour, for its edge and shading.
    var deeper: Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h),
                     saturation: Double(min(s * 1.18 + 0.04, 1)),
                     brightness: Double(max(b * 0.86, 0.12)))
    }

    var lighter: Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h),
                     saturation: Double(max(s * 0.62, 0)),
                     brightness: Double(min(b * 1.06 + 0.05, 1)))
    }
}

// MARK: - Shared pieces

private struct Stem: View {

    var colour: Color = BouquetPalette.stem
    var headY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            Path { path in
                path.move(to: CGPoint(x: w * 0.5, y: h))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * headY))
            }
            .stroke(colour, style: StrokeStyle(lineWidth: max(w * 0.05, 1.6), lineCap: .round))
        }
    }
}

private struct Blade: View {
    var colour: Color = BouquetPalette.leaf
    var body: some View {
        BladeShape()
            .fill(colour)
            .overlay(BladeShape().stroke(colour.deeper.opacity(0.35), lineWidth: 0.8))
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

/// A petal shaped like one — narrow at the base, round at the tip.
private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.62),
            control2: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.height * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.height * 0.12),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.62)
        )
        path.closeSubpath()
        return path
    }
}

/// A stem with leaves, shared by every single-headed bloom.
private struct Stalk: View {

    let headY: CGFloat
    var flip: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: headY).frame(width: w, height: h)

                Blade()
                    .frame(width: w * 0.40, height: h * 0.19)
                    .rotationEffect(.degrees(flip ? 22 : -22))
                    .scaleEffect(x: flip ? -1 : 1)
                    .position(x: w * (flip ? 0.70 : 0.30), y: h * 0.66)

                Blade()
                    .frame(width: w * 0.32, height: h * 0.15)
                    .rotationEffect(.degrees(flip ? -20 : 20))
                    .scaleEffect(x: flip ? 1 : -1)
                    .position(x: w * (flip ? 0.32 : 0.68), y: h * 0.83)
            }
        }
    }
}

// MARK: - Blooms

/// Petals in rings, each a little smaller — dahlias, ranunculus.
private struct Layered: View {

    let petal: Color
    let rings: Int
    let perRing: Int
    let eye: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let head = w * 0.94

            ZStack {
                Stalk(headY: 0.36).frame(width: w, height: h)

                ZStack {
                    ForEach(0..<rings, id: \.self) { ring in

                        let shrink = 1 - Double(ring) * 0.24
                        let shade = ring == 0 ? petal.deeper : (ring == 1 ? petal : petal.lighter)

                        ForEach(0..<perRing, id: \.self) { index in
                            PetalShape()
                                .fill(shade)
                                .overlay(PetalShape().stroke(petal.deeper.opacity(0.30),
                                                             lineWidth: 0.7))
                                .frame(width: head * 0.30 * shrink,
                                       height: head * 0.50 * shrink)
                                .offset(y: -head * 0.24 * shrink)
                                .rotationEffect(.degrees(
                                    Double(index) / Double(perRing) * 360
                                    + Double(ring) * (180 / Double(perRing))
                                ))
                        }
                    }

                    Circle()
                        .fill(eye)
                        .frame(width: head * 0.20, height: head * 0.20)
                }
                .frame(width: head, height: head)
                .position(x: w * 0.5, y: h * 0.22)
            }
        }
    }
}

/// Long petals round a round centre.
private struct Daisy: View {

    let petal: Color
    let centre: Color
    let petals: Int
    let slim: Bool

    private var isPale: Bool {
        petal == BouquetPalette.cream || petal == BouquetPalette.paper
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let head = w * 0.92

            ZStack {
                Stalk(headY: 0.34).frame(width: w, height: h)

                ZStack {
                    ForEach(0..<petals, id: \.self) { index in
                        PetalShape()
                            .fill(petal)
                            .overlay(PetalShape().stroke(
                                isPale ? BouquetPalette.edge : petal.deeper.opacity(0.35),
                                lineWidth: 0.8))
                            .frame(width: head * (slim ? 0.20 : 0.30),
                                   height: head * (slim ? 0.52 : 0.46))
                            .offset(y: -head * (slim ? 0.25 : 0.22))
                            .rotationEffect(.degrees(Double(index) / Double(petals) * 360))
                    }

                    Circle()
                        .fill(centre)
                        .overlay(Circle().stroke(centre.deeper.opacity(0.45), lineWidth: 0.8))
                        .frame(width: head * 0.30, height: head * 0.30)

                    Circle()
                        .fill(centre.deeper.opacity(0.35))
                        .frame(width: head * 0.14, height: head * 0.14)
                }
                .frame(width: head, height: head)
                .position(x: w * 0.5, y: h * 0.21)
            }
        }
    }
}

/// Wide overlapping petals with a dark eye — peonies and anemones.
private struct Peony: View {

    let petal: Color
    let eye: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let head = w * 0.94

            ZStack {
                Stalk(headY: 0.38, flip: true).frame(width: w, height: h)

                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Ellipse()
                            .fill(index.isMultiple(of: 2) ? petal : petal.deeper.opacity(0.9))
                            .overlay(Ellipse().stroke(petal.deeper.opacity(0.32), lineWidth: 0.8))
                            .frame(width: head * 0.46, height: head * 0.52)
                            .offset(y: -head * 0.24)
                            .rotationEffect(.degrees(Double(index) / 8 * 360))
                    }

                    ForEach(0..<5, id: \.self) { index in
                        Ellipse()
                            .fill(petal.lighter)
                            .frame(width: head * 0.30, height: head * 0.34)
                            .offset(y: -head * 0.13)
                            .rotationEffect(.degrees(Double(index) / 5 * 360 + 26))
                    }

                    Circle()
                        .fill(eye)
                        .frame(width: head * 0.17, height: head * 0.17)
                }
                .frame(width: head, height: head)
                .position(x: w * 0.5, y: h * 0.23)
            }
        }
    }
}

/// A rose, drawn as a spiral of arcs inside cupped petals.
private struct SpiralRose: View {

    let petal: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let head = w * 0.86

            ZStack {
                Stalk(headY: 0.36).frame(width: w, height: h)

                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        PetalShape()
                            .fill(petal)
                            .overlay(PetalShape().stroke(petal.deeper.opacity(0.4), lineWidth: 0.8))
                            .frame(width: head * 0.44, height: head * 0.46)
                            .offset(y: -head * 0.22)
                            .rotationEffect(.degrees(Double(index) / 6 * 360))
                    }

                    ForEach(0..<4, id: \.self) { turn in
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(turn.isMultiple(of: 2) ? petal.deeper : petal.lighter,
                                    style: StrokeStyle(lineWidth: head * 0.075, lineCap: .round))
                            .frame(width: head * (0.46 - Double(turn) * 0.10),
                                   height: head * (0.46 - Double(turn) * 0.10))
                            .rotationEffect(.degrees(Double(turn) * 74))
                    }
                }
                .frame(width: head, height: head)
                .position(x: w * 0.5, y: h * 0.22)
            }
        }
    }
}

// MARK: - Tulips

private struct Tulip: View {

    let petal: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stalk(headY: 0.28).frame(width: w, height: h)

                TulipCup()
                    .fill(petal)
                    .overlay(TulipCup().stroke(petal.deeper.opacity(0.4), lineWidth: 0.9))
                    .frame(width: w * 0.84, height: h * 0.30)
                    .overlay(
                        TulipCup()
                            .fill(petal.deeper.opacity(0.5))
                            .frame(width: w * 0.24, height: h * 0.28)
                    )
                    .position(x: w * 0.5, y: h * 0.17)
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

private struct OpenTulip: View {

    let petal: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stalk(headY: 0.32, flip: true).frame(width: w, height: h)

                ZStack {
                    ForEach(0..<5, id: \.self) { index in
                        PetalShape()
                            .fill(index == 2 ? petal.deeper : petal)
                            .overlay(PetalShape().stroke(petal.deeper.opacity(0.4), lineWidth: 0.8))
                            .frame(width: w * 0.40, height: h * 0.30)
                            .offset(y: -h * 0.04)
                            .rotationEffect(.degrees(Double(index - 2) * 26))
                    }
                }
                .position(x: w * 0.5, y: h * 0.19)
            }
        }
    }
}

// MARK: - Clusters

/// Hydrangea: a dome of little four-petal florets.
private struct Hydrangea: View {

    let petal: Color

    private let florets: [(CGFloat, CGFloat, CGFloat)] = [
        (0.50, 0.13, 0.32), (0.25, 0.19, 0.28), (0.75, 0.19, 0.28),
        (0.37, 0.31, 0.27), (0.63, 0.31, 0.27), (0.14, 0.33, 0.24),
        (0.86, 0.33, 0.24), (0.50, 0.39, 0.25)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stalk(headY: 0.42).frame(width: w, height: h)

                ForEach(Array(florets.enumerated()), id: \.offset) { index, spot in
                    ZStack {
                        ForEach(0..<4, id: \.self) { p in
                            Ellipse()
                                .fill(index.isMultiple(of: 2) ? petal : petal.lighter)
                                .overlay(Ellipse().stroke(petal.deeper.opacity(0.3),
                                                          lineWidth: 0.6))
                                .frame(width: w * spot.2 * 0.62, height: w * spot.2 * 0.52)
                                .offset(y: -w * spot.2 * 0.22)
                                .rotationEffect(.degrees(Double(p) * 90))
                        }
                        Circle()
                            .fill(BouquetPalette.yolk)
                            .frame(width: w * spot.2 * 0.16, height: w * spot.2 * 0.16)
                    }
                    .position(x: w * spot.0, y: h * spot.1)
                }
            }
        }
    }
}

/// Sweet pea: ruffled blooms climbing a slim stem.
private struct SweetPea: View {

    let petal: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: 0.10).frame(width: w, height: h)

                ForEach(0..<4, id: \.self) { index in
                    let y = 0.12 + Double(index) * 0.13
                    let side: CGFloat = index.isMultiple(of: 2) ? 0.34 : 0.66

                    ZStack {
                        Ellipse()
                            .fill(petal)
                            .overlay(Ellipse().stroke(petal.deeper.opacity(0.35), lineWidth: 0.7))
                            .frame(width: w * 0.58, height: w * 0.44)
                            .offset(y: -w * 0.08)

                        Ellipse()
                            .fill(petal.lighter)
                            .frame(width: w * 0.38, height: w * 0.30)
                            .offset(y: w * 0.04)
                    }
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -14 : 14))
                    .position(x: w * side, y: h * y)
                }
            }
        }
    }
}

private struct BallSprig: View {

    let colour: Color

    private let heads: [(CGFloat, CGFloat, CGFloat)] = [
        (0.50, 0.09, 0.30), (0.20, 0.23, 0.24), (0.80, 0.19, 0.26),
        (0.34, 0.39, 0.22), (0.68, 0.41, 0.22)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                ForEach(Array(heads.enumerated()), id: \.offset) { _, head in
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.5, y: h))
                        path.addQuadCurve(to: CGPoint(x: w * head.0, y: h * head.1),
                                          control: CGPoint(x: w * 0.5, y: h * 0.6))
                    }
                    .stroke(BouquetPalette.stem,
                            style: StrokeStyle(lineWidth: max(w * 0.033, 1.2), lineCap: .round))

                    Circle()
                        .fill(colour)
                        .overlay(Circle().stroke(colour.deeper.opacity(0.4), lineWidth: 0.8))
                        .frame(width: w * head.2, height: w * head.2)
                        .position(x: w * head.0, y: h * head.1)
                }
            }
        }
    }
}

private struct Spike: View {

    let colour: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(headY: 0.28).frame(width: w, height: h)

                ForEach(0..<12, id: \.self) { index in
                    let t = Double(index) / 12
                    Ellipse()
                        .fill(index.isMultiple(of: 2) ? colour : colour.lighter)
                        .frame(width: w * 0.42, height: w * 0.28)
                        .position(x: w * (index.isMultiple(of: 2) ? 0.36 : 0.64),
                                  y: h * (0.05 + t * 0.28))
                }
            }
        }
    }
}

private struct Gyp: View {

    private let dots: [(CGFloat, CGFloat, CGFloat)] = [
        (0.50, 0.06, 0.15), (0.28, 0.14, 0.12), (0.72, 0.12, 0.13),
        (0.40, 0.22, 0.11), (0.62, 0.24, 0.12), (0.16, 0.28, 0.10),
        (0.84, 0.30, 0.10), (0.50, 0.32, 0.11), (0.32, 0.38, 0.09),
        (0.70, 0.40, 0.09)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.5, y: h))
                        path.addQuadCurve(to: CGPoint(x: w * dot.0, y: h * dot.1),
                                          control: CGPoint(x: w * 0.5, y: h * 0.62))
                    }
                    .stroke(BouquetPalette.sage,
                            style: StrokeStyle(lineWidth: max(w * 0.021, 0.8), lineCap: .round))
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

private struct LeafSprig: View {

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(colour: BouquetPalette.stemDeep, headY: 0.12)
                    .frame(width: w, height: h)

                ForEach(0..<4, id: \.self) { index in
                    let y = 0.20 + Double(index) * 0.17
                    Blade(colour: BouquetPalette.leaf)
                        .frame(width: w * 0.58, height: h * 0.18)
                        .rotationEffect(.degrees(-28))
                        .position(x: w * 0.24, y: h * y)

                    Blade(colour: BouquetPalette.leaf)
                        .frame(width: w * 0.58, height: h * 0.18)
                        .rotationEffect(.degrees(28))
                        .scaleEffect(x: -1)
                        .position(x: w * 0.76, y: h * (y + 0.07))
                }
            }
        }
    }
}

private struct Eucalyptus: View {

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Stem(colour: BouquetPalette.sage, headY: 0.08)
                    .frame(width: w, height: h)

                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2)
                              ? BouquetPalette.sage
                              : BouquetPalette.sage.lighter)
                        .frame(width: w * 0.46, height: w * 0.40)
                        .position(x: w * (index.isMultiple(of: 2) ? 0.30 : 0.70),
                                  y: h * (0.10 + Double(index) * 0.10))
                }
            }
        }
    }
}
