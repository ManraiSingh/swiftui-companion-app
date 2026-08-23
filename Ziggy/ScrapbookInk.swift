//
//  ScrapbookInk.swift
//  Ziggy
//
//  The page's drawing, done by PencilKit.
//
//  The scrapbook used to keep its own strokes: a list of points per stroke,
//  drawn as a rounded polyline. That works, and it is why every stroke could
//  have its own layer — but a polyline has no pressure, no taper and no grain,
//  so a "brush" was only ever a thickness, and rubbing out could not do better
//  than drop whole strokes or cut them into pieces.
//
//  PencilKit has all of that already, and it is what the doodle screen draws
//  with, so using it here makes the two feel like the same app rather than two
//  apps that both let you draw.
//
//  The trade is that a page has one drawing rather than a stroke apiece. Every
//  mark shares a layer, the way it does on the doodle screen. Photos, text and
//  stickers are unaffected — they stay separate things that can be stacked.
//

import PencilKit
import SwiftUI

enum ScrapbookInk {

    /// Marks a stroke element as holding a PencilKit drawing rather than the
    /// list of points the old ones carry, so a page made before this still
    /// draws instead of coming up blank.
    static let prefix = "PK:"

    static func encode(_ drawing: PKDrawing) -> String {
        prefix + drawing.dataRepresentation().base64EncodedString()
    }

    static func decode(_ payload: String) -> PKDrawing? {

        guard payload.hasPrefix(prefix) else { return nil }

        guard
            let data = Data(base64Encoded: String(payload.dropFirst(prefix.count))),
            let drawing = try? PKDrawing(data: data)
        else { return nil }

        return drawing
    }

    static func holdsInk(_ payload: String) -> Bool {
        payload.hasPrefix(prefix)
    }

    /// The drawing as a picture, for the times the page is not being drawn on.
    ///
    /// Rendered at the size it is being shown at rather than once and scaled,
    /// because PencilKit rasterises at the size you ask for and a magnified
    /// bitmap is exactly as soft as it sounds.
    static func image(_ drawing: PKDrawing, size: CGSize) -> UIImage? {

        guard size.width > 1, size.height > 1 else { return nil }

        return drawing.image(
            from: CGRect(origin: .zero, size: size),
            scale: UIScreen.main.scale
        )
    }
}

/// PencilKit's canvas, sized to the page and see-through.
///
/// The doodle's own wrapper is opaque and paints a background, which is right
/// there and wrong here — the paper, the photographs and everything already
/// stuck down have to show through the glass you are drawing on.
struct ScrapbookInkCanvas: UIViewRepresentable {

    let canvas: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {

        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false

        // A fixed page, never scrolled or zoomed. Left as a scroll view it
        // keeps a pinch recogniser that fights with pinching a sticker.
        canvas.isScrollEnabled = false
        canvas.bouncesZoom = false

        return canvas
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.backgroundColor = .clear
        view.isOpaque = false
    }
}

extension ScrapbookInk {

    /// The doodle screen's pens, in the order the scrapbook's brush picker
    /// already shows them.
    ///
    /// The two lists were written months apart and happen to match exactly —
    /// pen, fountain, marker, pencil, monoline, watercolour, crayon — so the
    /// picker needed no rearranging to start driving the real thing. What was
    /// underneath it before were seven ways of varying the width and opacity
    /// of one round line, which is a fair imitation of a pen and nothing like
    /// a pencil or a crayon.
    static let inks: [PKInkingTool.InkType] = [
        .pen, .fountainPen, .marker, .pencil, .monoline, .watercolor, .crayon
    ]

    static func ink(_ index: Int) -> PKInkingTool.InkType {
        inks[((index % inks.count) + inks.count) % inks.count]
    }
}
