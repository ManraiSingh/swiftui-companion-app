//
//  ZiggyTheme.swift
//  Ziggy
//
//  The app's colour schemes, and the line drawn around them.
//
//  A theme owns the background, the cards, the accent and the text — the whole
//  surface of the app's own screens.
//
//  What it deliberately does not own is the *worlds*: Scrapbook, Doodle, the
//  five games, the paywall, Ziggy Jump. Those have a look somebody chose —
//  paper and ink, a night sky, a chalkboard — and tinting them would make them
//  worse rather than more consistent.
//
//  That boundary is also what makes this safe. The app pins itself to the
//  light colour scheme, so `.primary` is black everywhere, and the worlds draw
//  black text on white cards exactly as they always have. Themed screens never
//  rely on `.primary`; they ask the theme for their ink and their surfaces by
//  name. Nothing a theme does can reach across that line, which is why adding
//  a dark one cannot quietly break a screen nobody thought to re-check.
//
//  Every card in the app was written as white at some opacity, so `surface(_:)`
//  takes that same number back. The conversion was a straight swap and the
//  relative weighting — heavier card here, lighter there — came through intact.
//

import SwiftUI
import Combine

struct ZiggyTheme: Identifiable, Equatable {

    let id: String
    let name: String
    /// A word about the mood, shown under the name in the picker.
    let blurb: String

    /// Three stops, drawn top-leading to bottom-trailing.
    let background: [Color]

    /// Buttons, highlights, the things that should catch the eye.
    let accent: Color

    /// For labels sitting directly on the background, with nothing behind
    /// them. The one place a dark theme would otherwise lose its text.
    let ink: Color
    let inkSoft: Color

    /// Near-white with a breath of the theme's own hue, so cards belong to
    /// the palette rather than sitting on top of it. Dawn's is pure white,
    /// which is what makes the default theme pixel-identical to before.
    let surfaceTint: Color

    /// Cards lift slightly on a dark background — at the same opacity they
    /// look muddy rather than floating.
    let cardOpacity: Double

    let isDark: Bool

    var gradient: LinearGradient {
        LinearGradient(
            colors: background,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A card at the weight the layout asked for.
    ///
    /// Every card in the app was written as white at some opacity. This takes
    /// that same number and returns the right surface for the theme, so the
    /// conversion is a straight swap and the relative weighting the designer
    /// chose — a heavier card here, a lighter one there — survives intact.
    ///
    /// On a dark theme the meaning has to inverse: a *heavier* card becomes a
    /// more solid slate, and it is lighter than the background rather than
    /// darker, because that is what makes a card read as lifted off the page
    /// instead of cut into it.
    func surface(_ weight: Double) -> Color {
        guard isDark else { return surfaceTint.opacity(weight) }
        return Color(red: 0.20, green: 0.21, blue: 0.33)
            .opacity(min(1, 0.52 + weight * 0.46))
    }

    /// The default card weight, for anything that doesn't state one.
    var card: Color { surface(cardOpacity) }

    /// Drives `.primary` and `.secondary` inside the themed screens, which is
    /// what saves hand-colouring seventy-odd labels one at a time.
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    // MARK: - The set

    /// Midnight is deliberately not in here.
    ///
    /// It is built and works, but it is held back for now. Anyone who had it
    /// selected falls back to Dawn on their own, because `named(_:)` only
    /// resolves ids that are actually offered — so pulling it needs no
    /// migration and putting it back is one line.
    static let all: [ZiggyTheme] = [dawn, sunset, meadow, lavender, rose]

    /// Exactly the colours the app shipped with, so choosing "Dawn" puts
    /// everything back where it was.
    static let dawn = ZiggyTheme(
        id: "dawn",
        name: "Dawn",
        blurb: "The original. Soft cream, mint and pale blue.",
        background: [
            Color(red: 0.98, green: 0.96, blue: 0.91),
            Color(red: 0.90, green: 0.97, blue: 0.94),
            Color(red: 0.92, green: 0.94, blue: 0.99)
        ],
        accent: Color(red: 0.95, green: 0.45, blue: 0.55),
        ink: Color(red: 0.16, green: 0.15, blue: 0.18),
        inkSoft: Color(red: 0.42, green: 0.41, blue: 0.45),
        surfaceTint: Color.white,
        cardOpacity: 0.76,
        isDark: false
    )

    static let sunset = ZiggyTheme(
        id: "sunset",
        name: "Sunset",
        blurb: "Warm peach and apricot, like late afternoon.",
        background: [
            Color(red: 1.00, green: 0.93, blue: 0.84),
            Color(red: 0.99, green: 0.85, blue: 0.79),
            Color(red: 0.97, green: 0.79, blue: 0.82)
        ],
        accent: Color(red: 0.93, green: 0.42, blue: 0.32),
        ink: Color(red: 0.26, green: 0.15, blue: 0.13),
        inkSoft: Color(red: 0.50, green: 0.37, blue: 0.34),
        surfaceTint: Color(red: 1.00, green: 0.985, blue: 0.975),
        cardOpacity: 0.80,
        isDark: false
    )

    static let meadow = ZiggyTheme(
        id: "meadow",
        name: "Meadow",
        blurb: "Fresh sage and sky. Calm and green.",
        background: [
            Color(red: 0.91, green: 0.97, blue: 0.91),
            Color(red: 0.86, green: 0.95, blue: 0.93),
            Color(red: 0.88, green: 0.93, blue: 0.86)
        ],
        accent: Color(red: 0.24, green: 0.62, blue: 0.45),
        ink: Color(red: 0.13, green: 0.22, blue: 0.18),
        inkSoft: Color(red: 0.36, green: 0.46, blue: 0.41),
        surfaceTint: Color(red: 0.985, green: 1.00, blue: 0.985),
        cardOpacity: 0.78,
        isDark: false
    )

    static let lavender = ZiggyTheme(
        id: "lavender",
        name: "Lavender",
        blurb: "Dusky violet and periwinkle.",
        background: [
            Color(red: 0.94, green: 0.92, blue: 0.99),
            Color(red: 0.90, green: 0.88, blue: 0.98),
            Color(red: 0.95, green: 0.91, blue: 0.97)
        ],
        accent: Color(red: 0.52, green: 0.38, blue: 0.82),
        ink: Color(red: 0.19, green: 0.16, blue: 0.28),
        inkSoft: Color(red: 0.43, green: 0.40, blue: 0.54),
        surfaceTint: Color(red: 0.990, green: 0.985, blue: 1.00),
        cardOpacity: 0.80,
        isDark: false
    )

    static let rose = ZiggyTheme(
        id: "rose",
        name: "Rose",
        blurb: "Blush and petal pink.",
        background: [
            Color(red: 1.00, green: 0.94, blue: 0.95),
            Color(red: 0.99, green: 0.89, blue: 0.92),
            Color(red: 0.97, green: 0.90, blue: 0.95)
        ],
        accent: Color(red: 0.86, green: 0.30, blue: 0.48),
        ink: Color(red: 0.26, green: 0.14, blue: 0.19),
        inkSoft: Color(red: 0.50, green: 0.36, blue: 0.41),
        surfaceTint: Color(red: 1.00, green: 0.985, blue: 0.992),
        cardOpacity: 0.82,
        isDark: false
    )

    /// The dark one. Finished, tested, and currently withheld — see `all`.
    ///
    /// Kept rather than deleted because everything that makes it work is
    /// still carried by the other themes: `isDark`, the dark branch of
    /// `surface(_:)`, and the hand-drawn titles in Settings and Activity that
    /// replaced system ones UIKit would paint black. Re-adding it to `all` is
    /// the whole job.
    static let midnight = ZiggyTheme(
        id: "midnight",
        name: "Midnight",
        blurb: "Deep navy and indigo, with the cards glowing on top.",
        background: [
            Color(red: 0.09, green: 0.10, blue: 0.20),
            Color(red: 0.14, green: 0.13, blue: 0.27),
            Color(red: 0.10, green: 0.13, blue: 0.24)
        ],
        accent: Color(red: 0.62, green: 0.68, blue: 1.00),
        ink: Color(red: 0.96, green: 0.96, blue: 0.99),
        inkSoft: Color(red: 0.70, green: 0.71, blue: 0.82),
        surfaceTint: Color.white,
        cardOpacity: 0.90,
        isDark: true
    )

    static func named(_ id: String) -> ZiggyTheme {
        all.first { $0.id == id } ?? dawn
    }
}

// MARK: - Manager

/// Holds the chosen theme and remembers it.
///
/// Stored in the shared App Group rather than plain UserDefaults so the
/// widget can read it later without this having to be moved.
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    private static let key = "ziggy_theme_id"
    private static let suite = "group.com.manrai.ziggy"

    @Published var theme: ZiggyTheme {
        didSet {
            guard theme != oldValue else { return }
            UserDefaults(suiteName: Self.suite)?.set(theme.id, forKey: Self.key)
        }
    }

    private init() {
        let saved = UserDefaults(suiteName: Self.suite)?.string(forKey: Self.key)
        theme = ZiggyTheme.named(saved ?? ZiggyTheme.dawn.id)
    }
}

// MARK: - Convenience

extension View {

    /// The standard full-screen background.
    func themedBackground(_ theme: ZiggyTheme) -> some View {
        background(theme.gradient.ignoresSafeArea())
    }
}
