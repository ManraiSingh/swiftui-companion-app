//
//  ScrapbookStyle.swift
//  Ziggy
//
//  Every colour, paper and frame the scrapbook draws from. Kept in one place
//  so the shelf, the covers and the pages stay in the same world.
//

import SwiftUI

enum ScrapbookStyle {

    // MARK: Shelf
    //
    // A warm, outlined set. Everything on the shelf shares one dark-brown
    // stroke, which is what holds the drawn objects and the book spines
    // together as a single illustration rather than a pile of shapes.

    static let outline     = Color(red: 0.33, green: 0.21, blue: 0.13)
    static let wood        = Color(red: 0.82, green: 0.53, blue: 0.35)
    static let woodDark    = Color(red: 0.70, green: 0.42, blue: 0.26)
    static let woodLight   = Color(red: 0.89, green: 0.63, blue: 0.44)

    static let cream       = Color(red: 0.96, green: 0.90, blue: 0.77)
    static let paperWhite  = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let mustard     = Color(red: 0.95, green: 0.79, blue: 0.42)
    static let terracotta  = Color(red: 0.85, green: 0.55, blue: 0.36)
    static let sage        = Color(red: 0.72, green: 0.82, blue: 0.62)
    static let leafStem    = Color(red: 0.47, green: 0.58, blue: 0.38)
    static let blossom     = Color(red: 0.94, green: 0.68, blue: 0.62)
    static let deepBrown   = Color(red: 0.44, green: 0.28, blue: 0.19)

    /// The wall behind the shelf.
    static let wallTop     = Color(red: 0.93, green: 0.91, blue: 0.97)
    static let wallBottom  = Color(red: 0.99, green: 0.95, blue: 0.89)

    // MARK: Paper

    static let ink         = Color(red: 0.18, green: 0.16, blue: 0.15)
    static let inkSoft     = Color(red: 0.42, green: 0.38, blue: 0.35)

    // MARK: Covers

    /// Front colour, spine colour, and the ink the title is written in.
    struct Cover {
        let front: Color
        let spine: Color
        let title: Color
    }

    static let covers: [Cover] = [
        Cover(front: Color(red: 0.95, green: 0.79, blue: 0.42),
              spine: Color(red: 0.87, green: 0.69, blue: 0.32),
              title: Color(red: 0.36, green: 0.24, blue: 0.10)),

        Cover(front: Color(red: 0.85, green: 0.55, blue: 0.36),
              spine: Color(red: 0.75, green: 0.45, blue: 0.28),
              title: Color(red: 0.99, green: 0.96, blue: 0.90)),

        Cover(front: Color(red: 0.72, green: 0.82, blue: 0.62),
              spine: Color(red: 0.60, green: 0.72, blue: 0.51),
              title: Color(red: 0.24, green: 0.34, blue: 0.19)),

        Cover(front: Color(red: 0.94, green: 0.68, blue: 0.62),
              spine: Color(red: 0.86, green: 0.57, blue: 0.52),
              title: Color(red: 0.44, green: 0.19, blue: 0.18)),

        Cover(front: Color(red: 0.96, green: 0.90, blue: 0.77),
              spine: Color(red: 0.88, green: 0.81, blue: 0.66),
              title: Color(red: 0.38, green: 0.27, blue: 0.16)),

        Cover(front: Color(red: 0.44, green: 0.62, blue: 0.63),
              spine: Color(red: 0.34, green: 0.52, blue: 0.53),
              title: Color(red: 0.96, green: 0.97, blue: 0.94)),

        Cover(front: Color(red: 0.68, green: 0.56, blue: 0.74),
              spine: Color(red: 0.57, green: 0.46, blue: 0.64),
              title: Color(red: 0.99, green: 0.97, blue: 0.94)),

        Cover(front: Color(red: 0.62, green: 0.38, blue: 0.30),
              spine: Color(red: 0.51, green: 0.30, blue: 0.23),
              title: Color(red: 0.97, green: 0.90, blue: 0.78))
    ]

    static func cover(_ index: Int) -> Cover {
        covers[((index % covers.count) + covers.count) % covers.count]
    }

    // MARK: Papers

    struct Paper {
        let name: String
        let base: Color
        let tint: Color
        let ruled: Bool
        let grid: Bool
    }

    static let papers: [Paper] = [
        Paper(name: "Cream",  base: Color(red: 0.97, green: 0.94, blue: 0.87),
              tint: Color(red: 0.93, green: 0.88, blue: 0.78), ruled: false, grid: false),

        Paper(name: "Kraft",  base: Color(red: 0.87, green: 0.77, blue: 0.62),
              tint: Color(red: 0.80, green: 0.68, blue: 0.51), ruled: false, grid: false),

        Paper(name: "Ruled",  base: Color(red: 0.98, green: 0.97, blue: 0.94),
              tint: Color(red: 0.72, green: 0.80, blue: 0.88), ruled: true,  grid: false),

        Paper(name: "Grid",   base: Color(red: 0.98, green: 0.97, blue: 0.93),
              tint: Color(red: 0.80, green: 0.83, blue: 0.78), ruled: false, grid: true),

        Paper(name: "Blush",  base: Color(red: 0.99, green: 0.91, blue: 0.90),
              tint: Color(red: 0.95, green: 0.82, blue: 0.82), ruled: false, grid: false),

        Paper(name: "Sky",    base: Color(red: 0.90, green: 0.94, blue: 0.99),
              tint: Color(red: 0.80, green: 0.87, blue: 0.96), ruled: false, grid: false),

        Paper(name: "Mint",   base: Color(red: 0.90, green: 0.96, blue: 0.92),
              tint: Color(red: 0.79, green: 0.90, blue: 0.83), ruled: false, grid: false),

        Paper(name: "Night",  base: Color(red: 0.16, green: 0.17, blue: 0.24),
              tint: Color(red: 0.24, green: 0.26, blue: 0.34), ruled: false, grid: false)
    ]

    static func paper(_ index: Int) -> Paper {
        papers[((index % papers.count) + papers.count) % papers.count]
    }

    /// Text defaults to light on the dark paper, otherwise it vanishes.
    static func defaultInk(onPaper index: Int) -> Color {
        paper(index).name == "Night"
            ? Color(red: 0.96, green: 0.95, blue: 0.92)
            : ink
    }

    // MARK: Photo frames

    enum Frame: Int, CaseIterable, Identifiable {
        case none, polaroid, white, tape, film, rounded, torn, tornCircle, arch

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .none:     return "Plain"
            case .polaroid: return "Polaroid"
            case .white:    return "Border"
            case .tape:     return "Taped"
            case .film:     return "Film"
            case .rounded:  return "Rounded"
            case .torn:     return "Torn"
            case .tornCircle: return "Circle"
            case .arch:     return "Arch"
            }
        }

        var icon: String {
            switch self {
            case .none:     return "photo"
            case .polaroid: return "square.bottomhalf.filled"
            case .white:    return "square.on.square"
            case .tape:     return "bandage"
            case .film:     return "film"
            case .rounded:  return "square.dashed"
            case .torn:     return "doc.plaintext"
            case .tornCircle: return "circle.dashed"
            case .arch:     return "arrowtriangle.up.square"
            }
        }
    }

    static func frame(_ index: Int) -> Frame {
        Frame(rawValue: index) ?? .none
    }

    // MARK: Brush + text colours

    static let inkPalette: [String] = [
        "#2E2A27", "#FFFFFF", "#E4572E", "#F4A259", "#F6C453",
        "#6BAA75", "#3B8EA5", "#4F6DE0", "#8367C7", "#D64A7A",
        "#A8763E", "#7D8491"
    ]

    /// Papers a photo frame can be cut from.
    static let framePalette: [String] = [
        "#FDFAF5", "#F5E9D0", "#2B2B30", "#F6C453", "#E4572E",
        "#94C4E8", "#F2A8C4", "#8FBF7F", "#4F6DE0", "#C9A0DC"
    ]

    /// Whether ink on this paper needs to be light.
    ///
    /// Rec. 601 luma — good enough to decide between white and dark, and it
    /// keeps the film sprockets and polaroid shadow legible whichever colour
    /// the frame has been changed to.
    static func isDark(hex: String) -> Bool {

        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        guard value.count == 6, let number = UInt32(value, radix: 16) else { return false }

        let red = Double((number & 0xFF0000) >> 16)
        let green = Double((number & 0x00FF00) >> 8)
        let blue = Double(number & 0x0000FF)

        return (0.299 * red + 0.587 * green + 0.114 * blue) < 140
    }

    // MARK: Brushes

    /// The pens available on a page. Mirrors the doodle's set as closely as
    /// plain stroke drawing allows — the doodle has PencilKit's real inks
    /// behind it, so these approximate the same feel with opacity, width and
    /// cap rather than reproducing the texture.
    struct Brush {
        let label: String
        let icon: String
        let opacity: Double
        let widthScale: Double
        let flatCap: Bool
        /// Drawn twice, slightly apart, for the grain of a crayon.
        let grainy: Bool
    }

    static let brushes: [Brush] = [
        Brush(label: "Pen",      icon: "pencil.tip",              opacity: 1.00,
              widthScale: 1.0,  flatCap: false, grainy: false),
        Brush(label: "Fountain", icon: "paintbrush.pointed.fill", opacity: 0.95,
              widthScale: 1.35, flatCap: false, grainy: false),
        Brush(label: "Marker",   icon: "highlighter",             opacity: 0.55,
              widthScale: 2.1,  flatCap: true,  grainy: false),
        Brush(label: "Pencil",   icon: "pencil",                  opacity: 0.72,
              widthScale: 0.6,  flatCap: false, grainy: true),
        Brush(label: "Monoline", icon: "scribble",                opacity: 1.00,
              widthScale: 0.85, flatCap: true,  grainy: false),
        Brush(label: "Water",    icon: "drop.fill",               opacity: 0.34,
              widthScale: 2.6,  flatCap: false, grainy: false),
        Brush(label: "Crayon",   icon: "paintpalette.fill",       opacity: 0.80,
              widthScale: 1.5,  flatCap: true,  grainy: true)
    ]

    static func brush(_ index: Int) -> Brush {
        brushes[((index % brushes.count) + brushes.count) % brushes.count]
    }

    // MARK: Stickers

    /// Grouped so the picker has sections rather than one endless grid.
    static let stickerGroups: [(String, [String])] = [
        ("Love",    ["❤️", "💕", "💘", "💞", "😍", "🥰", "😘", "💌", "🫶", "💍"]),
        ("Cute",    ["🌸", "🌷", "🌻", "🍀", "⭐️", "✨", "🌙", "☁️", "🦋", "🐣"]),
        ("Trips",   ["✈️", "🗺", "🏝", "⛰", "🚗", "🎒", "📸", "🎡", "🏨", "🧳"]),
        ("Food",    ["🍰", "🍓", "🍕", "🍜", "🍦", "☕️", "🍺", "🥐", "🍣", "🧋"]),
        ("Moments", ["🎂", "🎉", "🎁", "🎈", "🕯", "🎬", "🎧", "📖", "🏆", "🎨"])
    ]

    // MARK: Fonts

    struct FontChoice {
        let label: String
        let design: Font.Design
        let weight: Font.Weight
        let italic: Bool
    }

    static let fonts: [FontChoice] = [
        FontChoice(label: "Hand",    design: .rounded,    weight: .semibold, italic: false),
        FontChoice(label: "Serif",   design: .serif,      weight: .regular,  italic: false),
        FontChoice(label: "Note",    design: .serif,      weight: .regular,  italic: true),
        FontChoice(label: "Clean",   design: .default,    weight: .medium,   italic: false),
        FontChoice(label: "Type",    design: .monospaced, weight: .regular,  italic: false),
        FontChoice(label: "Bold",    design: .rounded,    weight: .black,    italic: false),

        FontChoice(label: "Title",   design: .serif,      weight: .black,    italic: false),
        FontChoice(label: "Quote",   design: .serif,      weight: .semibold, italic: true),
        FontChoice(label: "Light",   design: .default,    weight: .thin,     italic: false),
        FontChoice(label: "Slant",   design: .rounded,    weight: .bold,     italic: true),
        FontChoice(label: "Caps",    design: .default,    weight: .heavy,    italic: false),
        FontChoice(label: "Soft",    design: .rounded,    weight: .light,    italic: false),
        FontChoice(label: "Ticket",  design: .monospaced, weight: .bold,     italic: false),
        FontChoice(label: "Whisper", design: .default,    weight: .regular,  italic: true),
        FontChoice(label: "Heavy",   design: .default,    weight: .black,    italic: false),
        FontChoice(label: "Book",    design: .serif,      weight: .medium,   italic: false)
    ]

    static func font(_ index: Int, size: CGFloat) -> Font {
        let choice = fonts[((index % fonts.count) + fonts.count) % fonts.count]
        let base = Font.system(size: size, weight: choice.weight, design: choice.design)
        return choice.italic ? base.italic() : base
    }
}

// MARK: - Hex bridging

extension Color {

    init(scrapbookHex hex: String) {

        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            self = ScrapbookStyle.ink
            return
        }

        self.init(
            red:   Double((number & 0xFF0000) >> 16) / 255,
            green: Double((number & 0x00FF00) >> 8) / 255,
            blue:  Double(number & 0x0000FF) / 255
        )
    }
}
