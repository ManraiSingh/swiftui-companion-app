//
//  ScrapbookOrnaments.swift
//  Ziggy
//
//  The objects that share the shelf with the books. Drawn rather than
//  shipped as images so they stay crisp at any size and cost nothing to
//  load, and outlined so they sit in the same world as the spines.
//

import SwiftUI

// MARK: - Building blocks

/// A filled shape with the house outline around it.
struct Outlined<S: Shape>: View {

    let shape: S
    let fill: Color
    var line: CGFloat = 2

    var body: some View {
        shape
            .fill(fill)
            .overlay(shape.stroke(ScrapbookStyle.outline, lineWidth: line))
    }
}

extension Outlined where S == RoundedRectangle {
    init(radius: CGFloat, fill: Color, line: CGFloat = 2) {
        self.init(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                  fill: fill, line: line)
    }
}

// MARK: - The set

enum ScrapbookOrnament: Int, CaseIterable, Identifiable {

    case flowerVase, bookStack, framedArt, tableLamp
    case camera, bunny, pottedPlant, heartFrame
    case ziggyToy, teacup, candle, cassette
    case alarmClock, polaroids, jarOfHearts, recordPlayer

    var id: Int { rawValue }

    /// What a shelf comes furnished with.
    ///
    /// Deliberately not everything: the stock arrangement puts one of each on
    /// the shelves, and sixteen of them would leave no room for the books.
    /// The rest are there to be chosen — a shelf you have arranged yourself is
    /// never overwritten by this.
    static let defaultKinds: [ScrapbookOrnament] = [
        .flowerVase, .bookStack, .framedArt, .tableLamp,
        .camera, .bunny, .pottedPlant, .heartFrame
    ]

    var label: String {
        switch self {
        case .flowerVase:   return "Flowers"
        case .bookStack:    return "Books"
        case .framedArt:    return "Print"
        case .tableLamp:    return "Lamp"
        case .camera:       return "Camera"
        case .bunny:        return "Bunny"
        case .pottedPlant:  return "Plant"
        case .heartFrame:   return "Photo"
        case .ziggyToy:     return "Ziggy"
        case .teacup:       return "Tea"
        case .candle:       return "Candle"
        case .cassette:     return "Tape"
        case .alarmClock:   return "Clock"
        case .polaroids:    return "Snaps"
        case .jarOfHearts:  return "Jar"
        case .recordPlayer: return "Record"
        }
    }

    /// Roughly how much shelf each one needs.
    var width: CGFloat {
        switch self {
        case .flowerVase:   return 62
        case .bookStack:    return 72
        case .framedArt:    return 60
        case .tableLamp:    return 58
        case .camera:       return 66
        case .bunny:        return 62
        case .pottedPlant:  return 68
        case .heartFrame:   return 46
        case .ziggyToy:     return 64
        case .teacup:       return 56
        case .candle:       return 44
        case .cassette:     return 70
        case .alarmClock:   return 56
        case .polaroids:    return 64
        case .jarOfHearts:  return 52
        case .recordPlayer: return 72
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .flowerVase:   FlowerVase()
        case .bookStack:    BookStack()
        case .framedArt:    FramedArt()
        case .tableLamp:    TableLamp()
        case .camera:       CameraOrnament()
        case .bunny:        BunnyPlush()
        case .pottedPlant:  PottedPlant()
        case .heartFrame:   HeartFrame()
        case .ziggyToy:     ZiggyToy()
        case .teacup:       Teacup()
        case .candle:       Candle()
        case .cassette:     Cassette()
        case .alarmClock:   AlarmClock()
        case .polaroids:    PolaroidStack()
        case .jarOfHearts:  JarOfHearts()
        case .recordPlayer: RecordPlayer()
        }
    }
}

// MARK: - Flowers in a vase

private struct FlowerVase: View {

    private let stems: [(CGFloat, CGFloat)] = [(-17, 16), (0, 4), (17, 20)]

    var body: some View {

        VStack(spacing: -3) {

            ZStack {
                ForEach(Array(stems.enumerated()), id: \.offset) { _, stem in

                    Path { path in
                        path.move(to: CGPoint(x: 31 + stem.0 * 0.35, y: 62))
                        path.addQuadCurve(
                            to: CGPoint(x: 31 + stem.0, y: stem.1 + 12),
                            control: CGPoint(x: 31 + stem.0 * 0.5, y: 38)
                        )
                    }
                    .stroke(ScrapbookStyle.leafStem, lineWidth: 2)

                    Flower()
                        .frame(width: 26, height: 26)
                        .position(x: 31 + stem.0, y: stem.1 + 4)
                }

                // A couple of leaves off the middle stem.
                Leaf()
                    .frame(width: 15, height: 9)
                    .position(x: 22, y: 44)
                Leaf()
                    .frame(width: 15, height: 9)
                    .scaleEffect(x: -1)
                    .position(x: 41, y: 50)
            }
            .frame(width: 62, height: 68)

            Outlined(shape: VaseBody(), fill: ScrapbookStyle.cream)
                .frame(width: 46, height: 42)
        }
    }
}

private struct Flower: View {

    var body: some View {
        ZStack {
            ForEach(0..<5) { index in
                Ellipse()
                    .fill(ScrapbookStyle.blossom)
                    .overlay(Ellipse().stroke(ScrapbookStyle.outline, lineWidth: 1.6))
                    .frame(width: 10, height: 15)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
            Circle()
                .fill(ScrapbookStyle.mustard)
                .overlay(Circle().stroke(ScrapbookStyle.outline, lineWidth: 1.4))
                .frame(width: 7, height: 7)
        }
    }
}

private struct Leaf: View {
    var body: some View {
        Outlined(shape: LeafShape(), fill: ScrapbookStyle.sage, line: 1.6)
    }
}

private struct VaseBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.20, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.80, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.86, y: rect.maxY),
            control1: CGPoint(x: rect.width * 0.96, y: rect.height * 0.42),
            control2: CGPoint(x: rect.width * 0.90, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.14, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.20, y: rect.minY),
            control1: CGPoint(x: rect.width * 0.10, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.04, y: rect.height * 0.42)
        )
        path.closeSubpath()
        return path
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Books lying flat

private struct BookStack: View {

    private let layers: [(CGFloat, Color)] = [
        (68, ScrapbookStyle.mustard),
        (72, ScrapbookStyle.terracotta),
        (64, ScrapbookStyle.cream)
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                Outlined(radius: 3, fill: layer.1)
                    .frame(width: layer.0, height: 13)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(ScrapbookStyle.outline.opacity(0.45))
                            .frame(width: 1.4)
                            .padding(.vertical, 3)
                            .padding(.trailing, 6)
                    }
            }
        }
    }
}

// MARK: - Framed print

private struct FramedArt: View {

    var body: some View {

        Outlined(radius: 4, fill: ScrapbookStyle.terracotta)
            .frame(width: 58, height: 78)
            .overlay {
                Outlined(radius: 2, fill: ScrapbookStyle.paperWhite, line: 1.6)
                    .frame(width: 40, height: 60)
                    .overlay { Sprig() }
            }
    }
}

/// The botanical stem inside the frame.
private struct Sprig: View {

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 20, y: 52))
                path.addLine(to: CGPoint(x: 20, y: 8))
            }
            .stroke(ScrapbookStyle.leafStem, lineWidth: 1.6)

            ForEach(0..<4) { row in
                let y = 16 + CGFloat(row) * 10
                Leaf()
                    .frame(width: 14, height: 8)
                    .rotationEffect(.degrees(-24))
                    .position(x: 12, y: y)
                Leaf()
                    .frame(width: 14, height: 8)
                    .rotationEffect(.degrees(24))
                    .position(x: 28, y: y + 4)
            }
        }
        .frame(width: 40, height: 60)
    }
}

// MARK: - Lamp

private struct TableLamp: View {

    var body: some View {
        VStack(spacing: -2) {

            Outlined(shape: LampShade(), fill: ScrapbookStyle.mustard)
                .frame(width: 56, height: 38)

            Rectangle()
                .fill(ScrapbookStyle.cream)
                .overlay(
                    HStack {
                        Rectangle().fill(ScrapbookStyle.outline).frame(width: 2)
                        Spacer()
                        Rectangle().fill(ScrapbookStyle.outline).frame(width: 2)
                    }
                )
                .frame(width: 13, height: 16)

            // Same taper as the shade — narrow at the neck, spreading to the
            // foot, so the lamp sits rather than balances on a point.
            Outlined(shape: LampShade(), fill: ScrapbookStyle.cream)
                .frame(width: 38, height: 22)
        }
    }
}

private struct LampShade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.26, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.74, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Camera

private struct CameraOrnament: View {

    var body: some View {

        ZStack(alignment: .top) {

            Outlined(radius: 7, fill: ScrapbookStyle.terracotta)
                .frame(width: 64, height: 42)
                .overlay {
                    Circle()
                        .fill(ScrapbookStyle.deepBrown)
                        .overlay(Circle().stroke(ScrapbookStyle.outline, lineWidth: 2))
                        .overlay(
                            Circle()
                                .fill(ScrapbookStyle.cream.opacity(0.85))
                                .frame(width: 7, height: 7)
                                .offset(x: -3, y: -3)
                        )
                        .frame(width: 22, height: 22)
                }
                .overlay(alignment: .topLeading) {
                    Outlined(radius: 2, fill: ScrapbookStyle.mustard, line: 1.6)
                        .frame(width: 12, height: 7)
                        .padding(.leading, 7)
                        .padding(.top, 6)
                }

            // The viewfinder hump.
            Outlined(radius: 3, fill: ScrapbookStyle.deepBrown, line: 1.8)
                .frame(width: 22, height: 10)
                .offset(y: -7)
        }
        .padding(.top, 7)
    }
}

// MARK: - Bunny

private struct BunnyPlush: View {

    var body: some View {

        ZStack {

            // Ears go behind the head.
            Outlined(shape: Capsule(), fill: ScrapbookStyle.cream)
                .frame(width: 15, height: 46)
                .rotationEffect(.degrees(-9))
                .offset(x: -11, y: -34)

            Outlined(shape: Capsule(), fill: ScrapbookStyle.cream)
                .frame(width: 15, height: 46)
                .rotationEffect(.degrees(9))
                .offset(x: 11, y: -34)

            // Body, then head on top.
            Outlined(shape: Circle(), fill: ScrapbookStyle.cream)
                .frame(width: 46, height: 40)
                .offset(y: 16)

            Outlined(shape: Capsule(), fill: ScrapbookStyle.cream)
                .frame(width: 13, height: 20)
                .rotationEffect(.degrees(28))
                .offset(x: -21, y: 14)

            Outlined(shape: Capsule(), fill: ScrapbookStyle.cream)
                .frame(width: 13, height: 20)
                .rotationEffect(.degrees(-28))
                .offset(x: 21, y: 14)

            Outlined(shape: Circle(), fill: ScrapbookStyle.cream)
                .frame(width: 42, height: 38)
                .offset(y: -8)
                .overlay {
                    VStack(spacing: 3) {
                        HStack(spacing: 11) {
                            eye
                            eye
                        }
                        Triangle()
                            .fill(ScrapbookStyle.blossom)
                            .frame(width: 6, height: 5)
                    }
                    .offset(y: -6)
                }
        }
        .frame(width: 62, height: 108, alignment: .bottom)
    }

    private var eye: some View {
        Circle()
            .fill(ScrapbookStyle.outline)
            .frame(width: 4, height: 4)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Potted plant

private struct PottedPlant: View {

    // x, y within the 68 x 62 foliage box.
    private let leaves: [(CGFloat, CGFloat)] = [
        (12, 30), (22, 14), (34, 6), (46, 14), (56, 28),
        (26, 34), (42, 34), (34, 24)
    ]

    var body: some View {

        VStack(spacing: -4) {

            ZStack {

                Path { path in
                    for leaf in leaves {
                        path.move(to: CGPoint(x: 34, y: 62))
                        path.addQuadCurve(
                            to: CGPoint(x: leaf.0, y: leaf.1),
                            control: CGPoint(x: 34 + (leaf.0 - 34) * 0.2, y: 44)
                        )
                    }
                }
                .stroke(ScrapbookStyle.leafStem, lineWidth: 1.8)

                ForEach(Array(leaves.enumerated()), id: \.offset) { _, leaf in
                    Outlined(shape: Circle(), fill: ScrapbookStyle.sage, line: 1.6)
                        .frame(width: 15, height: 15)
                        .position(x: leaf.0, y: leaf.1)
                }
            }
            .frame(width: 68, height: 62)

            Outlined(shape: BowlShape(), fill: ScrapbookStyle.mustard)
                .frame(width: 52, height: 32)
        }
    }
}

private struct BowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.86),
            control2: CGPoint(x: rect.width * 0.74, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.width * 0.26, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.86)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Small heart frame

private struct HeartFrame: View {

    var body: some View {
        Outlined(radius: 4, fill: ScrapbookStyle.mustard)
            .frame(width: 44, height: 40)
            .overlay {
                Outlined(radius: 2, fill: ScrapbookStyle.paperWhite, line: 1.6)
                    .frame(width: 30, height: 26)
                    .overlay {
                        HeartShape()
                            .fill(ScrapbookStyle.blossom)
                            .overlay(HeartShape().stroke(ScrapbookStyle.outline, lineWidth: 1.4))
                            .frame(width: 15, height: 13)
                    }
            }
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.28),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.76),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.52)
        )
        path.addArc(
            center: CGPoint(x: rect.width * 0.25, y: rect.height * 0.28),
            radius: rect.width * 0.25,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.width * 0.75, y: rect.height * 0.28),
            radius: rect.width * 0.25,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.52),
            control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.76)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Ziggy, sitting on the shelf

/// The pet himself, as a little toy. Drawn to match the rest of the shelf
/// rather than dropped in as the app's artwork, which is a painted picture and
/// would sit oddly beside eight outlined objects.
private struct ZiggyToy: View {

    var body: some View {

        ZStack {

            // Body, wider than the head so he sits rather than stacks.
            Outlined(radius: 15, fill: ScrapbookStyle.paperWhite)
                .frame(width: 44, height: 30)
                .position(x: 32, y: 62)

            // Front paws.
            ForEach(0..<2, id: \.self) { side in
                Outlined(shape: Capsule(), fill: ScrapbookStyle.paperWhite, line: 1.6)
                    .frame(width: 13, height: 9)
                    .position(x: side == 0 ? 23 : 41, y: 71)
            }

            // Ears over the body but under the head, which is what makes them
            // hang: drawn first they disappeared behind both, and he came out
            // a bear.
            ForEach(0..<2, id: \.self) { side in
                Outlined(shape: Capsule(), fill: ScrapbookStyle.cream, line: 1.8)
                    .frame(width: 17, height: 36)
                    .rotationEffect(.degrees(side == 0 ? -8 : 8))
                    .position(x: side == 0 ? 12 : 52, y: 42)
            }

            Outlined(shape: Circle(), fill: ScrapbookStyle.paperWhite)
                .frame(width: 38, height: 37)
                .position(x: 32, y: 32)

            // Eyes, big and low — the whole of the face is in how far down
            // they sit.
            ForEach(0..<2, id: \.self) { side in
                Circle().fill(ScrapbookStyle.outline)
                    .frame(width: 6, height: 6)
                    .position(x: side == 0 ? 26 : 38, y: 33)
            }

            // Cheeks.
            ForEach(0..<2, id: \.self) { side in
                Ellipse().fill(ScrapbookStyle.blossom.opacity(0.75))
                    .frame(width: 7, height: 4)
                    .position(x: side == 0 ? 20 : 44, y: 38)
            }

            // Nose.
            Ellipse().fill(ScrapbookStyle.outline)
                .frame(width: 5, height: 4)
                .position(x: 32, y: 41)

            // A collar, so he reads as somebody's rather than a stray.
            Outlined(radius: 2, fill: ScrapbookStyle.terracotta, line: 1.4)
                .frame(width: 28, height: 6)
                .position(x: 32, y: 50)

            HeartShape()
                .fill(ScrapbookStyle.blossom)
                .frame(width: 9, height: 8)
                .position(x: 32, y: 55)
        }
        .frame(width: 64, height: 80)
    }
}

// MARK: - Tea

private struct Teacup: View {

    var body: some View {

        ZStack {

            // Handle, behind the cup.
            Circle()
                .stroke(ScrapbookStyle.outline, lineWidth: 2)
                .frame(width: 18, height: 18)
                .position(x: 44, y: 44)

            Outlined(shape: CupShape(), fill: ScrapbookStyle.paperWhite)
                .frame(width: 38, height: 30)
                .position(x: 27, y: 44)

            // The tea itself, showing at the rim.
            Outlined(shape: Ellipse(), fill: ScrapbookStyle.terracotta, line: 1.4)
                .frame(width: 30, height: 8)
                .position(x: 27, y: 31)

            // Saucer.
            Outlined(shape: Capsule(), fill: ScrapbookStyle.cream)
                .frame(width: 50, height: 8)
                .position(x: 27, y: 62)

            // Steam.
            ForEach(0..<2, id: \.self) { index in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 14))
                    path.addQuadCurve(to: CGPoint(x: 0, y: 0),
                                      control: CGPoint(x: 9, y: 7))
                }
                .stroke(ScrapbookStyle.outline.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 9, height: 14)
                .position(x: 20 + CGFloat(index) * 14, y: 14)
            }
        }
        .frame(width: 56, height: 70)
    }
}

private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.74, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.72),
            control2: CGPoint(x: rect.width * 0.90, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.26, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.width * 0.10, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Candle

private struct Candle: View {

    var body: some View {

        ZStack {

            // Flame.
            Outlined(shape: FlameShape(), fill: ScrapbookStyle.mustard, line: 1.4)
                .frame(width: 11, height: 16)
                .position(x: 22, y: 15)

            // Wick.
            Rectangle()
                .fill(ScrapbookStyle.outline)
                .frame(width: 1.6, height: 5)
                .position(x: 22, y: 26)

            // The wax, with a soft pool at the top.
            Outlined(radius: 4, fill: ScrapbookStyle.paperWhite)
                .frame(width: 24, height: 36)
                .position(x: 22, y: 47)

            Outlined(shape: Ellipse(), fill: ScrapbookStyle.cream, line: 1.4)
                .frame(width: 22, height: 7)
                .position(x: 22, y: 30)

            // Holder.
            Outlined(shape: Capsule(), fill: ScrapbookStyle.terracotta)
                .frame(width: 36, height: 9)
                .position(x: 22, y: 67)
        }
        .frame(width: 44, height: 74)
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.height * 0.42))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.height * 0.42))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cassette

private struct Cassette: View {

    var body: some View {

        Outlined(radius: 5, fill: ScrapbookStyle.blossom)
            .frame(width: 68, height: 44)
            .overlay {
                VStack(spacing: 4) {

                    // The label you write the track list on.
                    Outlined(radius: 2, fill: ScrapbookStyle.paperWhite, line: 1.4)
                        .frame(width: 52, height: 14)
                        .overlay {
                            VStack(spacing: 3) {
                                ForEach(0..<2, id: \.self) { _ in
                                    Rectangle()
                                        .fill(ScrapbookStyle.outline.opacity(0.35))
                                        .frame(height: 1.4)
                                }
                            }
                            .padding(.horizontal, 6)
                        }

                    // The window, with both spools.
                    Outlined(radius: 2, fill: ScrapbookStyle.deepBrown, line: 1.4)
                        .frame(width: 44, height: 15)
                        .overlay {
                            HStack(spacing: 12) {
                                ForEach(0..<2, id: \.self) { _ in
                                    Outlined(shape: Circle(),
                                             fill: ScrapbookStyle.cream, line: 1.2)
                                        .frame(width: 9, height: 9)
                                }
                            }
                        }
                }
            }
            .frame(width: 70, height: 60, alignment: .bottom)
    }
}

// MARK: - Alarm clock

private struct AlarmClock: View {

    var body: some View {

        ZStack {

            // Bells.
            ForEach(0..<2, id: \.self) { side in
                Outlined(shape: Circle(), fill: ScrapbookStyle.mustard, line: 1.6)
                    .frame(width: 14, height: 14)
                    .position(x: side == 0 ? 12 : 44, y: 16)
            }

            // Feet.
            ForEach(0..<2, id: \.self) { side in
                Outlined(shape: Capsule(), fill: ScrapbookStyle.outline, line: 1.2)
                    .frame(width: 7, height: 10)
                    .position(x: side == 0 ? 17 : 39, y: 60)
            }

            Outlined(shape: Circle(), fill: ScrapbookStyle.terracotta)
                .frame(width: 44, height: 44)
                .position(x: 28, y: 38)

            Outlined(shape: Circle(), fill: ScrapbookStyle.paperWhite, line: 1.6)
                .frame(width: 32, height: 32)
                .position(x: 28, y: 38)

            // Hands, at ten past ten.
            Path { path in
                path.move(to: CGPoint(x: 28, y: 38))
                path.addLine(to: CGPoint(x: 28, y: 26))
                path.move(to: CGPoint(x: 28, y: 38))
                path.addLine(to: CGPoint(x: 37, y: 42))
            }
            .stroke(ScrapbookStyle.outline,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: 56, height: 70)
    }
}

// MARK: - A little stack of snaps

private struct PolaroidStack: View {

    private let leans: [Double] = [-9, 5, -2]

    var body: some View {

        ZStack {
            ForEach(Array(leans.enumerated()), id: \.offset) { index, lean in
                Outlined(radius: 2, fill: ScrapbookStyle.paperWhite, line: 1.6)
                    .frame(width: 40, height: 46)
                    .overlay(alignment: .top) {
                        Outlined(radius: 1, fill: index == 1
                                 ? ScrapbookStyle.sage
                                 : ScrapbookStyle.terracotta, line: 1.2)
                            .frame(width: 32, height: 30)
                            .padding(.top, 4)
                    }
                    .rotationEffect(.degrees(lean))
                    .offset(x: CGFloat(index) * 4 - 4, y: CGFloat(index) * -2)
            }
        }
        .frame(width: 64, height: 60)
    }
}

// MARK: - Jar of paper hearts

private struct JarOfHearts: View {

    private let hearts: [(CGFloat, CGFloat, Double)] = [
        (16, 46, -14), (30, 42, 10), (23, 54, 4), (34, 55, -8)
    ]

    var body: some View {

        ZStack {

            // Lid.
            Outlined(radius: 2, fill: ScrapbookStyle.terracotta, line: 1.6)
                .frame(width: 30, height: 8)
                .position(x: 25, y: 18)

            // Glass.
            Outlined(radius: 7, fill: ScrapbookStyle.paperWhite.opacity(0.9))
                .frame(width: 36, height: 44)
                .position(x: 25, y: 44)

            ForEach(Array(hearts.enumerated()), id: \.offset) { _, heart in
                HeartShape()
                    .fill(ScrapbookStyle.blossom)
                    .frame(width: 11, height: 10)
                    .rotationEffect(.degrees(heart.2))
                    .position(x: heart.0, y: heart.1)
            }

            // A highlight down the glass, over the hearts.
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 4, height: 22)
                .position(x: 14, y: 40)
        }
        .frame(width: 52, height: 70)
    }
}

// MARK: - Record player

private struct RecordPlayer: View {

    var body: some View {

        ZStack {

            // The lid, standing up behind.
            Outlined(radius: 3, fill: ScrapbookStyle.terracotta)
                .frame(width: 58, height: 26)
                .position(x: 36, y: 24)

            // The case.
            Outlined(radius: 4, fill: ScrapbookStyle.cream)
                .frame(width: 66, height: 30)
                .position(x: 36, y: 52)

            // The record on the platter, with its label.
            Outlined(shape: Circle(), fill: ScrapbookStyle.outline, line: 1.4)
                .frame(width: 26, height: 26)
                .overlay {
                    Circle()
                        .fill(ScrapbookStyle.mustard)
                        .frame(width: 9, height: 9)
                }
                .position(x: 30, y: 52)

            // The tonearm, resting on the record.
            Path { path in
                path.move(to: CGPoint(x: 60, y: 42))
                path.addLine(to: CGPoint(x: 36, y: 52))
            }
            .stroke(ScrapbookStyle.outline,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            Circle()
                .fill(ScrapbookStyle.outline)
                .frame(width: 6, height: 6)
                .position(x: 61, y: 42)
        }
        .frame(width: 72, height: 70)
    }
}
