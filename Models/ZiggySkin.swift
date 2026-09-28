//
//  ZiggySkin.swift
//  Ziggy
//
//  What Ziggy is wearing.
//
//  Shared with the widget extension, the same way `Pet` is, because a hat that
//  only exists inside the app is a hat your partner never sees — and the
//  widget is where he is looked at most.
//
//  A skin is deliberately not a picture of a dressed-up Ziggy. Ziggy is eight
//  separate drawings, one per mood, and a skin that replaced them would need
//  eight new images each. Instead an accessory is drawn in code and laid over
//  whichever mood is showing, which means one hat works across all eight moods,
//  the seven Ziggy Jump frames, and anything drawn later, for nothing.
//
//  The hard part is that the eight moods are eight *poses* — he sits, he lies
//  down, he puts his paws up — so the top of his head is somewhere different in
//  each. `ZiggyAnchor` carries where the crown is and how wide the head is in
//  every one, measured off the artwork rather than guessed, so a hat sits on
//  his head whatever he is doing.
//

import SwiftUI

// MARK: - Where the head is

/// The crown of Ziggy's head in one mood, as fractions of the sprite's box.
///
/// Measured from the artwork itself by finding the topmost fur-coloured pixel
/// — fur specifically, so the floating hearts, the flames and the Zzz do not
/// drag the anchor up above his head.
struct ZiggyAnchor: Sendable {

    /// Horizontal centre of the head.
    let x: Double

    /// The very top of the head.
    let y: Double

    /// Ear to ear, which is what an accessory is sized against.
    let headWidth: Double

    static func forSprite(_ name: String) -> ZiggyAnchor {
        table[name] ?? ZiggyAnchor(x: 0.50, y: 0.25, headWidth: 0.65)
    }

    private static let table: [String: ZiggyAnchor] = [
        "ziggy_happie":          .init(x: 0.503, y: 0.198, headWidth: 0.714),
        "ziggy_tears":           .init(x: 0.496, y: 0.238, headWidth: 0.686),
        "ziggy_fireangry":       .init(x: 0.514, y: 0.244, headWidth: 0.580),
        "ziggy_angrywithhands":  .init(x: 0.470, y: 0.252, headWidth: 0.668),
        "ziggy_angrywithmark":   .init(x: 0.475, y: 0.258, headWidth: 0.672),
        "ziggu_cry":             .init(x: 0.470, y: 0.272, headWidth: 0.638),
        "ziggy_loveeyes":        .init(x: 0.510, y: 0.288, headWidth: 0.638),
        // Lying down, head to the right and lower than every other pose.
        "ziggy_sleep":           .init(x: 0.545, y: 0.334, headWidth: 0.626)
    ]
}

// MARK: - Accessories

/// One thing Ziggy can wear on his head.
///
/// Head-top only for now. Glasses and scarves want the face and the neck,
/// which are two more anchors per pose, and a hat that sits perfectly is worth
/// more than four accessories that nearly do.
enum ZiggyAccessory: String, CaseIterable, Identifiable, Sendable {

    case bow, crown, partyHat, beanie, flowerCrown,
         halo, headphones, cap, topHat, sprout

    nonisolated var id: String { rawValue }

    nonisolated var name: String {
        switch self {
        case .bow:         return "Bow"
        case .crown:       return "Crown"
        case .partyHat:    return "Party Hat"
        case .beanie:      return "Beanie"
        case .flowerCrown: return "Flowers"
        case .halo:        return "Halo"
        case .headphones:  return "Headphones"
        case .cap:         return "Cap"
        case .topHat:      return "Top Hat"
        case .sprout:      return "Sprout"
        }
    }

    /// Width as a multiple of the head's width in whatever pose is showing.
    nonisolated var widthRatio: Double {
        switch self {
        case .bow:         return 0.56
        case .crown:       return 0.64
        case .partyHat:    return 0.50
        case .beanie:      return 0.84
        case .flowerCrown: return 0.94
        case .halo:        return 0.58
        case .headphones:  return 0.96
        case .cap:         return 0.86
        case .topHat:      return 0.64
        case .sprout:      return 0.30
        }
    }

    nonisolated var aspect: Double {
        switch self {
        case .bow:         return 0.62
        case .crown:       return 0.58
        case .partyHat:    return 1.25
        case .beanie:      return 0.74
        case .flowerCrown: return 0.32
        case .halo:        return 0.30
        case .headphones:  return 0.64
        case .cap:         return 0.54
        case .topHat:      return 0.86
        case .sprout:      return 1.00
        }
    }

    /// How far the piece sinks into the head, as a fraction of its own height.
    ///
    /// Without this everything perches exactly on the crown like it is
    /// balanced there. A beanie should swallow the top of his head; a halo
    /// should float clear of it, which is what a negative value means.
    nonisolated var sink: Double {
        switch self {
        case .bow:         return 0.16
        case .crown:       return 0.24
        case .partyHat:    return 0.10
        case .beanie:      return 0.50
        case .flowerCrown: return 0.48
        case .halo:        return -0.90
        case .headphones:  return 0.62
        case .cap:         return 0.44
        case .topHat:      return 0.12
        case .sprout:      return 0.04
        }
    }
}

// MARK: - Skins

/// A skin is an accessory today and may be a whole alternate Ziggy later.
///
/// `spriteSet` is the door left open: give it a prefix and the renderer will
/// look for `<prefix>_<mood>` before falling back to the stock drawing, so a
/// full hand-drawn Ziggy can be dropped in later without any of this changing.
struct ZiggySkin: Identifiable, Sendable {

    let id: String
    let name: String
    let blurb: String
    let accessory: ZiggyAccessory?
    let spriteSet: String?

    nonisolated init(
        id: String,
        name: String,
        blurb: String,
        accessory: ZiggyAccessory? = nil,
        spriteSet: String? = nil
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.accessory = accessory
        self.spriteSet = spriteSet
    }

    /// Ziggy as he comes.
    static let none = ZiggySkin(
        id: "none",
        name: "Just Ziggy",
        blurb: "No extras",
        accessory: nil
    )

    static let all: [ZiggySkin] = [none] + ZiggyAccessory.allCases.map { piece in
        ZiggySkin(
            id: piece.rawValue,
            name: piece.name,
            blurb: blurbs[piece] ?? "",
            accessory: piece
        )
    }

    static func named(_ id: String) -> ZiggySkin {
        all.first { $0.id == id } ?? none
    }

    private static let blurbs: [ZiggyAccessory: String] = [
        .bow:         "A little bow",
        .crown:       "His Majesty",
        .partyHat:    "It's a celebration",
        .beanie:      "Cosy",
        .flowerCrown: "Picked for him",
        .halo:        "He's been good",
        .headphones:  "In his own world",
        .cap:         "Off out",
        .topHat:      "Very formal",
        .sprout:      "Something's growing"
    ]
}
