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

        if let data = entry.doodleImageData,
           let uiImage = UIImage(data: data) {
            doodleBody(uiImage)
        } else {
            defaultBody
        }
    }

    private func doodleBody(_ uiImage: UIImage) -> some View {

        // The drawing fully covers the widget, edge-to-edge — no card,
        // no caption, just the doodle itself.
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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
struct ZiggyWidget: Widget {
    let kind: String = "ZiggyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            ZiggyWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {

                    ZStack {

                        // Kept underneath as a fallback, so the widget still
                        // looks deliberate if the artwork ever fails to load.
                        LinearGradient(
                            colors: entry.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(ziggyRoomImageName(for: entry.imageName))
                            .resizable()
                            .scaledToFill()

                        // The afternoon room in particular is bright enough
                        // to swallow white text, so a flat wash plus a
                        // stronger band behind the message keeps every line
                        // readable. The band sits at the top, where the text
                        // now lives, leaving the floor clean under Ziggy.
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
        // ADD BOTH SIZES HERE
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Ziggy")
        .description("Your cute connected pet.")
        // Let the doodle fill the whole widget edge-to-edge.
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
