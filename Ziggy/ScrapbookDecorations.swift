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
    case bow, pushPin, flower, butterfly
    case cloud, moonStar, tick, ringScribble
    case squiggle, envelope, plane, crown

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
        case .bow:          return "Bow"
        case .pushPin:      return "Pin"
        case .flower:       return "Flower"
        case .butterfly:    return "Butterfly"
        case .cloud:        return "Cloud"
        case .moonStar:     return "Moon"
        case .tick:         return "Tick"
        case .ringScribble: return "Circle"
        case .squiggle:     return "Squiggle"
        case .envelope:     return "Letter"
        case .plane:        return "Plane"
        case .crown:        return "Crown"
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
        case .arrow:        return CGSize(width: 100, height: 60)
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
        case .bow:          return CGSize(width: 100, height: 70)
        case .pushPin:      return CGSize(width: 60, height: 80)
        case .flower:       return CGSize(width: 80, height: 80)
        case .butterfly:    return CGSize(width: 90, height: 70)
        case .cloud:        return CGSize(width: 100, height: 60)
        case .moonStar:     return CGSize(width: 70, height: 80)
        case .tick:         return CGSize(width: 70, height: 60)
        case .ringScribble: return CGSize(width: 100, height: 76)
        case .squiggle:     return CGSize(width: 120, height: 26)
        case .envelope:     return CGSize(width: 100, height: 70)
        case .plane:        return CGSize(width: 90, height: 70)
        case .crown:        return CGSize(width: 90, height: 62)
        }
    }

    /// Where a picture can be tucked inside, as fractions of the sticker's own
    /// box. Only the pieces that are a container rather than a shape: a stamp,
    /// a frame, a bubble, a length of film.
    /// Every place a picture can go, as fractions of the sticker's own box.
    ///
    /// A list, because a length of film has three frames and putting one
    /// photograph across all of them defeats the point of it being film. The
    /// rest hold one thing and have one window.
    var imageWindows: [CGRect] {
        switch self {

        case .stamp:        return [CGRect(x: 0.16, y: 0.15, width: 0.68, height: 0.70)]
        case .dashedBox:    return [CGRect(x: 0.05, y: 0.06, width: 0.90, height: 0.88)]
        case .speechBubble: return [CGRect(x: 0.07, y: 0.07, width: 0.86, height: 0.67)]

        case .filmStrip:
            // Three frames along the strip, matching the cells drawn behind
            // them. Measured off the same numbers the drawing uses, so a
            // picture lands exactly in a frame rather than near one.
            return (0..<3).map { cell in
                CGRect(
                    x: 0.045 + Double(cell) * 0.3123,
                    y: 0.20,
                    width: 0.2837,
                    height: 0.60
                )
            }

        default: return []
        }
    }

    /// The first window, for everything that only has one.
    var imageWindow: CGRect? { imageWindows.first }

    var holdsImage: Bool { !imageWindows.isEmpty }

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
        case .arrow:        HandArrow(tint: tint, zoom: zoom)
        case .banner:       Banner(tint: tint, zoom: zoom)
        case .paperClip:    PaperClip(tint: tint)
        case .stamp:        Stamp(tint: tint, zoom: zoom)
        case .filmStrip:    FilmStrip(tint: tint, zoom: zoom)
        case .speechBubble: SpeechBubble(tint: tint, zoom: zoom)
        case .heart:        HeartDoodle(tint: tint, zoom: zoom)
        case .dashedBox:    DashedBox(tint: tint, zoom: zoom)
        case .heartOutline: OutlineHeart(tint: tint)
        case .doubleHeart:  DoubleHeart(tint: tint)
        case .loopArrow:    LoopArrow(tint: tint, zoom: zoom)
        case .bow:          Bow(tint: tint)
        case .pushPin:      PushPin(tint: tint)
        case .flower:       FlowerSprig(tint: tint)
        case .butterfly:    Butterfly(tint: tint)
        case .cloud:        CloudPuff(tint: tint)
        case .moonStar:     MoonAndStar(tint: tint)
        case .tick:         TickMark(tint: tint)
        case .ringScribble: ScribbleRing(tint: tint)
        case .squiggle:     Squiggle(tint: tint)
        case .envelope:     Envelope(tint: tint)
        case .plane:        PaperPlane(tint: tint)
        case .crown:        Crown(tint: tint)
        }
    }
}

// MARK: - The finish
//
// What separated these pieces from the bouquet's flowers was never the drawing.
// It was that each one was a single flat colour with a dark hairline round it
// and one hard shadow underneath — which reads as a shape, not as a thing lying
// on paper. Three changes fix that, and they are worth stating because every
// piece below uses them.

extension ShapeStyle where Self == LinearGradient {

    /// A fill that is not perfectly even, because nothing on paper is.
    ///
    /// Light off the top, the colour itself through the middle, a little depth
    /// at the bottom. The range is deliberately narrow — enough to give a shape
    /// a body, not so much that it looks like a button.
    static func paper(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.lighter, tint, tint.deeper],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension View {

    /// Two shadows rather than one.
    ///
    /// A single mid-sized shadow is what makes a shape look like it has an
    /// outline drawn under it. Real things cast a tight, dark contact shadow
    /// where they touch, and a wide faint one from the light in the room.
    /// Having both is most of why something looks like it is sitting on the
    /// page rather than printed into it.
    func paperLift(_ zoom: CGFloat, weight: CGFloat = 1) -> some View {
        self
            .shadow(
                color: .black.opacity(0.16 * weight),
                radius: 1.2 * zoom,
                y: 0.8 * zoom
            )
            .shadow(
                color: .black.opacity(0.13 * weight),
                radius: 5 * zoom,
                y: 3 * zoom
            )
    }
}

/// A piece drawn in a fixed design space and scaled as a whole.
///
/// Laying a shape out in fractions of its own box skews every diagonal by that
/// box's aspect. On a piece twice as wide as it is tall, a line drawn at
/// forty-five degrees arrives on screen at twenty-six — which is how both
/// arrows ended up with heads pointing somewhere their tails were not going.
///
/// Giving the drawing its own square unit keeps angles as drawn, and puts the
/// weight of the pen on the same footing, so a piece enlarged stays the piece
/// it was rather than a thin wire version of it.
private struct Drawn: View {

    let design: CGSize
    let weight: CGFloat
    let tint: Color
    let build: ((CGFloat, CGFloat) -> CGPoint) -> Path

    var body: some View {
        GeometryReader { proxy in

            let unit = min(
                proxy.size.width / design.width,
                proxy.size.height / design.height
            )

            let insetX = (proxy.size.width - design.width * unit) / 2
            let insetY = (proxy.size.height - design.height * unit) / 2

            build { x, y in
                CGPoint(x: insetX + x * unit, y: insetY + y * unit)
            }
            .stroke(
                tint,
                style: StrokeStyle(
                    lineWidth: max(weight * unit, 1),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .paperLift(unit * 1.4, weight: 0.45)
        }
    }
}

// MARK: - Tape

private struct WashiTape: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        ZStack {

            // Tape is translucent, and that is most of why it reads as tape
            // rather than a painted bar — the page carries on underneath it.
            Rectangle().fill(tint.opacity(0.62))

            // No stripes.
            //
            // Vertical bands against an edge that wanders read as corrugation,
            // and the strip came out looking like a folded paper fan rather
            // than something stuck to a page. What actually says tape is that
            // the page shows through it and the light catches along the top,
            // so that is all this is now.
            LinearGradient(
                colors: [
                    .white.opacity(0.26),
                    .white.opacity(0.04),
                    .black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // Barely ragged. Tape is cut from a roll, not torn off a sheet — the
        // long edges are near enough straight, and giving them a torn strip's
        // raggedness was what made a piece of tape read as a folded paper fan.
        .clipShape(TornEdges(teeth: 18, depth: 1.6 * zoom))
        .paperLift(zoom, weight: 0.6)
    }
}


// MARK: - Torn paper

private struct TornStrip: View {

    let tint: Color
    var zoom: CGFloat = 1

    private var edge: TornEdges { TornEdges(teeth: 13, depth: 5.5 * zoom) }

    var body: some View {
        edge
            .fill(tint.opacity(0.88))
            .overlay(
                // The pale lip a tear leaves behind. Paper parts along its
                // fibres and the torn face catches the light, which is what
                // separates a torn strip from one cut with scissors.
                edge
                    .stroke(.white.opacity(0.45), lineWidth: 1.6 * zoom)
                    .blur(radius: 0.5 * zoom)
            )
            .shadow(color: .black.opacity(0.14), radius: 2.5 * zoom, y: 1.2 * zoom)
    }
}

/// A rectangle with ragged top and bottom, for tape and torn paper.
///
/// The raggedness is uneven on purpose. Alternating between two depths gives a
/// perfectly regular zigzag, which is not what a tear looks like — it is what
/// pinking shears look like. Paper tears in runs: a long pull, a short catch,
/// another long one. These two lists are that, fixed rather than random so a
/// strip does not reshuffle itself every time the page is redrawn.
private struct TornEdges: Shape {

    let teeth: Int
    let depth: CGFloat

    private static let upper: [CGFloat] =
        [0.15, 0.85, 0.30, 1.00, 0.20, 0.70, 0.10, 0.95, 0.40, 0.75, 0.25, 0.90, 0.35]

    private static let lower: [CGFloat] =
        [0.90, 0.25, 0.75, 0.15, 0.95, 0.35, 0.80, 0.20, 1.00, 0.30, 0.70, 0.45, 0.85]

    func path(in rect: CGRect) -> Path {

        var path = Path()
        let count = max(teeth, 1)
        let step = rect.width / CGFloat(count)

        // The corners stay put; only the edge between them wanders, so the
        // strip keeps its length however torn it looks.
        path.move(to: CGPoint(x: 0, y: Self.upper[0] * depth))

        for tooth in 0...count {
            let x = min(CGFloat(tooth) * step, rect.maxX)
            let y = Self.upper[tooth % Self.upper.count] * depth
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - Self.lower[0] * depth))

        for tooth in stride(from: count, through: 0, by: -1) {
            let x = min(CGFloat(tooth) * step, rect.maxX)
            let y = rect.maxY - Self.lower[tooth % Self.lower.count] * depth
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
            .fill(.paper(tint))
            .overlay(
                // Rounded rather than sharp. A cut-paper star has soft points
                // — needle-sharp ones are what a vector star looks like.
                SpikeStar(points: 5, innerRatio: 0.42)
                    .stroke(
                        tint.lighter.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2.2 * zoom, lineJoin: .round)
                    )
                    .blendMode(.plusLighter)
            )
            .paperLift(zoom)
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
    var zoom: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in

            // Drawn in a fixed 100 × 60 space and scaled as a whole.
            //
            // It used to be laid out in fractions of its own box, which is
            // twice as wide as it is tall — so every diagonal came out skewed
            // by that ratio. The head was placed at an angle that looked right
            // on paper and arrived on screen pointing somewhere the tail was
            // not going, floating off the end of the sweep as a separate mark.
            // A square unit keeps the two agreeing.
            let unit = min(proxy.size.width / 100, proxy.size.height / 60)
            let line = max(5 * unit, 1)

            let insetX = (proxy.size.width - 100 * unit) / 2
            let insetY = (proxy.size.height - 60 * unit) / 2

            let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: insetX + x * unit, y: insetY + y * unit)
            }

            Path { path in

                // The sweep, arriving at the tip travelling up and to the right.
                path.move(to: point(8, 44))
                path.addCurve(
                    to: point(88, 22),
                    control1: point(30, 58),
                    control2: point(60, 50)
                )

                // Both barbs measured back from that same tip, turned to the
                // direction the sweep arrives from, so the head sits on the
                // end of the line rather than beside it.
                path.move(to: point(69, 28))
                path.addLine(to: point(88, 22))
                path.addLine(to: point(82, 41))
            }
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Banner

private struct Banner: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        BannerShape()
            .fill(.paper(tint))
            .overlay(
                // The crease where a ribbon turns back on itself, which is the
                // one line that stops a banner reading as a flat notched bar.
                HStack {
                    Rectangle().fill(.black.opacity(0.14)).frame(width: 1.4 * zoom)
                    Spacer()
                    Rectangle().fill(.black.opacity(0.14)).frame(width: 1.4 * zoom)
                }
                .padding(.horizontal, 18 * zoom)
                .mask(BannerShape())
            )
            .paperLift(zoom)
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
            // Even-odd, so the circles laid along each edge are bitten *out*
            // of the stamp instead of added to it. Filled the ordinary way
            // they piled up on the boundary and overlapped each other, which
            // is why the edge read as a row of squiggles rather than
            // perforations.
            .fill(.paper(tint), style: FillStyle(eoFill: true))
            .overlay(
                // The plate line a printed stamp carries a little inside its
                // own edge.
                RoundedRectangle(cornerRadius: 2 * zoom, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 1.2 * zoom)
                    .padding(9 * zoom)
            )
            .paperLift(zoom)
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
            Rectangle().fill(.paper(tint))

            VStack {
                sprockets
                Spacer()
                sprockets
            }
            .padding(.vertical, 2.5 * zoom)

            // Three frames, each its own. The borders used to be thick enough
            // that the pictures were a thin band down the middle of a mostly
            // black rectangle — real film is nearly all frame, with just
            // enough edge to carry the sprockets.
            GeometryReader { proxy in

                let width = proxy.size.width
                let height = proxy.size.height
                let cell = width * 0.2837
                let step = width * 0.3123

                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(0.20))
                        .frame(width: cell, height: height * 0.60)
                        .position(
                            x: width * 0.045 + step * Double(index) + cell / 2,
                            y: height * 0.50
                        )
                }
            }
        }
        .paperLift(zoom)
    }

    private var sprockets: some View {
        HStack(spacing: 5 * zoom) {
            ForEach(0..<10, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1 * zoom)
                    .fill(.white.opacity(0.85))
                    .frame(width: 4.5 * zoom, height: 3.5 * zoom)
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
                .fill(.paper(tint))
                .padding(.bottom, 12 * zoom)

            Path { path in
                path.move(to: CGPoint(x: 16 * zoom, y: 0))
                path.addLine(to: CGPoint(x: 40 * zoom, y: 0))
                path.addLine(to: CGPoint(x: 20 * zoom, y: 14 * zoom))
                path.closeSubpath()
            }
            .fill(tint.deeper)
            .frame(width: 44 * zoom, height: 14 * zoom)
            .offset(x: 14 * zoom)
        }
        .paperLift(zoom)
    }
}

// MARK: - Heart

private struct HeartDoodle: View {

    let tint: Color
    var zoom: CGFloat = 1

    var body: some View {
        DoodleHeart()
            .fill(.paper(tint))
            .paperLift(zoom)
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
    var zoom: CGFloat = 1

    var body: some View {
        Drawn(design: CGSize(width: 120, height: 62), weight: 5, tint: tint) { point in

            var path = Path()

            path.move(to: point(8, 22))

            // The loop, crossing over itself the way a pen does.
            path.addCurve(
                to: point(38, 46),
                control1: point(22, 10),
                control2: point(48, 18)
            )
            path.addCurve(
                to: point(34, 24),
                control1: point(30, 64),
                control2: point(12, 40)
            )

            // Then away to the right, arriving almost level.
            path.addCurve(
                to: point(106, 32),
                control1: point(58, 12),
                control2: point(82, 26)
            )

            // Barbs measured back from that tip along the direction the line
            // arrives from, so the head belongs to the stroke it ends.
            path.move(to: point(93, 20))
            path.addLine(to: point(106, 32))
            path.addLine(to: point(89, 37))

            return path
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

// MARK: - The rest of the drawer
//
// All drawn as line work, because that is the register the pieces that already
// looked right were in — a sparkle, a paper clip, an outlined heart. Solid
// silhouettes sit on a page like stickers printed on it; a drawn line sits on
// it like something somebody put there.

private struct Bow: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 100, height: 70), weight: 5, tint: tint) { point in

            var path = Path()

            // Left loop.
            path.move(to: point(48, 32))
            path.addCurve(to: point(10, 14), control1: point(34, 12), control2: point(12, 6))
            path.addCurve(to: point(48, 38), control1: point(6, 26), control2: point(24, 40))

            // Right loop.
            path.move(to: point(52, 32))
            path.addCurve(to: point(90, 14), control1: point(66, 12), control2: point(88, 6))
            path.addCurve(to: point(52, 38), control1: point(94, 26), control2: point(76, 40))

            // The knot.
            path.move(to: point(44, 30))
            path.addCurve(to: point(44, 40), control1: point(38, 34), control2: point(38, 36))
            path.addLine(to: point(56, 40))
            path.addCurve(to: point(56, 30), control1: point(62, 36), control2: point(62, 34))
            path.closeSubpath()

            // Tails.
            path.move(to: point(46, 42))
            path.addCurve(to: point(30, 64), control1: point(42, 52), control2: point(36, 58))
            path.move(to: point(54, 42))
            path.addCurve(to: point(72, 62), control1: point(58, 52), control2: point(66, 56))

            return path
        }
    }
}

private struct PushPin: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 60, height: 80), weight: 5, tint: tint) { point in

            var path = Path()

            let origin = point(11, 6)
            let far = point(49, 26)

            // The cap you press with your thumb.
            path.addEllipse(
                in: CGRect(
                    x: origin.x,
                    y: origin.y,
                    width: far.x - origin.x,
                    height: far.y - origin.y
                )
            )

            // The waist, narrowing to the collar.
            path.move(to: point(21, 25))
            path.addLine(to: point(24, 45))
            path.move(to: point(39, 25))
            path.addLine(to: point(36, 45))
            path.move(to: point(21, 45))
            path.addLine(to: point(39, 45))

            // And the needle, straight down into the page.
            path.move(to: point(30, 45))
            path.addLine(to: point(30, 75))

            return path
        }
    }
}

private struct FlowerSprig: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 80, height: 80), weight: 4.5, tint: tint) { point in

            var path = Path()

            // Five petals around a centre.
            let centre = (x: CGFloat(40), y: CGFloat(32))

            for petal in 0..<5 {
                let angle = CGFloat(petal) * (2 * .pi / 5) - .pi / 2
                let tipX = centre.x + cos(angle) * 24
                let tipY = centre.y + sin(angle) * 24
                let leftX = centre.x + cos(angle - 0.55) * 14
                let leftY = centre.y + sin(angle - 0.55) * 14
                let rightX = centre.x + cos(angle + 0.55) * 14
                let rightY = centre.y + sin(angle + 0.55) * 14

                path.move(to: point(centre.x, centre.y))
                path.addCurve(
                    to: point(tipX, tipY),
                    control1: point(leftX, leftY),
                    control2: point(leftX, leftY)
                )
                path.addCurve(
                    to: point(centre.x, centre.y),
                    control1: point(rightX, rightY),
                    control2: point(rightX, rightY)
                )
            }

            // Stem and a leaf.
            path.move(to: point(40, 40))
            path.addLine(to: point(40, 74))
            path.move(to: point(40, 60))
            path.addCurve(to: point(60, 52), control1: point(48, 62), control2: point(58, 60))

            return path
        }
    }
}

private struct Butterfly: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 90, height: 70), weight: 4.5, tint: tint) { point in

            var path = Path()

            // Upper wings.
            path.move(to: point(45, 34))
            path.addCurve(to: point(10, 10), control1: point(30, 14), control2: point(14, 4))
            path.addCurve(to: point(45, 34), control1: point(2, 22), control2: point(24, 36))

            path.move(to: point(45, 34))
            path.addCurve(to: point(80, 10), control1: point(60, 14), control2: point(76, 4))
            path.addCurve(to: point(45, 34), control1: point(88, 22), control2: point(66, 36))

            // Lower wings.
            path.move(to: point(45, 36))
            path.addCurve(to: point(20, 60), control1: point(32, 44), control2: point(18, 48))
            path.addCurve(to: point(45, 38), control1: point(22, 66), control2: point(38, 50))

            path.move(to: point(45, 36))
            path.addCurve(to: point(70, 60), control1: point(58, 44), control2: point(72, 48))
            path.addCurve(to: point(45, 38), control1: point(68, 66), control2: point(52, 50))

            // Body and feelers.
            path.move(to: point(45, 28))
            path.addLine(to: point(45, 52))
            path.move(to: point(45, 28))
            path.addCurve(to: point(36, 14), control1: point(43, 22), control2: point(38, 18))
            path.move(to: point(45, 28))
            path.addCurve(to: point(54, 14), control1: point(47, 22), control2: point(52, 18))

            return path
        }
    }
}

private struct CloudPuff: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 100, height: 60), weight: 5, tint: tint) { point in

            var path = Path()

            path.move(to: point(20, 46))
            path.addCurve(to: point(16, 26), control1: point(6, 46), control2: point(4, 30))
            path.addCurve(to: point(38, 16), control1: point(20, 16), control2: point(30, 12))
            path.addCurve(to: point(64, 14), control1: point(46, 4), control2: point(60, 4))
            path.addCurve(to: point(82, 28), control1: point(74, 16), control2: point(82, 20))
            path.addCurve(to: point(80, 46), control1: point(94, 32), control2: point(92, 46))
            path.closeSubpath()

            return path
        }
    }
}

private struct MoonAndStar: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 70, height: 80), weight: 4.5, tint: tint) { point in

            var path = Path()

            // A crescent, drawn as two arcs meeting at the horns.
            path.move(to: point(44, 12))
            path.addCurve(to: point(44, 68), control1: point(14, 20), control2: point(14, 60))
            path.addCurve(to: point(44, 12), control1: point(32, 56), control2: point(32, 24))
            path.closeSubpath()

            // A small star off its shoulder.
            path.move(to: point(56, 20))
            path.addLine(to: point(59, 27))
            path.addLine(to: point(66, 30))
            path.addLine(to: point(59, 33))
            path.addLine(to: point(56, 40))
            path.addLine(to: point(53, 33))
            path.addLine(to: point(46, 30))
            path.addLine(to: point(53, 27))
            path.closeSubpath()

            return path
        }
    }
}

private struct TickMark: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 70, height: 60), weight: 7, tint: tint) { point in

            var path = Path()

            path.move(to: point(8, 32))
            path.addCurve(to: point(26, 48), control1: point(14, 38), control2: point(21, 44))
            path.addCurve(to: point(62, 10), control1: point(38, 34), control2: point(50, 20))

            return path
        }
    }
}

private struct ScribbleRing: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 100, height: 76), weight: 4.5, tint: tint) { point in

            var path = Path()

            // Round something, twice, the way a pen does when it means it.
            path.move(to: point(24, 20))
            path.addCurve(to: point(88, 40), control1: point(58, 4), control2: point(96, 16))
            path.addCurve(to: point(20, 52), control1: point(80, 66), control2: point(30, 74))
            path.addCurve(to: point(30, 16), control1: point(8, 36), control2: point(12, 20))
            path.addCurve(to: point(90, 34), control1: point(60, 10), control2: point(94, 14))

            return path
        }
    }
}

private struct Squiggle: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 120, height: 26), weight: 5, tint: tint) { point in

            var path = Path()

            path.move(to: point(6, 16))
            path.addCurve(to: point(34, 16), control1: point(14, 2), control2: point(26, 30))
            path.addCurve(to: point(62, 16), control1: point(42, 2), control2: point(54, 30))
            path.addCurve(to: point(90, 16), control1: point(70, 2), control2: point(82, 30))
            path.addCurve(to: point(114, 14), control1: point(98, 2), control2: point(108, 22))

            return path
        }
    }
}

private struct Envelope: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 100, height: 70), weight: 4.5, tint: tint) { point in

            var path = Path()

            path.addRoundedRect(
                in: CGRect(
                    origin: point(8, 10),
                    size: CGSize(
                        width: point(84, 0).x - point(0, 0).x,
                        height: point(0, 50).y - point(0, 0).y
                    )
                ),
                cornerSize: CGSize(width: 4, height: 4)
            )

            // The flap.
            path.move(to: point(8, 14))
            path.addLine(to: point(50, 42))
            path.addLine(to: point(92, 14))

            return path
        }
    }
}

private struct PaperPlane: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 90, height: 70), weight: 4.5, tint: tint) { point in

            var path = Path()

            path.move(to: point(6, 32))
            path.addLine(to: point(84, 8))
            path.addLine(to: point(52, 62))
            path.addLine(to: point(42, 40))
            path.closeSubpath()

            // The crease, which is the whole reason it reads as folded paper.
            path.move(to: point(42, 40))
            path.addLine(to: point(84, 8))

            return path
        }
    }
}

private struct Crown: View {

    let tint: Color

    var body: some View {
        Drawn(design: CGSize(width: 90, height: 62), weight: 4.5, tint: tint) { point in

            var path = Path()

            path.move(to: point(10, 50))
            path.addLine(to: point(6, 14))
            path.addLine(to: point(28, 32))
            path.addLine(to: point(45, 8))
            path.addLine(to: point(62, 32))
            path.addLine(to: point(84, 14))
            path.addLine(to: point(80, 50))
            path.closeSubpath()

            return path
        }
    }
}
