//
//  ScrapbookModels.swift
//  Ziggy
//
//  The shared scrapbook: a shelf of books, each book a stack of pages,
//  each page a loose pile of elements both partners can move around.
//

import SwiftUI

// MARK: - Book

/// One book on the shelf. Cheap to load — the pages live in a subcollection,
/// so the shelf can list twenty books without pulling a single photo.
struct ScrapbookBook: Identifiable, Equatable {

    var id: String
    var title: String
    var coverIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var pageCount: Int

    /// How far the book leans on the shelf, in degrees. Set by hand in edit
    /// mode; zero means standing straight.
    var tilt: Double = 0

    /// A multiplier on the spine's natural size, so a favourite can be made
    /// bigger than the rest. Clamped by `displayThickness` / `displayHeight`.
    var sizeScale: Double = 1

    /// Where the book sits in the running order across the whole bookcase.
    ///
    /// Seeded from the creation time so books added before this existed still
    /// come out oldest-first, and only rewritten when someone actually moves
    /// one. Sorting on `updatedAt` instead would reshuffle the shelf every
    /// time either of you touched a page.
    var position: Double = 0

    /// A row of identical books looks machine-stamped, so each one is nudged
    /// off the standard height. Derived from the title rather than the id:
    /// `hashValue` is salted per launch, so an id-based jitter would reshuffle
    /// the whole shelf every time the app started.
    var heightJitter: CGFloat {
        CGFloat(stableSeed % 100) / 100 * 22 - 11
    }

    /// Same idea for the spine width — thin books next to fat ones.
    var thickness: CGFloat {
        34 + CGFloat((stableSeed / 7) % 100) / 100 * 18
    }

    var height: CGFloat { 146 + heightJitter }

    /// The size actually drawn, once the owner's edits are applied. Bounded
    /// so no single book can grow tall enough to push through the shelf above
    /// it or thin enough to disappear.
    var displayThickness: CGFloat { thickness * clampedScale }
    var displayHeight: CGFloat { height * clampedScale }

    private var clampedScale: CGFloat { min(max(CGFloat(sizeScale), 0.78), 1.22) }

    /// FNV-1a over the title. Small, stable across launches and identical on
    /// both phones, which `String.hashValue` is not.
    private var stableSeed: Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in title.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return Int(hash % 1_000_000)
    }

    static func placeholder(title: String, coverIndex: Int) -> ScrapbookBook {
        ScrapbookBook(
            id: UUID().uuidString,
            title: title,
            coverIndex: coverIndex,
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 0
        )
    }
}

// MARK: - Ornament placement

/// Where one drawn object sits on the bookcase.
///
/// Stored for the couple rather than derived from shelf position, so moving
/// the lamp is a change your partner sees too.
struct ScrapbookOrnamentPlacement: Identifiable, Equatable {

    var id: String

    /// Ornaments share one running order with the books rather than having
    /// their own shelf and column. That's what lets a book be dropped between
    /// two plants, and a plant between two books.
    var position: Double

    var kind: Int
    var scale: Double = 1

    var ornament: ScrapbookOrnament {
        ScrapbookOrnament(rawValue: kind) ?? .flowerVase
    }

    var clampedScale: CGFloat { min(max(CGFloat(scale), 0.7), 1.35) }

    var displayWidth: CGFloat { ornament.width * clampedScale }

    /// The stock arrangement: one of every object, spread through the books
    /// rather than queued up behind them.
    ///
    /// Bunching them all after the last book left them piled onto whichever
    /// shelf they happened to land on and the lower shelves bare. Threading
    /// their positions through the range the books occupy puts something on
    /// every shelf, which is what a shelf actually looks like.
    ///
    /// Only ever used until somebody moves something — the moment there's a
    /// saved arrangement, that wins.
    static func defaults(spanning bookPositions: [Double]) -> [ScrapbookOrnamentPlacement] {

        let kinds = ScrapbookOrnament.allCases

        guard let first = bookPositions.min(),
              let last = bookPositions.max(),
              last > first else {

            // Nothing to thread through yet, so just line them up.
            return kinds.enumerated().map { index, kind in
                ScrapbookOrnamentPlacement(
                    id: "o\(index)",
                    position: Double(index) * 1_000,
                    kind: kind.rawValue
                )
            }
        }

        let span = last - first

        return kinds.enumerated().map { index, kind in

            // Runs a little past the last book, so the tail of the shelf gets
            // an ornament too rather than ending on a spine.
            let through = Double(index + 1) / Double(kinds.count) * 1.15

            return ScrapbookOrnamentPlacement(
                id: "o\(index)",
                position: first + span * through,
                kind: kind.rawValue
            )
        }
    }
}

// MARK: - One thing standing on a shelf

/// Books and ornaments unified, so the shelf can lay them out as a single
/// flowing row and a drag can put either kind anywhere.
struct ShelfItem: Identifiable, Equatable {

    enum Kind: Equatable {
        case book(ScrapbookBook)
        case ornament(ScrapbookOrnamentPlacement)
        case addSlot
        case addOrnament
    }

    let id: String
    let kind: Kind
    let position: Double
    let width: CGFloat

    /// How tall it stands, so it can be sat on the shelf surface rather than
    /// aligned by a stack.
    let height: CGFloat

    /// The two "add" slots ride along in the layout but aren't part of the
    /// running order, so they're skipped when working out a drop index.
    var isMovable: Bool {
        switch kind {
        case .addSlot, .addOrnament: return false
        case .book, .ornament:       return true
        }
    }

    init(book: ScrapbookBook) {
        id = book.id
        kind = .book(book)
        position = book.position
        width = book.displayThickness
        height = book.displayHeight
    }

    init(ornament: ScrapbookOrnamentPlacement, boxHeight: CGFloat) {
        id = ornament.id
        kind = .ornament(ornament)
        position = ornament.position
        width = ornament.displayWidth
        height = boxHeight
    }

    init(addSlotWidth: CGFloat, height: CGFloat) {
        id = "__add__"
        kind = .addSlot
        position = .greatestFiniteMagnitude
        width = addSlotWidth
        self.height = height
    }

    init(addOrnamentWidth: CGFloat, height: CGFloat) {
        id = "__addOrnament__"
        kind = .addOrnament
        position = .greatestFiniteMagnitude
        width = addOrnamentWidth
        self.height = height
    }
}

// MARK: - Page

struct ScrapbookPage: Identifiable, Equatable {

    var id: String
    var index: Int
    var paperIndex: Int
    var updatedAt: Date

    static func blank(index: Int) -> ScrapbookPage {
        ScrapbookPage(
            id: UUID().uuidString,
            index: index,
            paperIndex: 0,
            updatedAt: Date()
        )
    }
}

// MARK: - Element

enum ScrapbookElementKind: String {
    case photo
    case text
    case sticker
    case stroke
}

/// A single thing sitting on a page.
///
/// Position is normalised to the page rather than stored in points: the canvas
/// is a different number of pixels wide on an SE than on a Pro Max, and a
/// scrapbook that reflowed between the two phones would be worse than useless.
struct ScrapbookElement: Identifiable, Equatable {

    var id: String
    var kind: ScrapbookElementKind

    var x: Double = 0.5
    var y: Double = 0.5
    var scale: Double = 1.0
    var rotation: Double = 0.0
    var z: Int = 0

    /// Photo: base64 JPEG. Text/sticker: the literal string.
    /// Stroke: normalised points encoded by `ScrapbookStroke`.
    var payload: String = ""

    var colorHex: String = "#2E2A27"
    var frameIndex: Int = 0
    var fontIndex: Int = 0
    var widthValue: Double = 6
    var createdBy: String = ""

    /// Photos carry their own aspect so the frame doesn't letterbox them
    /// before the image has finished decoding.
    var aspect: Double = 1.0

    /// Pinned to the page. A locked element ignores drags, pinches and turns
    /// so it can't be knocked out of place while you work around it.
    var locked: Bool = false
}

// MARK: - Stroke encoding

/// Brush strokes are stored as a flat "x,y x,y x,y" string.
///
/// A subcollection document per stroke would be tidier, but a page of
/// scribbles is easily a hundred strokes and that's a hundred writes and a
/// hundred reads every time someone opens the book. One document per stroke
/// with the points inline is the compromise: still granular enough that two
/// people drawing at once don't clobber each other.
enum ScrapbookStroke {

    static func encode(_ points: [CGPoint]) -> String {
        points
            .map { "\(round($0.x * 1000) / 1000),\(round($0.y * 1000) / 1000)" }
            .joined(separator: " ")
    }

    static func decode(_ raw: String) -> [CGPoint] {
        raw.split(separator: " ").compactMap { pair in
            let parts = pair.split(separator: ",")
            guard parts.count == 2,
                  let x = Double(parts[0]),
                  let y = Double(parts[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
    }

    /// Smooths the polyline into a curve so a finger-drawn line doesn't look
    /// like a seismograph. Midpoint quadratics — cheap, and good enough at
    /// the speed a finger actually moves.
    static func path(for points: [CGPoint], in size: CGSize) -> Path {

        var path = Path()
        guard let first = points.first else { return path }

        let scaled = points.map {
            CGPoint(x: $0.x * size.width, y: $0.y * size.height)
        }

        guard scaled.count > 2 else {
            path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
            for point in scaled.dropFirst() { path.addLine(to: point) }
            return path
        }

        path.move(to: scaled[0])
        for index in 1..<(scaled.count - 1) {
            let mid = CGPoint(
                x: (scaled[index].x + scaled[index + 1].x) / 2,
                y: (scaled[index].y + scaled[index + 1].y) / 2
            )
            path.addQuadCurve(to: mid, control: scaled[index])
        }
        path.addLine(to: scaled[scaled.count - 1])

        return path
    }
}
