//
//  ScrapbookElementView.swift
//  Ziggy
//
//  Draws one element, and the page it sits on. Used by both the read-only
//  preview in the book and the editor, so a page can't look like one thing
//  while you're browsing and another while you're editing.
//

import SwiftUI

// MARK: - Decoded photo cache

/// Base64 to UIImage is expensive enough that doing it inside `body` makes
/// dragging stutter. Keyed by element id, capped so a long book doesn't sit
/// on every photo it has ever shown.
final class ScrapbookImageCache {

    static let shared = ScrapbookImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 60
    }

    /// Drops a cached decode, for when an element's picture is swapped out
    /// under the same id.
    func forget(_ key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func image(for key: String, base64: String) -> UIImage? {

        if let hit = cache.object(forKey: key as NSString) { return hit }

        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }

        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

// MARK: - Page background

struct ScrapbookPaper: View {

    let paperIndex: Int

    var body: some View {

        let paper = ScrapbookStyle.paper(paperIndex)

        // One Canvas rather than a stack of GeometryReaders and Paths.
        //
        // Every pattern used to be its own GeometryReader with its own Path,
        // and a page is drawn six times over in an open book — the ruling
        // alone was hundreds of line segments re-laid out on each pass. A
        // Canvas draws straight into one layer and never lays anything out.
        Canvas(rendersAsynchronously: false) { context, size in

            let unit = max(size.width, 1) / ScrapbookStyle.pageReferenceWidth
            let whole = CGRect(origin: .zero, size: size)

            context.fill(Path(whole), with: .color(paper.base))

            context.fill(
                Path(whole),
                with: .radialGradient(
                    Gradient(colors: [.clear, paper.tint.opacity(0.55)]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 60 * unit,
                    endRadius: 420 * unit
                )
            )

            if paper.ruled { rule(&context, size, unit, paper) }
            if paper.grid { grid(&context, size, unit, paper) }
            if paper.dots { dots(&context, size, unit, paper) }
            if paper.news { news(&context, size, unit, paper) }
            if paper.aged { age(&context, size, unit, paper) }
        }
    }

    private func rule(_ context: inout GraphicsContext, _ size: CGSize,
                      _ unit: CGFloat, _ paper: ScrapbookStyle.Paper) {

        var path = Path()
        var y = 34 * unit
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += 30 * unit
        }
        context.stroke(path, with: .color(paper.tint.opacity(0.75)),
                       lineWidth: max(unit, 0.5))
    }

    private func grid(_ context: inout GraphicsContext, _ size: CGSize,
                      _ unit: CGFloat, _ paper: ScrapbookStyle.Paper) {

        let pitch = max(26 * unit, 2)
        var path = Path()

        var x: CGFloat = 0
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += pitch
        }
        var y: CGFloat = 0
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += pitch
        }
        context.stroke(path, with: .color(paper.tint.opacity(0.6)),
                       lineWidth: max(0.75 * unit, 0.4))
    }

    private func dots(_ context: inout GraphicsContext, _ size: CGSize,
                      _ unit: CGFloat, _ paper: ScrapbookStyle.Paper) {

        let pitch = max(30 * unit, 3)
        let dot = max(2.4 * unit, 0.6)
        var path = Path()

        var y = pitch / 2
        while y < size.height {
            var x = pitch / 2
            while x < size.width {
                path.addEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2,
                                           width: dot, height: dot))
                x += pitch
            }
            y += pitch
        }
        context.fill(path, with: .color(paper.tint.opacity(0.85)))
    }

    /// Newsprint: two columns of type with a rule between them, and a
    /// heavier line standing in for a headline.
    private func news(_ context: inout GraphicsContext, _ size: CGSize,
                      _ unit: CGFloat, _ paper: ScrapbookStyle.Paper) {

        let margin = 22 * unit
        let gutter = 14 * unit
        let column = (size.width - margin * 2 - gutter) / 2
        let line = 5.5 * unit
        let ink = paper.tint.opacity(0.5)

        // The masthead.
        context.fill(
            Path(CGRect(x: margin, y: 24 * unit, width: size.width - margin * 2, height: 9 * unit)),
            with: .color(paper.tint.opacity(0.75))
        )

        var text = Path()

        for side in 0..<2 {

            let left = margin + CGFloat(side) * (column + gutter)
            var y = 48 * unit
            var row = side * 7

            while y < size.height - 20 * unit {

                // Ragged right, so it reads as set type rather than bars.
                let fill = [1.0, 0.94, 0.88, 0.98, 0.72, 0.91][row % 6]
                text.addRect(CGRect(x: left, y: y, width: column * fill, height: line * 0.42))

                y += line
                row += 1
            }
        }

        context.fill(text, with: .color(ink))

        var rule = Path()
        rule.move(to: CGPoint(x: size.width / 2, y: 44 * unit))
        rule.addLine(to: CGPoint(x: size.width / 2, y: size.height - 20 * unit))
        context.stroke(rule, with: .color(paper.tint.opacity(0.4)), lineWidth: max(unit, 0.5))
    }

    /// Aged paper: soft blotches and a darkened edge.
    private func age(_ context: inout GraphicsContext, _ size: CGSize,
                     _ unit: CGFloat, _ paper: ScrapbookStyle.Paper) {

        // Fixed positions rather than random, so a page does not mottle
        // differently every time it is drawn.
        let blots: [(CGFloat, CGFloat, CGFloat)] = [
            (0.12, 0.18, 0.22), (0.78, 0.11, 0.17), (0.62, 0.44, 0.26),
            (0.22, 0.68, 0.20), (0.86, 0.74, 0.24), (0.44, 0.90, 0.18)
        ]

        for blot in blots {
            let radius = blot.2 * size.width
            let rect = CGRect(x: blot.0 * size.width - radius / 2,
                              y: blot.1 * size.height - radius / 2,
                              width: radius, height: radius)
            context.fill(Path(ellipseIn: rect), with: .color(paper.tint.opacity(0.16)))
        }

        context.stroke(
            Path(CGRect(origin: .zero, size: size).insetBy(dx: -size.width * 0.12,
                                                           dy: -size.height * 0.12)),
            with: .color(paper.tint.opacity(0.5)),
            lineWidth: size.width * 0.22
        )
    }
}

// MARK: - A stroke

/// One drawn line, through a chosen brush.
///
/// Shared by the finished strokes on the page and the one still under the
/// finger, so the line you are drawing looks exactly like the line you end up
/// with rather than turning into the right pen only once you let go.
struct ScrapbookStrokeView: View {

    let points: [CGPoint]
    let canvasSize: CGSize
    let colorHex: String
    let width: Double
    let brushIndex: Int

    var body: some View {

        let brush = ScrapbookStyle.brush(brushIndex)
        let path = ScrapbookStroke.path(for: points, in: canvasSize)
        let ink = Color(scrapbookHex: colorHex)
        let cap: CGLineCap = brush.flatCap ? .butt : .round

        // The stroke's shape is already in page proportions; its thickness
        // was not, so a line drawn in the editor came out heavy in the book.
        let unit = max(canvasSize.width, 1) / ScrapbookStyle.pageReferenceWidth
        let thickness = width * brush.widthScale * unit

        ZStack {

            path.stroke(
                ink.opacity(brush.opacity),
                style: StrokeStyle(lineWidth: thickness, lineCap: cap, lineJoin: .round)
            )

            // A second, thinner pass nudged off the first gives the broken
            // edge a crayon or pencil leaves. Cheaper and steadier than
            // scattering the points themselves, which would make a stroke
            // look different every time it was redrawn.
            if brush.grainy {
                path
                    .stroke(
                        ink.opacity(brush.opacity * 0.45),
                        style: StrokeStyle(lineWidth: thickness * 0.55,
                                           lineCap: cap, lineJoin: .round)
                    )
                    .offset(x: 1.2 * unit, y: 1.2 * unit)
            }
        }
    }
}

// MARK: - One element

struct ScrapbookElementView: View {

    let element: ScrapbookElement
    let canvasSize: CGSize
    let isSelected: Bool

    var body: some View {

        content
            .rotationEffect(.degrees(element.rotation))
            .scaleEffect(renderScale)
            .position(
                x: element.x * canvasSize.width,
                y: element.y * canvasSize.height
            )
    }

    /// Only strokes are magnified after the fact.
    ///
    /// `scaleEffect` is a render-time transform: it blows up the layer that
    /// has already been drawn. That softens anything made of glyphs — a photo,
    /// but equally text, an emoji or a cut-out letter, since a glyph is
    /// rasterised at the point size it was given. Everything but a stroke now
    /// builds itself at its final size so it is drawn sharp to begin with.
    ///
    /// A stroke is a path across the whole page rather than a box with a size,
    /// so scaling its geometry is the transform's job and stays crisp.
    private var renderScale: Double {
        element.kind == .stroke ? element.scale : 1
    }

    /// The element's size multiplier, bounded the way the gesture bounds it.
    private var zoom: CGFloat {
        CGFloat(min(max(element.scale, 0.2), 4))
    }

    /// How big this page is drawn, against the width sizes are quoted at.
    ///
    /// Multiplying every point measurement by this is what makes a page look
    /// the same in the book as it did in the editor, rather than everything
    /// but the photos appearing blown up on the smaller leaf.
    private var unit: CGFloat {
        max(canvasSize.width, 1) / ScrapbookStyle.pageReferenceWidth
    }

    /// A point measurement, taken relative to the page.
    private func onPage(_ value: CGFloat) -> CGFloat { value * zoom * unit }

    @ViewBuilder
    private var content: some View {

        switch element.kind {

        case .photo:
            photo

        case .text:
            Text(element.payload)
                .font(ScrapbookStyle.font(element.fontIndex,
                                          size: onPage(element.widthValue * 3)))
                .foregroundStyle(Color(scrapbookHex: element.colorHex))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                // The wrap width grows with the type, otherwise enlarging a
                // caption just breaks it onto more and more lines.
                .frame(maxWidth: canvasSize.width * 0.8 * zoom)
                .padding(onPage(6))
                .overlay(selectionRing)

        case .sticker:
            // A sticker is either an emoji or one of the drawn paper bits,
            // told apart by the "#" the decoration tokens carry.
            if let character = ScrapbookLetter.character(from: element.payload) {
                ScrapbookLetterSticker(character: character, zoom: zoom * unit)
                    .overlay(selectionRing)
            } else if let decoration = ScrapbookDecoration.from(payload: element.payload) {
                decoration.view(tint: Color(scrapbookHex: element.colorHex))
                    .frame(width: onPage(decoration.size.width),
                           height: onPage(decoration.size.height))
                    .overlay { caption(on: decoration) }
                    .overlay(selectionRing)
            } else {
                Text(element.payload)
                    .font(.system(size: onPage(element.widthValue * 6)))
                    .overlay(selectionRing)
            }

        case .stroke:
            strokeShape
        }
    }

    /// Words written on a paper sticker.
    ///
    /// The ink is picked against the paper's own colour rather than fixed, so
    /// a date on dark tape stays readable without anyone choosing a colour for
    /// it.
    @ViewBuilder
    private func caption(on decoration: ScrapbookDecoration) -> some View {

        if decoration.holdsText, !element.caption.isEmpty {

            let paperIsDark = ScrapbookStyle.isDark(hex: element.colorHex)

            Text(element.caption)
                .font(ScrapbookStyle.font(element.fontIndex,
                                          size: onPage(decoration.size.height * 0.40)))
                .foregroundStyle(paperIsDark
                                 ? Color(red: 0.98, green: 0.97, blue: 0.94)
                                 : Color(red: 0.20, green: 0.17, blue: 0.14))
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, onPage(decoration.size.width * 0.08))
                // The bubble's tail hangs below, so its words sit higher.
                .padding(.bottom, decoration == .speechBubble
                         ? onPage(decoration.size.height * 0.18) : 0)
        }
    }

    // MARK: Photo

    private var photo: some View {

        let frame = ScrapbookStyle.frame(element.frameIndex)
        let width = canvasSize.width * 0.42 * zoom
        // The round frames crop to a square, otherwise the "circle" comes out
        // an ellipse shaped by whatever the photo happened to be.
        let height = (frame == .tornCircle || frame == .heart)
            ? width
            : width / max(element.aspect, 0.2)

        return Group {
            if let image = ScrapbookImageCache.shared.image(for: element.id, base64: element.payload) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: width, height: height)
                    .overlay(ProgressView())
            }
        }
        .modifier(
            PhotoFrameModifier(
                frame: frame,
                width: width,
                paper: Color(scrapbookHex: element.frameColorHex),
                onDarkPaper: ScrapbookStyle.isDark(hex: element.frameColorHex),
                zoom: zoom * unit
            )
        )
        .overlay(selectionRing)
    }

    // MARK: Stroke

    private var strokeShape: some View {

        // A stroke covers the whole page and is positioned at its centre, so
        // the transform that every other element gets has to be undone here —
        // otherwise a stroke drawn at the top of the page jumps when the view
        // repositions it.
        ScrapbookStrokeView(
            points: ScrapbookStroke.decode(element.payload),
            canvasSize: canvasSize,
            colorHex: element.colorHex,
            width: element.widthValue,
            brushIndex: element.brushIndex
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .offset(
            x: canvasSize.width * (0.5 - element.x),
            y: canvasSize.height * (0.5 - element.y)
        )
    }

    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(
                    Color(red: 0.29, green: 0.47, blue: 0.95),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                )
                .padding(-5)
        }
    }
}

// MARK: - Frames

private struct PhotoFrameModifier: ViewModifier {

    let frame: ScrapbookStyle.Frame
    let width: CGFloat
    let paper: Color

    /// Whether the frame's paper is dark, so the details cut into it — film
    /// sprockets, the polaroid's shadow — stay legible whichever colour it has
    /// been changed to.
    let onDarkPaper: Bool

    /// The photo's size multiplier. Every measurement in here is scaled by it,
    /// so a frame keeps its proportions as the picture grows instead of the
    /// border staying a fixed few points and thinning away to nothing.
    let zoom: CGFloat

    private func scaled(_ value: CGFloat) -> CGFloat { value * zoom }

    private var detail: Color {
        onDarkPaper ? .white.opacity(0.85) : .black.opacity(0.55)
    }

    func body(content: Content) -> some View {

        switch frame {

        case .none:
            content
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

        case .polaroid:
            // The strip below the picture needs both dimensions pinned.
            // `Spacer` grows vertically and a bare `Color.clear` grows
            // horizontally, and either one on its own inflates the frame well
            // past the photo it is supposed to sit under.
            VStack(spacing: 0) {
                content
                Color.clear.frame(width: width, height: scaled(26))
            }
            .padding(.top, scaled(9))
            .padding(.horizontal, scaled(9))
            .background(paper)
            .shadow(color: .black.opacity(0.26), radius: 6, y: 3)

        case .white:
            content
                .padding(scaled(7))
                .background(paper)
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)

        case .tape:
            content
                .padding(scaled(5))
                .background(paper)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(red: 0.96, green: 0.87, blue: 0.55).opacity(0.75))
                        .frame(width: scaled(54), height: scaled(20))
                        .rotationEffect(.degrees(-8))
                        .offset(y: scaled(-9))
                }
                .overlay(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(Color(red: 0.96, green: 0.87, blue: 0.55).opacity(0.75))
                        .frame(width: scaled(48), height: scaled(18))
                        .rotationEffect(.degrees(12))
                        .offset(x: scaled(10), y: scaled(8))
                }
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

        case .film:
            content
                .padding(.vertical, scaled(13))
                .padding(.horizontal, scaled(6))
                .background(paper)
                .overlay(alignment: .top) { sprockets }
                .overlay(alignment: .bottom) { sprockets }
                .shadow(color: .black.opacity(0.3), radius: 5, y: 3)

        case .rounded:
            content
                .clipShape(RoundedRectangle(cornerRadius: scaled(14), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: scaled(14), style: .continuous)
                        .strokeBorder(paper, lineWidth: scaled(3))
                )
                .shadow(color: .black.opacity(0.24), radius: 6, y: 3)

        case .torn:
            // Two tears, not one: the photo's own ragged edge sitting on a
            // slightly larger scrap of paper, which is what gives the ripped
            // white border its depth.
            content
                .clipShape(TornRect(seed: 3, depth: scaled(5)))
                .padding(scaled(9))
                .background(
                    TornRect(seed: 11, depth: scaled(7)).fill(paper)
                )
                .shadow(color: .black.opacity(0.24), radius: 5, y: 3)

        case .tornCircle:
            content
                .clipShape(TornCircle(seed: 5, depth: scaled(5)))
                .padding(scaled(11))
                .background(
                    TornCircle(seed: 17, depth: scaled(8)).fill(paper)
                )
                .shadow(color: .black.opacity(0.26), radius: 7, y: 4)

        case .camera:
            // The picture is the camera's screen: body around it, a lens and
            // a shutter above, dials down the side.
            content
                .padding(scaled(9))
                .padding(.top, scaled(30))
                .padding(.trailing, scaled(30))
                .background(
                    RoundedRectangle(cornerRadius: scaled(14), style: .continuous)
                        .fill(paper)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: scaled(4), style: .continuous)
                        .fill(detail.opacity(0.85))
                        .frame(width: scaled(34), height: scaled(13))
                        .padding(.leading, scaled(12))
                        .padding(.top, scaled(9))
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(detail.opacity(0.9))
                        .frame(width: scaled(11), height: scaled(11))
                        .padding(.trailing, scaled(11))
                        .padding(.top, scaled(10))
                }
                .overlay(alignment: .trailing) {
                    VStack(spacing: scaled(7)) {
                        Circle()
                            .fill(detail.opacity(0.85))
                            .frame(width: scaled(17), height: scaled(17))
                        RoundedRectangle(cornerRadius: scaled(2))
                            .fill(detail.opacity(0.6))
                            .frame(width: scaled(13), height: scaled(6))
                        RoundedRectangle(cornerRadius: scaled(2))
                            .fill(detail.opacity(0.6))
                            .frame(width: scaled(13), height: scaled(6))
                    }
                    .padding(.trailing, scaled(7))
                    .padding(.top, scaled(26))
                }
                .shadow(color: .black.opacity(0.28), radius: scaled(6), y: scaled(3))

        case .heart:
            content
                .clipShape(FrameHeart())
                .padding(scaled(7))
                .background(FrameHeart().fill(paper))
                .shadow(color: .black.opacity(0.24), radius: scaled(5), y: scaled(3))

        case .reel:
            // A length of movie tape: perforations top and bottom, and the
            // strip running past the picture on both sides.
            content
                .padding(.vertical, scaled(16))
                .padding(.horizontal, scaled(18))
                .background(paper)
                .overlay(alignment: .top) { perforations }
                .overlay(alignment: .bottom) { perforations }
                .overlay(alignment: .leading) {
                    Rectangle().fill(detail.opacity(0.25)).frame(width: scaled(1.5))
                        .padding(.leading, scaled(14))
                }
                .overlay(alignment: .trailing) {
                    Rectangle().fill(detail.opacity(0.25)).frame(width: scaled(1.5))
                        .padding(.trailing, scaled(14))
                }
                .shadow(color: .black.opacity(0.3), radius: scaled(5), y: scaled(3))

        case .arch:
            content
                .clipShape(ArchShape())
                .padding(scaled(8))
                .background(ArchShape().fill(paper))
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
        }
    }

    /// How many sprocket holes fit.
    ///
    /// Counted off the unscaled width so the holes get bigger with the frame
    /// rather than multiplying into a dotted line — but guarded, because a
    /// page is briefly laid out at zero width, which made this divide by zero
    /// and then trap converting an infinite Double to Int.
    private var sprocketCount: Int {
        let raw = width / max(zoom, 0.0001) / 14
        guard raw.isFinite else { return 3 }
        return min(max(Int(raw), 3), 40)
    }

    /// Squared perforations, closer together than the film frame's.
    private var perforations: some View {
        HStack(spacing: scaled(4)) {
            ForEach(0..<min(max(Int(width / max(zoom, 0.0001) / 11), 4), 40), id: \.self) { _ in
                RoundedRectangle(cornerRadius: scaled(1))
                    .fill(detail)
                    .frame(width: scaled(5), height: scaled(7))
            }
        }
        .padding(.vertical, scaled(4))
    }

    private var sprockets: some View {
        HStack(spacing: scaled(5)) {
            ForEach(0..<sprocketCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: scaled(1.5))
                    .fill(detail)
                    .frame(width: scaled(6), height: scaled(5))
            }
        }
        .padding(.vertical, scaled(4))
    }
}

/// A heart to crop a photo into.
private struct FrameHeart: Shape {

    func path(in rect: CGRect) -> Path {

        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.30),
            control1: CGPoint(x: rect.width * 0.16, y: rect.height * 0.80),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.56)
        )
        path.addArc(
            center: CGPoint(x: rect.width * 0.25, y: rect.height * 0.30),
            radius: rect.width * 0.25,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.width * 0.75, y: rect.height * 0.30),
            radius: rect.width * 0.25,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.56),
            control2: CGPoint(x: rect.width * 0.84, y: rect.height * 0.80)
        )
        path.closeSubpath()

        return path
    }
}

/// A rounded arch — a rectangle with a domed top.
private struct ArchShape: Shape {

    func path(in rect: CGRect) -> Path {

        var path = Path()
        let dome = min(rect.width / 2, rect.height * 0.42)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + dome))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + dome),
            radius: dome,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - A frame, shown on its own

/// One frame drawn around a neutral sample rather than a real photograph.
///
/// The picker used to preview each frame on the actual picture, which sounded
/// helpful and looked poor — nine copies of the same photo competing with the
/// thing you were trying to compare. A plain sample lets the frame be the
/// only thing that changes between tiles.
struct ScrapbookFrameSample: View {

    let frame: ScrapbookStyle.Frame
    let paperHex: String
    var width: CGFloat = 108

    var body: some View {

        // Round frames crop square; the rest keep a portrait photo's shape.
        let height = frame == .tornCircle ? width : width * 1.2

        sample
            .frame(width: width, height: height)
            .modifier(
                PhotoFrameModifier(
                    frame: frame,
                    width: width,
                    paper: Color(scrapbookHex: paperHex),
                    onDarkPaper: ScrapbookStyle.isDark(hex: paperHex),
                    // A page draws a photo about 160pt wide, which is what the
                    // frame's trim is proportioned for.
                    zoom: width / 160
                )
            )
    }

    /// A stand-in picture: sky, hill, sun. Enough to read as a photograph
    /// without being anyone's.
    private var sample: some View {

        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .bottom) {

                LinearGradient(
                    colors: [Color(red: 0.62, green: 0.78, blue: 0.90),
                             Color(red: 0.80, green: 0.88, blue: 0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color(red: 0.99, green: 0.87, blue: 0.62))
                    .frame(width: w * 0.20, height: w * 0.20)
                    .position(x: w * 0.72, y: h * 0.24)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.52))
                    path.addLine(to: CGPoint(x: w * 0.66, y: h))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.55, green: 0.68, blue: 0.55))

                Path { path in
                    path.move(to: CGPoint(x: w * 0.42, y: h))
                    path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 1.05, y: h))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.44, green: 0.58, blue: 0.47))
            }
        }
    }
}

// MARK: - A whole page, read only

/// The page as it appears when browsing the book. No gestures — tapping
/// anywhere is the caller's business.
struct ScrapbookPagePreview: View {

    let page: ScrapbookPage
    let elements: [ScrapbookElement]

    var body: some View {

        GeometryReader { proxy in
            ZStack {
                ScrapbookPaper(paperIndex: page.paperIndex)

                ForEach(elements) { element in
                    ScrapbookElementView(
                        element: element,
                        canvasSize: proxy.size,
                        isSelected: false
                    )
                }

                if elements.isEmpty {
                    emptyHint
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var emptyHint: some View {

        let ink = ScrapbookStyle.defaultInk(onPaper: page.paperIndex)

        return VStack(spacing: 12) {

            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(ink.opacity(0.55))

            Text("This page is waiting")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(ink.opacity(0.75))

            Text("Tap to start scrapping")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(ink.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
        }
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
    }
}
