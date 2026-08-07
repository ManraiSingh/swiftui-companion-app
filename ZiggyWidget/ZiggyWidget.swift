//
//  ZiggyWidget.swift
//  ZiggyWidget
//
//  Created by Manrai Singh on 09/05/26.
//

import WidgetKit
import SwiftUI
import Foundation
import UIKit
// 1. THE PROVIDER
struct Provider: AppIntentTimelineProvider {
    func loadPet() -> Pet {

        guard
            let data = UserDefaults(
                suiteName: "group.com.manrai.ziggy"
            )?.data(
                forKey: "ziggy_widget_pet"
            ),
            let pet = try? JSONDecoder().decode(
                Pet.self,
                from: data
            )
        else {

            return Pet()
        }

        return pet
    }
    func latestEmotion() -> String {

        UserDefaults(
            suiteName: "group.com.manrai.ziggy"
        )?.string(
            forKey: "ziggy_widget_emotion"
        )
        ?? "Someone is thinking about you ❤️"
    }

    /// The latest cute message + Ziggy emotion your partner sent, if it's
    /// still fresh. Returns nil to fall back to the
    /// default mood-based widget.
    func partnerMessage() -> (text: String, image: String)? {
        let d = UserDefaults(suiteName: "group.com.manrai.ziggy")
        guard
            let text = d?.string(forKey: "ziggy_widget_msg"),
            let image = d?.string(forKey: "ziggy_widget_img"),
            let expiresAt = d?.object(
                forKey: "ziggy_widget_msg_expires_at"
            ) as? Date,
            expiresAt > Date()
        else { return nil }
        return (text, image)
    }

    private func doodleFileURL() -> URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.manrai.ziggy"
            )?
            .appendingPathComponent("partner_doodle.png")
    }

    /// The partner's latest hand-drawn doodle, if it's still fresh and newer
    /// than any pending message. Returns image data + who drew it.
    func partnerDoodle() -> (data: Data, sender: String)? {
        let d = UserDefaults(suiteName: "group.com.manrai.ziggy")

        guard
            let time = d?.object(forKey: "ziggy_widget_doodle_time") as? Date,
            let expiresAt = d?.object(
                forKey: "ziggy_widget_doodle_expires_at"
            ) as? Date,
            expiresAt > Date()
        else { return nil }

        let isPinned = d?.bool(forKey: "ziggy_widget_doodle_pinned") ?? false

        // Let a newer one-tap message / instant take priority over the
        // doodle — but only if that message is still active, and only if
        // the doodle isn't pinned. A pinned doodle stays no matter what
        // else happens, until a new doodle replaces it.
        if !isPinned,
           let msgTime = d?.object(forKey: "ziggy_widget_msg_time") as? Date,
           let msgExpiresAt = d?.object(
                forKey: "ziggy_widget_msg_expires_at"
           ) as? Date,
           msgExpiresAt > Date(),
           msgTime > time {
            return nil
        }

        let sender = d?.string(forKey: "ziggy_widget_doodle_sender")
            ?? "Your partner"

        if let imageData = d?.data(forKey: "ziggy_widget_doodle_png") {
            return (imageData, sender)
        }

        guard
            let url = doodleFileURL(),
            let imageData = try? Data(contentsOf: url)
        else { return nil }

        return (imageData, sender)
    }

    /// A dedicated, always-romantic pastel palette for the doodle card — it's
    /// a deliberate cute gesture, so it shouldn't inherit the generic
    /// hour-of-day mood gradient (which can turn moody indigo at night).
    let doodleColors: [Color] = [
        Color(red: 1.0, green: 0.75, blue: 0.85),
        Color(red: 0.93, green: 0.80, blue: 1.0)
    ]

    func placeholder(in context: Context) -> SimpleEntry {
        let pet = loadPet()
        let doodle = partnerDoodle()

        return SimpleEntry(
            date: Date(),
            imageName: widgetImage(for: pet),
            message: widgetMessage(for: pet),
            mood: pet.mood,
            loveScore: pet.loveScore,
            relationshipDays: pet.relationshipDays,
            colors: doodle != nil ? doodleColors : widgetColors(for: pet),
            roomMoodImage: pet.settledMoodImage,
            doodleImageData: doodle?.data,
            doodleSender: doodle?.sender ?? "Your partner"
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let pet = loadPet()
        let doodle = partnerDoodle()

        return SimpleEntry(
            date: Date(),
            imageName: widgetImage(for: pet),
            message: widgetMessage(for: pet),
            mood: pet.mood,
            loveScore: pet.loveScore,
            relationshipDays: pet.relationshipDays,
            colors: doodle != nil ? doodleColors : widgetColors(for: pet),
            roomMoodImage: pet.settledMoodImage,
            doodleImageData: doodle?.data,
            doodleSender: doodle?.sender ?? "Your partner"
        )
    }
    func hoursSinceLastOpen() -> Double {

        guard
            let lastOpen = UserDefaults(
                suiteName: "group.com.manrai.ziggy"
            )?.object(
                forKey: "last_app_open_time"
            ) as? Date
        else {

            return 999
        }

        return Date()
            .timeIntervalSince(lastOpen) / 3600
    }

    func currentHour() -> Int {

        Calendar.current.component(
            .hour,
            from: Date()
        )
    }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let nextUpdate = partnerMessageExpiry()
            ?? Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let pet = loadPet()
        let doodle = partnerDoodle()

        let entry = SimpleEntry(
            date: currentDate,
            imageName: widgetImage(for: pet),
            message: widgetMessage(for: pet),
            mood: pet.mood,
            loveScore: pet.loveScore,
            relationshipDays: pet.relationshipDays,
            colors: doodle != nil ? doodleColors : widgetColors(for: pet),
            roomMoodImage: pet.settledMoodImage,
            doodleImageData: doodle?.data,
            doodleSender: doodle?.sender ?? "Your partner"
        )
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func partnerMessageExpiry() -> Date? {
        guard
            let expiresAt = UserDefaults(
                suiteName: "group.com.manrai.ziggy"
            )?.object(
                forKey: "ziggy_widget_msg_expires_at"
            ) as? Date,
            expiresAt > Date()
        else { return nil }

        return expiresAt
    }
    /// Mirrors `ContentView.currentEmotionImage` exactly — same love-score
    /// bands, same faces — so the widget and the Home screen always show
    /// Ziggy in the same mood instead of drifting apart.
    func widgetImage(for pet: Pet) -> String {

        // Prefer the emotion your partner just sent. (The app does the same
        // with its ephemeral message.)
        if let pm = partnerMessage() { return pm.image }

        return pet.moodImage
    }

    /// The same wording as before, but keyed to the love-score bands the face
    /// now uses — otherwise a crying Ziggy could sit under "Best day ever ✨".
    func widgetMessage(for pet: Pet) -> String {

        // Prefer the actual cute message your partner just sent.
        if let pm = partnerMessage() { return pm.text }

        // Keyed to the face he ends up wearing, so the words and the
        // picture can never contradict each other.
        switch widgetImage(for: pet) {

        case "ziggy_loveeyes":
            return [
                "Thinking about you ❤️",
                "You're my favorite ❤️",
                "Best day ever ✨",
                "Can we cuddle?"
            ].randomElement()!

        case "ziggy_happie":
            return [
                "Let's play soon!",
                "Hope you're smiling ✨",
                "Having a good day?",
                "Miss you a little ❤️"
            ].randomElement()!

        case "ziggy_sleep":
            return [
                "Dreaming of you 😴",
                "Good night ❤️",
                "See you tomorrow 🌙",
                "Zzz..."
            ].randomElement()!

        case "ziggu_cry":
            return [
                "Where are you? 🥺",
                "I've been waiting...",
                "Come back ❤️",
                "Miss you..."
            ].randomElement()!

        case "ziggy_angrywithmark":
            return [
                "You forgot me 😤",
                "Still waiting...",
                "Not fair.",
                "Hello???"
            ].randomElement()!

        case "ziggy_angrywithhands":
            return [
                "Nobody fed me today 🍖",
                "My bowl is empty 🍖",
                "Dinner? Anyone?",
                "Still hungry over here 😤"
            ].randomElement()!

        default:
            return [
                "OPEN \(pet.name.uppercased()) NOW 🔥",
                "WE NEED TO TALK 😤",
                "I'M UPSET 😭",
                "HELLO HUMAN."
            ].randomElement()!
        }
    }
    func widgetColors(for pet: Pet) -> [Color] {

        let hour = currentHour()

        let hoursAway = hoursSinceLastOpen()

        if hour >= 22 || hour < 7 {

            return [
                .indigo,
                .blue
            ]
        }

        if hoursAway < 3 {

            return [
                .pink,
                .purple
            ]
        }

        if hoursAway < 8 {

            return [
                .yellow,
                .orange
            ]
        }

        if hoursAway < 16 {

            return [
                .cyan,
                .blue
            ]
        }

        if hoursAway < 24 {

            return [
                .orange,
                .red
            ]
        }

        return [
            .red,
            .black
        ]
    }
}

// 2. THE DATA MODEL
struct SimpleEntry: TimelineEntry {
    let date: Date
    let imageName: String
    let message: String
    let mood: String

    let loveScore: Int
    let relationshipDays: Int
    let colors: [Color]

    /// The pet's own mood, ignoring any partner message currently overriding
    /// the face. The room is keyed off this so a note arriving at midnight
    /// changes Ziggy without swapping the night room for the afternoon one.
    var roomMoodImage: String = "ziggy_happie"

    var doodleImageData: Data? = nil
    var doodleSender: String = "Your partner"
}

/// The room behind Ziggy, matched to the mood he's wearing — the same
/// scenes the Home screen hero card uses, so the widget feels like part of
/// the same world.
func ziggyRoomImageName(for moodImage: String) -> String {
    switch moodImage {
    case "ziggy_sleep":
        return "nightbackground"
    case "ziggy_tears", "ziggu_cry":
        return "cry"
    default:
        return "Afternoon"
    }
}

// 3. THE VIEW (The Look)
struct ZiggyWidgetEntryView: View {

    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                ZiggyWidgetBackground(entry: entry, family: family)
            }
    }

    @ViewBuilder
    private var content: some View {

        if let data = entry.doodleImageData,
           let uiImage = UIImage(data: data) {
            doodleBody(uiImage)
        } else {
            defaultBody
        }
    }

    @ViewBuilder
    private func doodleBody(_ uiImage: UIImage) -> some View {
        // Doodles are drawn on a square canvas. That covers the small widget
        // exactly, but filling a wide one means cropping the sides off the
        // drawing — so the medium keeps the doodle square and gives the space
        // it isn't using to Ziggy.
        switch family {
        case .systemSmall:
            smallDoodleBody(uiImage)
        default:
            mediumDoodleBody(uiImage)
        }
    }

    /// The drawing fully covers the widget, edge-to-edge — no card, no
    /// caption, just the doodle itself. Square canvas in a square widget, so
    /// nothing is lost.
    private func smallDoodleBody(_ uiImage: UIImage) -> some View {

        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    /// Ziggy on the left reacting to it, the drawing kept square on the
    /// right at the size it was drawn for.
    private func mediumDoodleBody(_ uiImage: UIImage) -> some View {

        HStack(spacing: 12) {

            // While a drawing is up he wears his painter's outfit rather than
            // his usual mood face — he's the one who just made it. Reverts on
            // its own when the doodle expires and the normal layout returns.
            Image("ziggy_artist")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
                // Sits him down on the studio floor rather than hovering over
                // it: 12pt cancels the row's bottom padding, the rest covers
                // the empty strip the artist artwork carries below the
                // character and settles him onto the floorboards. Safe as a
                // fixed number because this layout always pairs the same
                // mascot with the same background.
                .padding(.bottom, -30)
                // Fitting inside the row's height left him noticeably smaller
                // than the drawing beside him. There's spare width on this
                // side, so he grows from his feet up into it — the extra
                // reaches into the empty wall above rather than crowding the
                // doodle.
                .scaleEffect(1.10, anchor: .bottom)

            // A clear square sized by the widget's height, with the drawing
            // filling it. Because the doodle is already square this crops
            // nothing — it just stops the wide widget stretching it.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.9), lineWidth: 2.5)
                }
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var defaultBody: some View {
        // The small widget is nearly square, the medium one is wide — the
        // same stacked layout can't serve both, so each gets its own.
        switch family {
        case .systemSmall:
            smallBody
        default:
            mediumBody
        }
    }

    /// Square-ish: the line sits up in the room's empty wall space and Ziggy
    /// drops to the bottom so he's standing on the floor of the picture
    /// rather than floating above it.
    private var smallBody: some View {

        VStack(spacing: 2) {

            Text(entry.message)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                .padding(.top, 12)
                .padding(.horizontal, 10)

            Image(entry.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
                .padding(.bottom, 6)
        }
    }

    /// Wide: Ziggy on the left, the line reading across the space next to
    /// him rather than squashed into two words per row.
    private var mediumBody: some View {

        HStack(spacing: 14) {

            Image(entry.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
                // Starts his box lower and lets it run to the very bottom
                // edge, so he sits down on the floor instead of riding level
                // with the message beside him.
                .padding(.top, 16)

            Text(entry.message)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}
// 4. THE WIDGET CONFIGURATION
/// The room behind Ziggy.
///
/// Split out of `containerBackground` so it can read `widgetFamily` — the
/// small size needs to make a different decision to the medium one.
struct ZiggyWidgetBackground: View {

    let entry: SimpleEntry

    /// Passed in rather than read from the environment: this view is built
    /// inside `containerBackground`, where reading `widgetFamily` isn't
    /// dependable, and the small size needs a different decision to the
    /// medium one.
    let family: WidgetFamily

    private var hasDoodle: Bool { entry.doodleImageData != nil }

    /// A small widget's doodle covers its whole face, so the room behind it
    /// is never visible — decoding one there spends the extension's memory
    /// budget on something nobody can see, and going over that budget is
    /// what leaves the widget stuck on its blurred placeholder.
    private var roomIsVisible: Bool {
        !(hasDoodle && family == .systemSmall)
    }

    var body: some View {

        ZStack {

            // Kept underneath as a fallback, so the widget still looks
            // deliberate if the artwork ever fails to load.
            LinearGradient(
                colors: entry.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if roomIsVisible {

                // A drawing puts Ziggy in his studio; otherwise the room
                // follows his mood.
                Image(hasDoodle
                      ? "art_background"
                      : ziggyRoomImageName(for: entry.roomMoodImage))
                    .resizable()
                    .scaledToFill()

                // These two only exist to keep white text readable — the
                // afternoon room in particular is bright enough to swallow
                // it. The doodle layout has no text at all, so it skips them
                // and the studio stays bright.
                if !hasDoodle {

                    Color.black.opacity(0.22)

                    LinearGradient(
                        colors: [
                            .black.opacity(0.0),
                            .black.opacity(0.42)
                        ],
                        startPoint: .center,
                        endPoint: .top
                    )
                }
            }
        }
    }
}

struct ZiggyWidget: Widget {
    let kind: String = "ZiggyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            // The background is applied inside the entry view, where
            // `widgetFamily` can be read reliably — it decides whether the
            // room is drawn at all.
            ZiggyWidgetEntryView(entry: entry)
        }
        // ADD BOTH SIZES HERE
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Ziggy")
        .description("Your cute connected pet.")
        // Lets the small widget's doodle run edge-to-edge; the medium
        // layouts set their own padding instead.
        .contentMarginsDisabled()
    }
}

// 5. INTENT CONFIGURATION
extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}
