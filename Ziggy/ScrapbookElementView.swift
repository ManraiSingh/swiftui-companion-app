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

        ZStack {
            paper.base

            // A faint vignette gives the paper a bit of body; a flat fill
            // reads as a coloured rectangle rather than a sheet.
            GeometryReader { proxy in
                let unit = max(proxy.size.width, 1) / ScrapbookStyle.pageReferenceWidth
                RadialGradient(
                    colors: [.clear, paper.tint.opacity(0.55)],
                    center: .center,
                    startRadius: 60 * unit,
                    endRadius: 420 * unit
                )
            }

            if paper.ruled {
                GeometryReader { proxy in

                    // Ruling is spaced against the page, like everything else
                    // on it — at a fixed pitch the same sheet came out with
                    // twice as many lines on a book leaf as in the editor.
                    let unit = max(proxy.size.width, 1) / ScrapbookStyle.pageReferenceWidth

                    Path { path in
                        var y = 34 * unit
                        while y < proxy.size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                            y += 30 * unit
                        }
                    }
                    .stroke(paper.tint.opacity(0.75), lineWidth: max(unit, 0.5))
                }
            }

            if paper.dots {
                GeometryReader { proxy in

                    let unit = max(proxy.size.width, 1) / ScrapbookStyle.pageReferenceWidth
                    let pitch = max(30 * unit, 3)
                    let dot = max(2.4 * unit, 0.6)

                    Path { path in
                        var y = pitch / 2
                        while y < proxy.size.height {
                            var x = pitch / 2
                            while x < proxy.size.width {
                                path.addEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2,
                                                           width: dot, height: dot))
                                x += pitch
                            }
                            y += pitch
                        }
                    }
                    .fill(paper.tint.opacity(0.85))
                }
            }

            if paper.grid {
                GeometryReader { proxy in

                    let unit = max(proxy.size.width, 1) / ScrapbookStyle.pageReferenceWidth
                    let pitch = max(26 * unit, 2)

                    Path { path in
                        var x: CGFloat = 0
                        while x < proxy.size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                            x += pitch
                        }
                        var y: CGFloat = 0
                        while y < proxy.size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                            y += pitch
                        }
                    }
                    .stroke(paper.tint.opacity(0.6), lineWidth: max(0.75 * unit, 0.4))
                }
            }
        }
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

    // MARK: Photo

    private var photo: some View {

        let frame = ScrapbookStyle.frame(element.frameIndex)
        let width = canvasSize.width * 0.42 * zoom
        // The round frames crop to a square, otherwise the "circle" comes out
        // an ellipse shaped by whatever the photo happened to be.
        let height = frame == .tornCircle ? width : width / max(element.aspect, 0.2)

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
