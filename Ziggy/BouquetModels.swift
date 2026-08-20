//
//  BouquetModels.swift
//  Ziggy
//
//  A bouquet is composed privately and then given.
//
//  Unlike a scrapbook page, this is not co-edited — the whole point is that
//  the other person doesn't see it until it arrives. So it stays local while
//  it is being made and is written once, as a single document, when it is
//  sent. Stems are a handful of numbers each, so the whole thing sits well
//  inside Firestore's document limit with no images involved.
//

import SwiftUI

/// One flower standing in a bouquet.
struct BouquetStem: Identifiable, Equatable {

    var id: String = UUID().uuidString
    var kind: Int
    var x: Double = 0.5
    var y: Double = 0.5

    /// Turned about its cut end, so a stem fans out from the tie rather than
    /// spinning on the spot. Bounded: past this the head swings clear of the
    /// bouquet altogether and reads as a flower lying beside it.
    var rotation: Double = 0
    var scale: Double = 1
    var z: Int = 0

    /// Empty means the flower's own colour.
    var tintHex: String = ""

    var flower: BouquetFlower { BouquetFlower(rawValue: kind) ?? .whiteDaisy }

    var tint: Color? {
        tintHex.isEmpty ? nil : Color(scrapbookHex: tintHex)
    }

    /// Where every stem's cut end sits, as a fraction of the canvas.
    ///
    /// Fixed rather than per-stem. Letting a base be dragged is what let a
    /// flower be pulled clean out of the bouquet, and what made a tilted stem
    /// swing its stalk outside the wrap. A stem is aimed, not moved.
    static let tie = CGPoint(x: 0.5, y: 0.80)
    static let maxLean: Double = 52
}

/// The note tucked in among the flowers.
struct BouquetLetter: Equatable {

    var text: String = ""
    var fontIndex: Int = 0
    var x: Double = 0.78
    var y: Double = 0.72
    var rotation: Double = -6
    var scale: Double = 1

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct Bouquet: Identifiable, Equatable {

    var id: String = UUID().uuidString
    var stems: [BouquetStem] = []
    var wrapIndex: Int = 0
    var ribbonHex: String = "#B0413E"
    var letter: BouquetLetter = BouquetLetter()

    var sender: String = ""
    var senderDeviceID: String = ""
    var sentAt: Date = Date()

    var isEmpty: Bool { stems.isEmpty }

    var wrap: (name: String, paper: Color, shade: Color) {
        BouquetPalette.wraps[min(max(wrapIndex, 0), BouquetPalette.wraps.count - 1)]
    }

    // MARK: Firestore

    var payload: [String: Any] {
        [
            "stems": stems.map { stem in
                [
                    "id": stem.id,
                    "k": stem.kind,
                    "x": stem.x,
                    "y": stem.y,
                    "r": stem.rotation,
                    "s": stem.scale,
                    "z": stem.z,
                    "t": stem.tintHex
                ] as [String: Any]
            },
            "wrap": wrapIndex,
            "ribbon": ribbonHex,
            "letterText": letter.text,
            "letterFont": letter.fontIndex,
            "letterX": letter.x,
            "letterY": letter.y,
            "letterRotation": letter.rotation,
            "letterScale": letter.scale
        ]
    }

    static func from(id: String, data: [String: Any], sentAt: Date) -> Bouquet {

        var bouquet = Bouquet(id: id)

        bouquet.stems = (data["stems"] as? [[String: Any]] ?? []).map { raw in
            BouquetStem(
                id: raw["id"] as? String ?? UUID().uuidString,
                kind: raw["k"] as? Int ?? 0,
                x: raw["x"] as? Double ?? 0.5,
                y: raw["y"] as? Double ?? 0.5,
                rotation: raw["r"] as? Double ?? 0,
                scale: raw["s"] as? Double ?? 1,
                z: raw["z"] as? Int ?? 0,
                tintHex: raw["t"] as? String ?? ""
            )
        }

        bouquet.wrapIndex = data["wrap"] as? Int ?? 0
        bouquet.ribbonHex = data["ribbon"] as? String ?? "#B0413E"

        bouquet.letter = BouquetLetter(
            text: data["letterText"] as? String ?? "",
            fontIndex: data["letterFont"] as? Int ?? 0,
            x: data["letterX"] as? Double ?? 0.78,
            y: data["letterY"] as? Double ?? 0.72,
            rotation: data["letterRotation"] as? Double ?? -6,
            scale: data["letterScale"] as? Double ?? 1
        )

        bouquet.sender = data["sender"] as? String ?? ""
        bouquet.senderDeviceID = data["senderDeviceID"] as? String ?? ""
        bouquet.sentAt = sentAt

        return bouquet
    }
}

// MARK: - Where everything sits

/// One place that decides the shape of a bouquet, so the view that draws it
/// and the builder that aims stems into it can never disagree.
///
/// The wrap is anchored to the *bottom* of the canvas rather than placed at a
/// fraction of its height plus an offset. The old way added a fixed amount to
/// a proportional position, so on a short canvas the point of the cone ran
/// clean off the bottom edge.
enum BouquetLayout {

    static func stage(_ size: CGSize) -> CGFloat {
        min(size.width, size.height * 0.78)
    }

    static func unit(_ size: CGSize) -> CGFloat {
        stage(size) / 198
    }

    static func wrapSize(_ size: CGSize) -> CGSize {
        let s = stage(size)
        return CGSize(width: s * 0.42, height: s * 0.48)
    }

    static func wrapCentre(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2,
                y: size.height * 0.97 - wrapSize(size).height / 2)
    }

    /// Where every cut end meets — up inside the wrap, not at its point.
    static func tie(_ size: CGSize) -> CGPoint {
        let centre = wrapCentre(size)
        return CGPoint(x: centre.x, y: centre.y - wrapSize(size).height * 0.26)
    }
}

// MARK: - The wrap

/// The paper cone the stems disappear into, and the ribbon tied round it.
///
/// Drawn as two folded sheets rather than one shape: a real wrap has a seam
/// down the middle where the paper crosses over itself, and without it the
/// cone reads as a flat triangle.
struct BouquetWrap: View {

    let paper: Color
    let shade: Color
    let ribbon: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {

                WrapSheet()
                    .fill(shade)
                    .frame(width: w, height: h)
                    .scaleEffect(x: -1)

                WrapSheet()
                    .fill(paper)
                    .frame(width: w, height: h)

                // The tie sits where the cone is still wide. Lower down it
                // narrows to a point, and a bow tied there came out pinched
                // into a little red blob.
                Capsule()
                    .fill(ribbon.opacity(0.92))
                    .frame(width: w * 0.70, height: h * 0.070)
                    .position(x: w * 0.5, y: h * 0.46)

                RibbonBow(colour: ribbon)
                    .frame(width: w * 0.52, height: h * 0.26)
                    .position(x: w * 0.5, y: h * 0.50)
            }
        }
    }
}

private struct WrapSheet: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.16))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.52, y: rect.maxY),
            control: CGPoint(x: rect.width * 0.86, y: rect.height * 0.74)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.width * 0.16, y: rect.height * 0.62)
        )
        path.closeSubpath()
        return path
    }
}

private struct RibbonBow: View {

    let colour: Color

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {

                // Tails first, so the loops and knot sit over them.
                TailShape()
                    .fill(colour.opacity(0.8))
                    .frame(width: w * 0.16, height: h * 0.66)
                    .rotationEffect(.degrees(-14))
                    .position(x: w * 0.42, y: h * 0.70)

                TailShape()
                    .fill(colour.opacity(0.9))
                    .frame(width: w * 0.16, height: h * 0.66)
                    .rotationEffect(.degrees(14))
                    .position(x: w * 0.58, y: h * 0.70)

                // Two loops, clearly apart, with the knot between them.
                Ellipse()
                    .fill(colour)
                    .frame(width: w * 0.40, height: h * 0.46)
                    .rotationEffect(.degrees(-26))
                    .position(x: w * 0.27, y: h * 0.34)

                Ellipse()
                    .fill(colour)
                    .frame(width: w * 0.40, height: h * 0.46)
                    .rotationEffect(.degrees(26))
                    .position(x: w * 0.73, y: h * 0.34)

                Circle()
                    .fill(colour.opacity(0.8))
                    .frame(width: w * 0.17, height: w * 0.17)
                    .position(x: w * 0.5, y: h * 0.34)
            }
        }
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                          control: CGPoint(x: rect.minX, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.86))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control: CGPoint(x: rect.maxX, y: rect.height * 0.45))
        path.closeSubpath()
        return path
    }
}

// MARK: - The whole thing, drawn

/// A bouquet at any size — used by the builder, the showcase, the arrival
/// popup and the activity row, so all four can never disagree about what a
/// bouquet looks like.
struct BouquetView: View {

    let bouquet: Bouquet

    /// The letter is hidden while it is being dragged by the builder, and
    /// shown everywhere else.
    var showsLetter: Bool = true

    var body: some View {
        GeometryReader { proxy in

            let size = proxy.size
            let unit = BouquetLayout.unit(size)
            let tie = BouquetLayout.tie(size)

            ZStack {

                // Every cut end at the tie, every stem turned about it. The
                // frame is placed so its bottom lands on the tie, then the
                // rotation pivots there — which is what makes the stalks
                // gather into the wrap instead of splaying below it.
                ForEach(bouquet.stems.sorted { $0.z < $1.z }) { stem in

                    let sh = stem.flower.size.height * stem.scale * unit

                    stem.flower.view(tint: stem.tint)
                        .frame(
                            width: stem.flower.size.width * stem.scale * unit,
                            height: sh
                        )
                        .rotationEffect(.degrees(stem.rotation), anchor: .bottom)
                        .position(x: tie.x, y: tie.y - sh / 2)
                }

                // No flowers, no wrapping. An empty cone hanging in the
                // middle of the builder looks like a mistake.
                if !bouquet.stems.isEmpty {
                    BouquetWrap(
                        paper: bouquet.wrap.paper,
                        shade: bouquet.wrap.shade,
                        ribbon: Color(scrapbookHex: bouquet.ribbonHex)
                    )
                    .frame(width: BouquetLayout.wrapSize(size).width,
                           height: BouquetLayout.wrapSize(size).height)
                    .position(BouquetLayout.wrapCentre(size))
                }

                if showsLetter, !bouquet.letter.isEmpty {
                    BouquetEnvelope(ribbon: Color(scrapbookHex: bouquet.ribbonHex))
                        .frame(width: 62 * bouquet.letter.scale * unit,
                               height: 45 * bouquet.letter.scale * unit)
                        .rotationEffect(.degrees(bouquet.letter.rotation))
                        .position(x: bouquet.letter.x * size.width,
                                  y: bouquet.letter.y * size.height)
                }
            }
        }
    }
}
