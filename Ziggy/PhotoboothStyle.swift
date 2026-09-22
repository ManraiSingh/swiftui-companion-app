//
//  PhotoboothStyle.swift
//  Ziggy
//
//  What a strip is made of: the look of each photo, the paper it is printed
//  on, and the backdrop that can stand behind the two of you.
//
//  Kept apart from the camera and from the session on purpose. Everything in
//  here is a pure function from images to an image, which is what makes the
//  strip checkable without a lens — the simulator has no camera, but it can
//  render a whole strip from two stand-in photos and show exactly what would
//  come out of the booth.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Film

/// The look applied to each photo, before it is printed on the strip.
enum PhotoboothFilm: String, CaseIterable, Identifiable {

    case original, noir, warm, faded, vivid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Original"
        case .noir:     return "Noir"
        case .warm:     return "Warm"
        case .faded:    return "Faded"
        case .vivid:    return "Vivid"
        }
    }

    /// The swatch shown in the picker, so a row of choices reads as a row of
    /// looks rather than a row of words.
    var swatch: [Color] {
        switch self {
        case .original: return [Color(white: 0.85), Color(white: 0.65)]
        case .noir:     return [Color(white: 0.92), Color(white: 0.12)]
        case .warm:     return [Color(red: 0.96, green: 0.82, blue: 0.62),
                                Color(red: 0.62, green: 0.40, blue: 0.28)]
        case .faded:    return [Color(red: 0.90, green: 0.88, blue: 0.86),
                                Color(red: 0.66, green: 0.66, blue: 0.70)]
        case .vivid:    return [Color(red: 1.00, green: 0.62, blue: 0.45),
                                Color(red: 0.36, green: 0.52, blue: 0.92)]
        }
    }
}

// MARK: - Paper

/// The strip itself — the colour it is printed on and the ink of its footer.
enum PhotoboothPaper: String, CaseIterable, Identifiable {

    case classic, cream, film, midnight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic:  return "Classic"
        case .cream:    return "Cream"
        case .film:     return "Film"
        case .midnight: return "Midnight"
        }
    }

    var background: UIColor {
        switch self {
        case .classic:  return UIColor(white: 1.0, alpha: 1)
        case .cream:    return UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
        case .film:     return UIColor(red: 0.13, green: 0.12, blue: 0.11, alpha: 1)
        case .midnight: return UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        }
    }

    var ink: UIColor {
        switch self {
        case .classic, .cream: return UIColor(white: 0.10, alpha: 1)
        case .film, .midnight: return UIColor(white: 0.93, alpha: 1)
        }
    }

    /// Film gets sprocket holes down both edges — the detail that makes the
    /// first of the two reference strips read as film rather than as a photo
    /// with a dark border.
    var hasSprockets: Bool { self == .film }
}

// MARK: - Backdrop

/// What stands behind the two of you, once you have been cut out of your own
/// room. `.asIs` leaves the real background alone.
enum PhotoboothBackdrop: String, CaseIterable, Identifiable {

    case asIs, blush, mint, dusk, paper, noirWall

    var id: String { rawValue }

    var label: String {
        switch self {
        case .asIs:     return "As is"
        case .blush:    return "Blush"
        case .mint:     return "Mint"
        case .dusk:     return "Dusk"
        case .paper:    return "Paper"
        case .noirWall: return "Studio"
        }
    }

    /// Two stops, drawn top to bottom behind the subject.
    nonisolated var colours: [UIColor]? {
        switch self {
        case .asIs:  return nil
        case .blush: return [UIColor(red: 1.00, green: 0.82, blue: 0.84, alpha: 1),
                             UIColor(red: 0.96, green: 0.66, blue: 0.72, alpha: 1)]
        case .mint:  return [UIColor(red: 0.80, green: 0.94, blue: 0.88, alpha: 1),
                             UIColor(red: 0.60, green: 0.82, blue: 0.78, alpha: 1)]
        case .dusk:  return [UIColor(red: 0.42, green: 0.38, blue: 0.62, alpha: 1),
                             UIColor(red: 0.20, green: 0.18, blue: 0.34, alpha: 1)]
        case .paper: return [UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1),
                             UIColor(red: 0.88, green: 0.85, blue: 0.79, alpha: 1)]
        case .noirWall: return [UIColor(white: 0.30, alpha: 1),
                                UIColor(white: 0.12, alpha: 1)]
        }
    }

    var swatch: [Color] {
        guard let c = colours else { return [Color(white: 0.8), Color(white: 0.6)] }
        return c.map(Color.init)
    }
}

// MARK: - The darkroom

/// Applies film to a photo and prints a finished strip.
///
/// One shared CIContext: building one per call is the expensive part of Core
/// Image, and a strip runs this a dozen times over.
enum PhotoboothDarkroom {

    nonisolated static let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: Film

    static func apply(_ film: PhotoboothFilm, to image: UIImage) -> UIImage {

        guard film != .original,
              let input = CIImage(image: image) else { return image }

        let output: CIImage?

        switch film {

        case .original:
            output = input

        case .noir:
            let f = CIFilter.photoEffectNoir()
            f.inputImage = input
            output = f.outputImage.flatMap { boost(contrast: 1.12, on: $0) }

        case .warm:
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = input
            sepia.intensity = 0.55
            output = sepia.outputImage.flatMap { warm($0, by: 320) }

        case .faded:
            let f = CIFilter.photoEffectFade()
            f.inputImage = input
            output = f.outputImage

        case .vivid:
            let f = CIFilter.vibrance()
            f.inputImage = input
            f.amount = 0.9
            output = f.outputImage.flatMap { boost(contrast: 1.06, on: $0) }
        }

        guard let out = output,
              let cg = context.createCGImage(out, from: out.extent)
        else { return image }

        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func boost(contrast: Float, on image: CIImage) -> CIImage? {
        let f = CIFilter.colorControls()
        f.inputImage = image
        f.contrast = contrast
        f.saturation = 1
        f.brightness = 0
        return f.outputImage
    }

    private static func warm(_ image: CIImage, by kelvin: Float) -> CIImage? {
        let f = CIFilter.temperatureAndTint()
        f.inputImage = image
        f.neutral = CIVector(x: CGFloat(6500 + kelvin), y: 0)
        f.targetNeutral = CIVector(x: 6500, y: 0)
        return f.outputImage
    }

    // MARK: Printing

    /// One photo of the pair, drawn as `mine | theirs` inside a single frame.
    ///
    /// Each half is drawn filling its side, centre-cropped. The two of you
    /// were photographed in different rooms on different phones, so anything
    /// that preserved both aspect ratios would print two mismatched boxes
    /// with gaps — the crop is what makes one frame out of two photos.
    static func pairFrame(
        mine: UIImage?,
        theirs: UIImage?,
        size: CGSize,
        film: PhotoboothFilm,
        divider: UIColor
    ) -> UIImage {

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in

            UIColor(white: 0.16, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let half = CGSize(width: size.width / 2, height: size.height)

            draw(mine, film: film,
                 in: CGRect(origin: .zero, size: half))

            draw(theirs, film: film,
                 in: CGRect(origin: CGPoint(x: half.width, y: 0), size: half))

            // The seam between the two halves, so the pair reads as two
            // photos side by side rather than one wide photo.
            divider.setFill()
            ctx.fill(CGRect(x: half.width - 0.75, y: 0, width: 1.5, height: size.height))
        }
    }

    /// Centre-crop-and-fill, the way `scaledToFill` behaves on screen.
    private static func draw(_ image: UIImage?, film: PhotoboothFilm, in rect: CGRect) {

        guard let image else { return }

        let filtered = apply(film, to: image)

        let scale = max(rect.width / filtered.size.width,
                        rect.height / filtered.size.height)
        let drawn = CGSize(width: filtered.size.width * scale,
                           height: filtered.size.height * scale)

        let origin = CGPoint(
            x: rect.midX - drawn.width / 2,
            y: rect.midY - drawn.height / 2
        )

        UIGraphicsGetCurrentContext()?.saveGState()
        UIBezierPath(rect: rect).addClip()
        filtered.draw(in: CGRect(origin: origin, size: drawn))
        UIGraphicsGetCurrentContext()?.restoreGState()
    }

    /// The finished strip: every frame printed down one piece of paper.
    static func printStrip(
        pairs: [(mine: UIImage?, theirs: UIImage?)],
        film: PhotoboothFilm,
        paper: PhotoboothPaper,
        caption: String,
        frameWidth: CGFloat = 900
    ) -> UIImage {

        let margin = frameWidth * 0.055
        let gap = frameWidth * 0.030
        let photoWidth = frameWidth - margin * 2
        let photoHeight = photoWidth * 0.66          // a pair frame is wide
        let footer = frameWidth * 0.13

        let height = margin
            + CGFloat(pairs.count) * photoHeight
            + CGFloat(max(pairs.count - 1, 0)) * gap
            + footer

        let size = CGSize(width: frameWidth, height: height)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in

            paper.background.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            if paper.hasSprockets { drawSprockets(in: size, margin: margin) }

            var y = margin

            for pair in pairs {

                let rect = CGRect(x: margin, y: y, width: photoWidth, height: photoHeight)

                let frame = pairFrame(
                    mine: pair.mine,
                    theirs: pair.theirs,
                    size: CGSize(width: photoWidth, height: photoHeight),
                    film: film,
                    divider: paper.background
                )
                frame.draw(in: rect)

                y += photoHeight + gap
            }

            drawFooter(caption, in: size, footer: footer, paper: paper)
        }
    }

    private static func drawSprockets(in size: CGSize, margin: CGFloat) {

        let holeW = margin * 0.42
        let holeH = holeW * 1.35
        let pitch = holeH * 2.1
        let inset = (margin - holeW) / 2

        UIColor(white: 0.92, alpha: 1).setFill()

        var y = pitch * 0.5
        while y < size.height - pitch * 0.5 {
            for x in [inset, size.width - inset - holeW] {
                UIBezierPath(
                    roundedRect: CGRect(x: x, y: y, width: holeW, height: holeH),
                    cornerRadius: holeW * 0.28
                ).fill()
            }
            y += pitch
        }
    }

    private static func drawFooter(
        _ caption: String,
        in size: CGSize,
        footer: CGFloat,
        paper: PhotoboothPaper
    ) {

        let text = caption as NSString
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: footer * 0.30, weight: .heavy),
            .foregroundColor: paper.ink,
            .paragraphStyle: style,
            .kern: footer * 0.02
        ]

        let box = CGRect(
            x: 0,
            y: size.height - footer + footer * 0.22,
            width: size.width,
            height: footer * 0.5
        )
        text.draw(in: box, withAttributes: attrs)
    }
}
