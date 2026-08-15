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

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .flowerVase:  return "Flowers"
        case .bookStack:   return "Books"
        case .framedArt:   return "Print"
        case .tableLamp:   return "Lamp"
        case .camera:      return "Camera"
        case .bunny:       return "Bunny"
        case .pottedPlant: return "Plant"
        case .heartFrame:  return "Photo"
        }
    }

    /// Roughly how much shelf each one needs.
    var width: CGFloat {
        switch self {
        case .flowerVase:  return 62
        case .bookStack:   return 72
        case .framedArt:   return 60
        case .tableLamp:   return 58
        case .camera:      return 66
        case .bunny:       return 62
        case .pottedPlant: return 68
        case .heartFrame:  return 46
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .flowerVase:  FlowerVase()
        case .bookStack:   BookStack()
        case .framedArt:   FramedArt()
        case .tableLamp:   TableLamp()
        case .camera:      CameraOrnament()
        case .bunny:       BunnyPlush()
        case .pottedPlant: PottedPlant()
        case .heartFrame:  HeartFrame()
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
