//
//  ScrapbookDecorations.swift
//  Ziggy
//
//  The paper bits — tape, torn strips, stars, banners. The things that make a
//  page look made rather than laid out.
//
//  Drawn rather than shipped as images so they stay sharp at any size, cost
//  nothing to download, and can be recoloured.
//
//  They ride in an ordinary sticker element: the payload is a token like
//  "#tape" instead of an emoji, which keeps them on the same footing as
//  everything else on the page — draggable, resizable, turnable, lockable —
//  without a second element kind to thread through the whole editor.
//

import SwiftUI

enum ScrapbookDecoration: String, CaseIterable, Identifiable {

    case washiTape, tornStrip, star, sparkle
    case arrow, banner, paperClip, stamp
    case filmStrip, speechBubble, heart, dashedBox
    case heartOutline, doubleHeart, loopArrow

    var id: String { rawValue }

    /// The payload written into the element.
    var token: String { "#" + rawValue }

    /// Recognises a decoration element, ignoring plain emoji stickers.
    static func from(payload: String) -> ScrapbookDecoration? {
        guard payload.hasPrefix("#") else { return nil }
        return ScrapbookDecoration(rawValue: String(payload.dropFirst()))
    }

    var label: String {
        switch self {
        case .washiTape:    return "Tape"
        case .tornStrip:    return "Torn"
        case .star:         return "Star"
        case .sparkle:      return "Sparkle"
        case .arrow:        return "Arrow"
        case .banner:       return "Banner"
        case .paperClip:    return "Clip"
        case .stamp:        return "Stamp"
        case .filmStrip:    return "Film"
        case .speechBubble: return "Bubble"
        case .heart:        return "Heart"
        case .dashedBox:    return "Frame"
        case .heartOutline: return "Outline"
        case .doubleHeart:  return "Hearts"
        case .loopArrow:    return "Loop"
        }
    }

    /// Whether words can be written on it.
    ///
    /// Only the pieces that are actually paper — tape, a torn strip, a banner
    /// — plus the two that exist to hold something. A star with a date across
    /// it would just look wrong.
    var holdsText: Bool {
        switch self {
        case .washiTape, .tornStrip, .banner, .speechBubble, .stamp, .dashedBox:
            return true
        default:
            return false
        }
    }

    /// Drawn at this size for a sticker of scale 1; the element's own scale
    /// takes it from there.
    var size: CGSize {
        switch self {
        case .washiTape:    return CGSize(width: 110, height: 34)
        case .tornStrip:    return CGSize(width: 120, height: 40)
        case .star:         return CGSize(width: 64, height: 64)
        case .sparkle:      return CGSize(width: 56, height: 56)
        case .arrow:        return CGSize(width: 96, height: 48)
        case .banner:       return CGSize(width: 124, height: 46)
        case .paperClip:    return CGSize(width: 40, height: 76)
        case .stamp:        return CGSize(width: 70, height: 78)
        case .filmStrip:    return CGSize(width: 130, height: 56)
        case .speechBubble: return CGSize(width: 108, height: 74)
        case .heart:        return CGSize(width: 60, height: 54)
        case .dashedBox:    return CGSize(width: 104, height: 84)
        case .heartOutline: return CGSize(width: 62, height: 56)
        case .doubleHeart:  return CGSize(width: 96, height: 70)
        case .loopArrow:    return CGSize(width: 120, height: 62)
        }
    }

    /// Where a picture can be tucked inside, as fractions of the sticker's own
    /// box. Only the pieces that are a container rather than a shape: a stamp,
    /// a frame, a bubble, a length of film.
    var imageWindow: CGRect? {
        switch self {
        case .stamp:        return CGRect(x: 0.16, y: 0.15, width: 0.68, height: 0.70)
        case .dashedBox:    return CGRect(x: 0.05, y: 0.06, width: 0.90, height: 0.88)
        case .speechBubble: return CGRect(x: 0.07, y: 0.07, width: 0.86, height: 0.67)
        case .filmStrip:    return CGRect(x: 0.05, y: 0.27, width: 0.90, height: 0.46)
        default:            return nil
        }
    }

    var holdsImage: Bool { imageWindow != nil }

    /// How round the window's corners are, against its own width.
    var imageCorner: CGFloat {
        switch self {
        case .speechBubble: return 0.09
        case .dashedBox:    return 0.03
        default:            return 0
        }
    }

    /// The caption's point size before the page's own scaling.
    ///
    /// Proportional to the piece it sits on, so words fill a banner and a strip
    /// of tape alike. `widthValue` is the size setting the slider drives — 7 is
    /// what a sticker is created at, and gives the proportions each piece was
    /// drawn for.
    func captionSize(widthValue: Double) -> CGFloat {
        size.height * 0.40 * CGFloat(min(max(widthValue, 1), 24) / 7)
    }

    /// `zoom` is how much bigger than its natural size the piece is being
    /// drawn. Every measurement inside is multiplied by it, so a sticker keeps
    /// its proportions as it grows instead of the stripes, tears and stitching
    /// staying a fixed few points while the shape around them stretches.
    @ViewBuilder
    func view(tint: Color, zoom: CGFloat = 1) -> some View {
        switch self {
        case .washiTape:    WashiTape(tint: tint, zoom: zoom)
        case .tornStrip:    TornStrip(tint: tint, zoom: zoom)
        case .star:         StarBurst(tint: tint, zoom: zoom)
        case .sparkle:      Sparkle(tint: tint, zoom: zoom)
        case .arrow:        HandArrow(tint: tint)
        case .banner:       Banner(tint: tint, zoom: zoom)
        case .paperClip:    PaperClip(tint: tint)
        case .stamp:        Stamp(tint: tint, zoom: zoom)
        case .filmStrip:    FilmStrip(tint: tint, zoom: zoom)
        case .speechBubble: SpeechBubble(tint: tint, zoom: zoom)
        case .heart:        HeartDoodle(tint: tint, zoom: zoom)
        case .dashedBox:    DashedBox(tint: tint, zoom: zoom)
        case .heartOutline: OutlineHeart(tint: tint)
        case .doubleHeart:  DoubleHeart(tint: tint)
        case .loopArrow:    LoopArrow(tint: tint)
        }
    }
}

// MARK: - Tape

private struct WashiTape: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(tint.opacity(0.62))
            .overlay(
                // The faint stripes real washi tape has.
                HStack(spacing: 7 * zoom) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle().fill(.white.opacity(0.35)).frame(width: 3 * zoom)
                    }
                }
            )
            .clipShape(TornEdges(teeth: 7, depth: 3 * zoom))
    }
}

// MARK: - Torn paper

private struct TornStrip: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        TornEdges(teeth: 11, depth: 5 * zoom)
            .fill(tint.opacity(0.9))
            .overlay(
                TornEdges(teeth: 11, depth: 5 * zoom)
                    .stroke(.black.opacity(0.08), lineWidth: zoom)
            )
            .shadow(color: .black.opacity(0.12), radius: 2 * zoom, y: zoom)
    }
}

/// A rectangle with ragged top and bottom, for tape and torn paper.
private struct TornEdges: Shape {

    let teeth: Int
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {

        var path = Path()
        let step = rect.width / CGFloat(max(teeth, 1))

        path.move(to: CGPoint(x: 0, y: depth))

        for tooth in 0...teeth {
            let x = CGFloat(tooth) * step
            let y = tooth.isMultiple(of: 2) ? 0 : depth
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))

        for tooth in stride(from: teeth, through: 0, by: -1) {
            let x = CGFloat(tooth) * step
            let y = tooth.isMultiple(of: 2) ? rect.maxY : rect.maxY - depth
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Star

private struct StarBurst: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        SpikeStar(points: 5, innerRatio: 0.42)
            .fill(tint)
            .overlay(
                SpikeStar(points: 5, innerRatio: 0.42)
                    .stroke(.black.opacity(0.12), lineWidth: zoom)
            )
    }
}

private struct Sparkle: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        ZStack {
            SpikeStar(points: 4, innerRatio: 0.22).fill(tint)
            SpikeStar(points: 4, innerRatio: 0.22)
                .fill(tint.opacity(0.55))
                .scaleEffect(0.5)
                .offset(x: 16 * zoom, y: -14 * zoom)
            SpikeStar(points: 4, innerRatio: 0.22)
                .fill(tint.opacity(0.4))
                .scaleEffect(0.34)
                .offset(x: -17 * zoom, y: 15 * zoom)
        }
    }
}

private struct SpikeStar: Shape {

    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {

        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = .pi / CGFloat(points)

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * step - .pi / 2
            let point = CGPoint(
                x: centre.x + cos(angle) * radius,
                y: centre.y + sin(angle) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Arrow

private struct HandArrow: View {

    let tint: Color

    var body: some View {
        GeometryReader { proxy in

            let width = proxy.size.width
            let height = proxy.size.height

            // Taken off the box rather than fixed, so the pen keeps its weight
            // as the arrow is made bigger.
            let line = max(width * 0.052, 1)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.05, y: height * 0.72))
                    path.addCurve(
                        to: CGPoint(x: width * 0.88, y: height * 0.38),
                        control1: CGPoint(x: width * 0.34, y: height * 0.92),
                        control2: CGPoint(x: width * 0.62, y: height * 0.86)
                    )
                }
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))

                Path { path in
                    path.move(to: CGPoint(x: width * 0.66, y: height * 0.20))
                    path.addLine(to: CGPoint(x: width * 0.92, y: height * 0.36))
                    path.addLine(to: CGPoint(x: width * 0.68, y: height * 0.60))
                }
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Banner

private struct Banner: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        BannerShape()
            .fill(tint)
            .overlay(BannerShape().stroke(.black.opacity(0.12), lineWidth: zoom))
            .shadow(color: .black.opacity(0.14), radius: 3 * zoom, y: 2 * zoom)
    }
}

private struct BannerShape: Shape {

    func path(in rect: CGRect) -> Path {

        var path = Path()
        let notch = rect.width * 0.10

        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: notch, y: rect.midY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Paper clip

private struct PaperClip: View {

    let tint: Color

    var body: some View {
        GeometryReader { proxy in

            let width = proxy.size.width
            let height = proxy.size.height

            Path { path in
                path.move(to: CGPoint(x: width * 0.28, y: height * 0.86))
                path.addLine(to: CGPoint(x: width * 0.28, y: height * 0.22))
                path.addArc(
                    center: CGPoint(x: width * 0.5, y: height * 0.22),
                    radius: width * 0.22,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
                )
                path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.74))
                path.addArc(
                    center: CGPoint(x: width * 0.5, y: height * 0.74),
                    radius: width * 0.22,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false
                )
                path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.34))
            }
            .stroke(tint, style: StrokeStyle(lineWidth: max(width * 0.125, 1),
                                             lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Stamp

private struct Stamp: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        StampShape(bite: 5 * zoom)
            .fill(tint)
            .overlay(
                StampShape(bite: 5 * zoom)
                    .inset(by: 8 * zoom)
                    .stroke(.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: 1.5 * zoom,
                                               dash: [4 * zoom, 3 * zoom]))
            )
            .shadow(color: .black.opacity(0.14), radius: 3 * zoom, y: 2 * zoom)
    }
}

/// A stamp's scalloped edge.
private struct StampShape: InsettableShape {

    /// How deep the perforations bite. Scaled with the stamp, otherwise a big
    /// one comes out with the same tiny nicks a small one has.
    var bite: CGFloat = 5

    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> StampShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {

        let frame = rect.insetBy(dx: inset, dy: inset)
        let bite = max(self.bite, 0.5)
        var path = Path(frame)

        // Bitten out along each edge.
        for x in stride(from: frame.minX, through: frame.maxX, by: bite * 2) {
            path.addEllipse(in: CGRect(x: x - bite / 2, y: frame.minY - bite / 2,
                                       width: bite, height: bite))
            path.addEllipse(in: CGRect(x: x - bite / 2, y: frame.maxY - bite / 2,
                                       width: bite, height: bite))
        }

        for y in stride(from: frame.minY, through: frame.maxY, by: bite * 2) {
            path.addEllipse(in: CGRect(x: frame.minX - bite / 2, y: y - bite / 2,
                                       width: bite, height: bite))
            path.addEllipse(in: CGRect(x: frame.maxX - bite / 2, y: y - bite / 2,
                                       width: bite, height: bite))
        }

        return path
    }
}

// MARK: - Film strip

private struct FilmStrip: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        ZStack {
            Rectangle().fill(tint)

            VStack {
                sprockets
                Spacer()
                sprockets
            }
            .padding(.vertical, 4 * zoom)

            // The three blank cells. A picture placed inside covers exactly
            // this band, so they read as the empty frames until one is.
            HStack(spacing: 4 * zoom) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(.white.opacity(0.22))
                }
            }
            .padding(.vertical, 15 * zoom)
            .padding(.horizontal, 6 * zoom)
        }
    }

    private var sprockets: some View {
        HStack(spacing: 6 * zoom) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5 * zoom)
                    .fill(.white.opacity(0.85))
                    .frame(width: 6 * zoom, height: 5 * zoom)
            }
        }
    }
}

// MARK: - Speech bubble

private struct SpeechBubble: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            RoundedRectangle(cornerRadius: 16 * zoom, style: .continuous)
                .fill(tint)
                .padding(.bottom, 12 * zoom)

            Path { path in
                path.move(to: CGPoint(x: 16 * zoom, y: 0))
                path.addLine(to: CGPoint(x: 40 * zoom, y: 0))
                path.addLine(to: CGPoint(x: 20 * zoom, y: 14 * zoom))
                path.closeSubpath()
            }
            .fill(tint)
            .frame(width: 44 * zoom, height: 14 * zoom)
            .offset(x: 14 * zoom)
        }
        .shadow(color: .black.opacity(0.14), radius: 3 * zoom, y: 2 * zoom)
    }
}

// MARK: - Heart

private struct HeartDoodle: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        DoodleHeart()
            .fill(tint)
            .overlay(DoodleHeart().stroke(.black.opacity(0.12), lineWidth: zoom))
    }
}

struct DoodleHeart: Shape {

    func path(in rect: CGRect) -> Path {

        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.3),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.78),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.55)
        )
        path.addArc(
            center: CGPoint(x: rect.width * 0.25, y: rect.height * 0.3),
            radius: rect.width * 0.25,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.width * 0.75, y: rect.height * 0.3),
            radius: rect.width * 0.25,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.55),
            control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.78)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Drawn by hand

/// A heart sketched rather than filled.
private struct OutlineHeart: View {

    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            DoodleHeart()
                .stroke(tint, style: StrokeStyle(lineWidth: max(proxy.size.width * 0.055, 2),
                                                 lineCap: .round, lineJoin: .round))
        }
    }
}

/// Two of them, one tucked behind the other.
private struct DoubleHeart: View {

    let tint: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height
            let line = max(w * 0.036, 2)

            ZStack {
                DoodleHeart()
                    .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                    .frame(width: w * 0.56, height: h * 0.68)
                    .position(x: w * 0.32, y: h * 0.38)

                DoodleHeart()
                    .stroke(tint.opacity(0.85),
                            style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                    .frame(width: w * 0.46, height: h * 0.56)
                    .position(x: w * 0.70, y: h * 0.66)
            }
        }
    }
}

/// The looping arrow from a marker pen — a curl, then a long sweep to a head.
private struct LoopArrow: View {

    let tint: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height
            let line = max(w * 0.045, 2.5)

            ZStack {

                Path { path in

                    path.move(to: CGPoint(x: w * 0.04, y: h * 0.30))

                    // The loop.
                    path.addCurve(
                        to: CGPoint(x: w * 0.34, y: h * 0.66),
                        control1: CGPoint(x: w * 0.20, y: h * 0.16),
                        control2: CGPoint(x: w * 0.40, y: h * 0.24)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.30, y: h * 0.34),
                        control1: CGPoint(x: w * 0.26, y: h * 0.92),
                        control2: CGPoint(x: w * 0.10, y: h * 0.52)
                    )

                    // Away to the right.
                    path.addCurve(
                        to: CGPoint(x: w * 0.90, y: h * 0.52),
                        control1: CGPoint(x: w * 0.52, y: h * 0.14),
                        control2: CGPoint(x: w * 0.74, y: h * 0.28)
                    )
                }
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: w * 0.70, y: h * 0.30))
                    path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.53))
                    path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.72))
                }
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Dashed frame

private struct DashedBox: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 8 * zoom, style: .continuous)
            .stroke(tint, style: StrokeStyle(lineWidth: 3 * zoom,
                                             dash: [9 * zoom, 7 * zoom]))
    }
}

// MARK: - Torn edges

/// A rectangle with all four edges torn.
///
/// The ragged offsets come from a seeded generator rather than `random()`, so
/// a given photo's tear is the same every time it's drawn — otherwise the edge
/// would crawl on every redraw, and worse, look different on each partner's
/// phone.
struct TornRect: Shape {

    var seed: Int = 1
    var depth: CGFloat = 6
    var teeth: Int = 16

    func path(in rect: CGRect) -> Path {

        var state = UInt64(abs(seed) &* 2_654_435_761 &+ 1)

        func jitter() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((state >> 33) % 1_000) / 1_000 * depth
        }

        var points: [CGPoint] = []
        let across = max(teeth, 4)
        let down = max(Int(CGFloat(across) * rect.height / max(rect.width, 1)), 4)

        for step in 0...across {
            let t = CGFloat(step) / CGFloat(across)
            points.append(CGPoint(x: rect.minX + t * rect.width, y: rect.minY + jitter()))
        }
        for step in 1...down {
            let t = CGFloat(step) / CGFloat(down)
            points.append(CGPoint(x: rect.maxX - jitter(), y: rect.minY + t * rect.height))
        }
        for step in 1...across {
            let t = CGFloat(step) / CGFloat(across)
            points.append(CGPoint(x: rect.maxX - t * rect.width, y: rect.maxY - jitter()))
        }
        for step in 1..<down {
            let t = CGFloat(step) / CGFloat(down)
            points.append(CGPoint(x: rect.minX + jitter(), y: rect.maxY - t * rect.height))
        }

        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// The same idea round a circle, for the torn vignette.
struct TornCircle: Shape {

    var seed: Int = 1
    var depth: CGFloat = 7
    var segments: Int = 64

    func path(in rect: CGRect) -> Path {

        var state = UInt64(abs(seed) &* 40_503 &+ 7)

        func jitter() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((state >> 33) % 1_000) / 1_000 * depth
        }

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var points: [CGPoint] = []

        for step in 0..<segments {
            let angle = CGFloat(step) / CGFloat(segments) * 2 * .pi
            let reach = radius - jitter()
            points.append(CGPoint(x: centre.x + cos(angle) * reach,
                                  y: centre.y + sin(angle) * reach))
        }

        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

// MARK: - Ziggy

/// The pet, as a sticker for the page.
///
/// The app's own artwork rather than something drawn again here — a scrapbook
/// about the two of you should have the same Ziggy in it that the home screen
/// does, in the moods you already know him in.
enum ScrapbookPet {

    static let prefix = "#Z:"

    static func token(_ pose: String) -> String { prefix + pose }

    static func pose(from payload: String) -> String? {
        guard payload.hasPrefix(prefix) else { return nil }
        let rest = String(payload.dropFirst(prefix.count))
        return rest.isEmpty ? nil : rest
    }

    /// Asset name and what to call it. Kept to the moods that suit a page —
    /// the angry ones are for the pet screen, not for a memory.
    static let poses: [(asset: String, label: String)] = [
        ("ziggy_happie",   "Happy"),
        ("ziggy_loveeyes", "Smitten"),
        ("ziggy_sleep",    "Sleepy"),
        ("ziggy_tears",    "Teary"),
        ("ziggu_cry",      "Sad"),
        ("ziggy_angrywithhands", "Huffy")
    ]

    /// Drawn at this size for a sticker of scale 1.
    static let size: CGFloat = 88
}

// MARK: - Cut-out letters

/// The ransom-note alphabet: each character on its own scrap of coloured
/// paper, cut slightly crooked.
enum ScrapbookLetter {

    static let prefix = "#L:"

    static func token(_ character: String) -> String { prefix + character }

    static func character(from payload: String) -> String? {
        guard payload.hasPrefix(prefix) else { return nil }
        let rest = String(payload.dropFirst(prefix.count))
        return rest.isEmpty ? nil : rest
    }

    // Built in steps: the three-way concatenation of mapped strings in one
    // expression is more than the type checker will infer quickly.
    private static let letters: [String] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
    private static let digits: [String] = "0123456789".map(String.init)
    private static let marks: [String] = ["!", "?", "&", "+", "♥"]

    static let characters: [String] = letters + digits + marks

    /// Paper and ink, paired for contrast.
    static let palette: [(paper: Color, ink: Color)] = [
        (Color(red: 0.16, green: 0.20, blue: 0.75), Color(red: 0.93, green: 0.95, blue: 0.42)),
        (Color(red: 0.93, green: 0.95, blue: 0.42), Color(red: 0.16, green: 0.20, blue: 0.75)),
        (Color(red: 0.95, green: 0.76, blue: 0.85), Color(red: 0.16, green: 0.20, blue: 0.75)),
        (Color(red: 0.99, green: 0.91, blue: 0.78), Color(red: 0.18, green: 0.18, blue: 0.20)),
        (Color(red: 0.20, green: 0.22, blue: 0.28), Color(red: 0.99, green: 0.95, blue: 0.88)),
        (Color(red: 0.90, green: 0.35, blue: 0.36), Color(red: 0.99, green: 0.95, blue: 0.88)),
        (Color(red: 0.55, green: 0.78, blue: 0.90), Color(red: 0.16, green: 0.20, blue: 0.75))
    ]

    /// Chosen from the character itself, so a word laid out letter by letter
    /// comes out varied without anyone having to pick colours for each one.
    static func style(for character: String) -> (paper: Color, ink: Color) {
        let seed = character.unicodeScalars.first.map { Int($0.value) } ?? 0
        return palette[seed % palette.count]
    }
}

struct ScrapbookLetterSticker: View {

    let character: String

    /// Built at its final size rather than magnified afterwards. The glyph is
    /// rasterised at whatever point size it is given, so scaling the finished
    /// view blows up those pixels and the letter goes soft.
    var zoom: CGFloat = 1

    /// Chosen colours, where somebody has chosen them. Left off, the letter
    /// picks its own from the character — which is what gives a title spelled
    /// out one scrap at a time its variety without anyone having to.
    var paper: Color?
    var ink: Color?

    private var style: (paper: Color, ink: Color) {
        let automatic = ScrapbookLetter.style(for: character)
        return (paper ?? automatic.paper, ink ?? automatic.ink)
    }

    private var seed: Int {
        character.unicodeScalars.first.map { Int($0.value) } ?? 1
    }

    var body: some View {
        ZStack {
            CutPaper(seed: seed)
                .fill(style.paper)
                .shadow(color: .black.opacity(0.22), radius: 2 * zoom, x: zoom, y: zoom)

            Text(character)
                .font(.system(size: 30 * zoom, weight: .black, design: .serif))
                .foregroundStyle(style.ink)
        }
        .frame(width: 48 * zoom, height: 52 * zoom)
        // A slight lean, again from the character, so a row of them sits like
        // it was stuck down by hand.
        .rotationEffect(.degrees(Double(seed % 9) - 4))
    }
}

/// A quadrilateral cut a bit crooked, like a letter snipped from a magazine.
private struct CutPaper: Shape {

    let seed: Int

    func path(in rect: CGRect) -> Path {

        var state = UInt64(abs(seed) &* 7_919 &+ 13)

        func jitter(_ span: CGFloat) -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((state >> 33) % 1_000) / 1_000 * span
        }

        var path = Path()
        let bite = min(rect.width, rect.height) * 0.16

        path.move(to: CGPoint(x: jitter(bite), y: jitter(bite)))
        path.addLine(to: CGPoint(x: rect.maxX - jitter(bite), y: jitter(bite) * 0.6))
        path.addLine(to: CGPoint(x: rect.maxX - jitter(bite) * 0.5, y: rect.maxY - jitter(bite)))
        path.addLine(to: CGPoint(x: jitter(bite) * 0.7, y: rect.maxY - jitter(bite) * 0.6))
        path.closeSubpath()

        return path
    }
}
