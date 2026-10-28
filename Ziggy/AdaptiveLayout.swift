//
//  AdaptiveLayout.swift
//  Ziggy
//
//  How the app behaves when it is not a phone held upright.
//
//  Three shapes, not a spectrum. A phone in portrait is the app as it has
//  always been and is left alone. A phone turned sideways has plenty of width
//  and almost no height. An iPad has plenty of both. Those want different
//  things, and guessing from a single number — the width — gets the middle one
//  wrong, because a sideways phone is as wide as a small iPad and half as tall.
//
//  So the decision is made from the size classes iOS already works out, with
//  the measured height only used to tell a short screen from a tall one.
//

import SwiftUI

// MARK: - The shape of the screen

enum ZiggyShape {

    /// A phone held upright. The original layout, untouched.
    case phone

    /// A phone turned sideways: wide and very short.
    case phoneLandscape

    /// An iPad, either way up. Wide and tall.
    case pad

    /// Whether this shape has room to put things side by side.
    var isWide: Bool { self != .phone }

    /// Whether vertical space is the scarce thing.
    var isShort: Bool { self == .phoneLandscape }
}

private struct ZiggyShapeKey: EnvironmentKey {
    static let defaultValue: ZiggyShape = .phone
}

extension EnvironmentValues {
    var ziggyShape: ZiggyShape {
        get { self[ZiggyShapeKey.self] }
        set { self[ZiggyShapeKey.self] = newValue }
    }
}

// MARK: - Working it out

/// Decides the shape once, at the top, and puts it in the environment so no
/// screen has to work it out again — or disagree about it.
struct ZiggyShapeReader<Content: View>: View {

    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical

    @ViewBuilder var content: Content

    var body: some View {
        content.environment(\.ziggyShape, shape)
    }

    private var shape: ZiggyShape {
        // A sideways phone is the only thing iOS reports as vertically
        // compact. An iPad is regular in both directions whichever way it is
        // held, including in a narrow split view, where it behaves like a
        // phone and is treated as one.
        if vertical == .compact { return .phoneLandscape }
        if horizontal == .regular { return .pad }
        return .phone
    }
}

// MARK: - Column width

/// Keeps a column of cards readable however wide the screen gets.
///
/// Full-bleed is right on a phone, where the screen is about as wide as a
/// column of text should be. It stops being right the moment there is more
/// width than that: a card stretched across an iPad is not generous, it is
/// just a long way for the eye to travel to find the next word.
private struct ReadableColumn: ViewModifier {

    let limit: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: limit)
            // The second frame is what centres the first. Without it the
            // capped column sits against the leading edge.
            .frame(maxWidth: .infinity)
    }
}

extension View {

    /// Caps and centres a column of content on wide screens, and does nothing
    /// on a phone in portrait, where the screen is already narrower than the
    /// cap.
    func readableColumn(_ limit: CGFloat = 620) -> some View {
        modifier(ReadableColumn(limit: limit))
    }
}
