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
            RadialGradient(
                colors: [.clear, paper.tint.opacity(0.55)],
                center: .center,
                startRadius: 60,
                endRadius: 420
            )

            if paper.ruled {
                GeometryReader { proxy in
                    Path { path in
                        var y: CGFloat = 34
                        while y < proxy.size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                            y += 30
                        }
                    }
                    .stroke(paper.tint.opacity(0.75), lineWidth: 1)
                }
            }

            if paper.grid {
                GeometryReader { proxy in
                    Path { path in
                        var x: CGFloat = 0
                        while x < proxy.size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                            x += 26
                        }
                        var y: CGFloat = 0
                        while y < proxy.size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                            y += 26
                        }
                    }
                    .stroke(paper.tint.opacity(0.6), lineWidth: 0.75)
                }
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
            .scaleEffect(element.scale)
            .position(
                x: element.x * canvasSize.width,
                y: element.y * canvasSize.height
            )
    }

    @ViewBuilder
    private var content: some View {

        switch element.kind {

        case .photo:
            photo

        case .text:
            Text(element.payload)
                .font(ScrapbookStyle.font(element.fontIndex, size: element.widthValue * 3))
                .foregroundStyle(Color(scrapbookHex: element.colorHex))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: canvasSize.width * 0.8)
                .padding(6)
                .overlay(selectionRing)

        case .sticker:
            Text(element.payload)
                .font(.system(size: element.widthValue * 6))
                .overlay(selectionRing)

        case .stroke:
            strokeShape
        }
    }

    // MARK: Photo

    private var photo: some View {

        let frame = ScrapbookStyle.frame(element.frameIndex)
        let width = canvasSize.width * 0.42
        let height = width / max(element.aspect, 0.2)

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
        .modifier(PhotoFrameModifier(frame: frame, width: width))
        .overlay(selectionRing)
    }

    // MARK: Stroke

    private var strokeShape: some View {

        // A stroke covers the whole page and is positioned at its centre, so
        // the transform that every other element gets has to be undone here —
        // otherwise a stroke drawn at the top of the page jumps when the view
        // repositions it.
        ScrapbookStroke
            .path(for: ScrapbookStroke.decode(element.payload), in: canvasSize)
            .stroke(
                Color(scrapbookHex: element.colorHex),
                style: StrokeStyle(
                    lineWidth: element.widthValue,
                    lineCap: .round,
                    lineJoin: .round
                )
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
                Color.clear.frame(width: width, height: 26)
            }
            .padding(.top, 9)
            .padding(.horizontal, 9)
            .background(Color(red: 0.99, green: 0.98, blue: 0.95))
            .shadow(color: .black.opacity(0.26), radius: 6, y: 3)

        case .white:
            content
                .padding(7)
                .background(Color(red: 0.99, green: 0.98, blue: 0.95))
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)

        case .tape:
            content
                .padding(5)
                .background(Color.white.opacity(0.9))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(red: 0.96, green: 0.87, blue: 0.55).opacity(0.75))
                        .frame(width: 54, height: 20)
                        .rotationEffect(.degrees(-8))
                        .offset(y: -9)
                }
                .overlay(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(Color(red: 0.96, green: 0.87, blue: 0.55).opacity(0.75))
                        .frame(width: 48, height: 18)
                        .rotationEffect(.degrees(12))
                        .offset(x: 10, y: 8)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

        case .film:
            content
                .padding(.vertical, 13)
                .padding(.horizontal, 6)
                .background(Color(red: 0.13, green: 0.12, blue: 0.12))
                .overlay(alignment: .top) { sprockets }
                .overlay(alignment: .bottom) { sprockets }
                .shadow(color: .black.opacity(0.3), radius: 5, y: 3)

        case .rounded:
            content
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.24), radius: 6, y: 3)
        }
    }

    private var sprockets: some View {
        HStack(spacing: 5) {
            ForEach(0..<Int(max(width / 14, 3)), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.85, green: 0.84, blue: 0.82))
                    .frame(width: 6, height: 5)
            }
        }
        .padding(.vertical, 4)
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
