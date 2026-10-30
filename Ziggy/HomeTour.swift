//
//  HomeTour.swift
//  Ziggy
//
//  The first look at the home screen, shown round.
//
//  Once you are home for the first time, every feature lights up in turn with
//  a bubble saying what it does, Ziggy doing the explaining. It runs once.
//

import SwiftUI

/// Something on the home screen the tour points at.
enum HomeTip: Hashable {
    case love, bouquet, ziggy, feed, walk, question, doodle, play, instant, messages
}

enum HomeTourStep {

    /// The tour, for a Ziggy who might have been renamed.
    static func steps(petName name: String, wide: Bool) -> [TourStep<HomeTip>] {
        func step(_ tip: HomeTip?, tab: Int? = nil, _ face: String, _ colour: Color, _ title: String, _ text: String) -> TourStep<HomeTip> {
            TourStep(tip: tip, place: tab.flatMap { tab in wide ? nil : { tabBarItem(tab, in: $0) } }, title: title, text: text,
                     picture: HomeTourPicture(face: face, colour: colour))
        }
        let pink = Color(red: 1, green: 0.88, blue: 0.92)
        let peach = Color(red: 1, green: 0.9, blue: 0.82)
        let sky = Color(red: 0.8, green: 0.91, blue: 0.98)
        let mint = Color(red: 0.87, green: 0.94, blue: 0.8)
        let lilac = Color(red: 0.91, green: 0.87, blue: 0.99)

        return [
            step(.ziggy, "ziggy_happie", mint, "Meet \(name)",
                 "The two of you share \(name). His mood changes with how much love he gets, so look after him together."),
            step(.love, "ziggy_loveeyes", pink, "Your love score",
                 "Everything you do together fills this heart. Quiet days make it drop. Tap it any time to see what earns love."),
            step(.bouquet, "ziggy_loveeyes", peach, "Send a bouquet",
                 "Arrange flowers, add a note, and surprise your partner. It earns love too."),
            step(.feed, "ziggy_angrywithhands", peach, "Feed \(name)",
                 "He gets hungry every day. Feed him to keep him happy."),
            step(.walk, "ziggy_happie", mint, "Go for a walk",
                 "Walk through the park together. The longer you walk, the more love you earn."),
            step(.question, "31", lilac, "A question every day",
                 "\(name) asks you both something new each day. You'll see each other's answers once you've both replied."),
            step(.doodle, "ziggy_happie", lilac, "Doodle",
                 "Draw something and send it straight to your partner."),
            step(.play, "ziggy_happie", mint, "Play games",
                 "Play games together, and finish one to earn love."),
            step(.instant, "ziggy_loveeyes", pink, "Send an Instant",
                 "Snap a photo for your partner, right now. It earns plenty of love too."),
            step(.messages, "ziggy_loveeyes", pink, "Send a little love",
                 "Tap a message to send it, write your own, or make a new one you'll use again."),
            step(nil, tab: 1, "ziggy_happie", peach, "Your scrapbook",
                 "Fill books with your photos, doodles and stickers."),
            step(nil, tab: 2, "ziggy_happie", sky, "Your activity",
                 "All your moments together, in one place."),
            step(nil, tab: 3, "ziggy_happie", lilac, "Settings",
                 "Change your theme, your name and more. That's everything. Have fun!"),
        ]
    }

    /// Where a tab sits in the floating tab bar: four across, near the bottom.
    /// Before iOS 26 the bar is a different shape, so the bubble just sits in
    /// the middle instead.
    private static func tabBarItem(_ index: Int, in size: CGSize) -> CGRect? {
        guard #available(iOS 26.0, *) else { return nil }
        let inset: CGFloat = 21, height: CGFloat = 60, count: CGFloat = 4
        let width = (size.width - inset * 2) / count
        return CGRect(x: inset + width * CGFloat(index), y: size.height - height - 22, width: width, height: height)
    }
}

/// Ziggy, explaining, on a soft tile.
private struct HomeTourPicture: View {

    let face: String
    let colour: Color

    var body: some View {
        Image(face)
            .resizable()
            .scaledToFit()
            .padding(7)
            .frame(width: 64, height: 64)
            .background(RoundedRectangle(cornerRadius: 18).fill(colour))
    }
}
