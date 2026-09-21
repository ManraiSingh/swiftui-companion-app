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
        return Color(red: 0.125, green: 0.122, blue: 0.137)
            .opacity(min(1, 0.55 + weight * 0.45))
    }

    /// The default card weight, for anything that doesn't state one.
    var card: Color { surface(cardOpacity) }

    /// Drives `.primary` and `.secondary` inside the themed screens, which is
    /// what saves hand-colouring seventy-odd labels one at a time.
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    /// How strongly a coloured outline should read.
    ///
    /// The tinted tiles — Doodle, Play, Instant — are drawn with a faint
    /// stroke of their own colour, which is right on a pale background and
    /// disappears completely on a dark one. In the dark the outline is doing
    /// the work the fill used to, so it gets to be three times as present.
    func outline(_ colour: Color) -> Color {
        colour.opacity(isDark ? 0.62 : 0.20)
    }

    /// The app's dark-chocolate button, or the theme's accent when the page
    /// is itself near-black and chocolate-on-black stops reading as a button.
    func solidButton(_ chocolate: Color) -> Color { isDark ? accent : chocolate }

    /// A decorative edge that should recede rather than announce itself.
    ///
    /// The opposite job to `outline(_:)`. There the colour carries meaning and
    /// earns its brightness; here it is trim, and a tinted hairline on a black
    /// page reads as a warning rather than as decoration.
    func quietEdge(_ tint: Color) -> Color {
        isDark ? Color.white.opacity(0.12) : tint
    }

    /// A matching wash behind that outline.
    func tintedFill(_ colour: Color) -> Color {
        colour.opacity(isDark ? 0.14 : 0.0)
    }

    /// The card under a popup.
    ///
    /// Every modal in the app was `.ultraThinMaterial`, and that quietly
    /// breaks here. The app pins itself to the light colour scheme so the
    /// worlds keep their black-on-white ink — which means the system material
    /// resolves *light* whatever the theme is, and a dark theme's popups came
    /// up as pale grey slabs with dark text sitting on them. The material has
    /// to be swapped for a real surface rather than re-tinted.
    ///
    /// Light themes keep the material untouched, so nothing already shipped
    /// changes.
    var popupSurface: AnyShapeStyle {
        isDark
            ? AnyShapeStyle(Color(red: 0.145, green: 0.142, blue: 0.157))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    /// A hand-picked dark colour, kept as-is on light themes and swapped for
    /// the theme's own ink once the surface beneath it has gone dark.
    ///
    /// The counterpart to `solidButton(_:)`, for text rather than fills. The
    /// popups hard-coded the app's chocolate for their titles and their
    /// "Later" buttons, which is dark text on a dark card in the dark themes.
    func inkOr(_ chocolate: Color) -> Color { isDark ? ink : chocolate }

    // MARK: - The set

    static let all: [ZiggyTheme] = [dawn, sunset, meadow, lavender, rose, midnight]

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

    /// The dark one.
    ///
    /// Near-black and neutral rather than navy — a tinted dark theme reads as
    /// a colour choice, and this one should read as the lights being off. The
    /// cards sit a shade above the page so they still lift off it, and the
    /// accent stays pink so the app doesn't lose its character in the dark.
    static let midnight = ZiggyTheme(
        id: "midnight",
        name: "Midnight",
        blurb: "Lights off. Near-black, with everything glowing on top.",
        background: [
            Color(red: 0.043, green: 0.043, blue: 0.051),
            Color(red: 0.071, green: 0.063, blue: 0.082),
            Color(red: 0.051, green: 0.047, blue: 0.059)
        ],
        accent: Color(red: 1.00, green: 0.30, blue: 0.55),
        ink: Color(red: 0.97, green: 0.97, blue: 0.98),
        inkSoft: Color(red: 0.62, green: 0.62, blue: 0.66),
        surfaceTint: Color.white,
        cardOpacity: 0.80,
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
