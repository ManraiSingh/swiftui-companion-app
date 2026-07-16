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
        print("🖼️ [Widget] partnerDoodle() called. suite nil? \(d == nil)")

        guard
            let time = d?.object(forKey: "ziggy_widget_doodle_time") as? Date,
            let expiresAt = d?.object(
                forKey: "ziggy_widget_doodle_expires_at"
            ) as? Date,
            expiresAt > Date()
        else {
            let hasTime = d?.object(forKey: "ziggy_widget_doodle_time") != nil
            let hasExpiry = d?.object(forKey: "ziggy_widget_doodle_expires_at") != nil
            print("🖼️ [Widget] ❌ no fresh doodle. hasTime=\(hasTime) hasExpiry=\(hasExpiry)")
            return nil
        }

        // Let a newer one-tap message / instant take priority over the doodle
        // — but only if that message is still active. Otherwise a stale,
        // already-expired message would permanently block every doodle.
        if let msgTime = d?.object(forKey: "ziggy_widget_msg_time") as? Date,
           let msgExpiresAt = d?.object(
                forKey: "ziggy_widget_msg_expires_at"
           ) as? Date,
           msgExpiresAt > Date(),
           msgTime > time {
            print("🖼️ [Widget] ❌ suppressed — a newer active message exists")
            return nil
        }

        let sender = d?.string(forKey: "ziggy_widget_doodle_sender")
            ?? "Your partner"

        if let imageData = d?.data(forKey: "ziggy_widget_doodle_png") {
            print("🖼️ [Widget] ✅ got \(imageData.count) bytes from UserDefaults blob, sender=\(sender)")
            return (imageData, sender)
        }

        print("🖼️ [Widget] UserDefaults blob missing, trying file fallback")

        guard
            let url = doodleFileURL()
        else {
            print("🖼️ [Widget] ❌ doodleFileURL() is nil — container URL unavailable")
            return nil
        }

        print("🖼️ [Widget] file path: \(url.path), exists=\(FileManager.default.fileExists(atPath: url.path))")

        guard let imageData = try? Data(contentsOf: url) else {
            print("🖼️ [Widget] ❌ could not read file at that path")
            return nil
        }

        print("🖼️ [Widget] ✅ got \(imageData.count) bytes from file, sender=\(sender)")
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
        print("🖼️ [Widget] timeline(for:in:) called — building a fresh entry")
        let currentDate = Date()
        let nextUpdate = partnerMessageExpiry()
            ?? Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let pet = loadPet()
        let doodle = partnerDoodle()
        print("🖼️ [Widget] timeline entry doodle present? \(doodle != nil)")

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
        print("🖼️ [Widget] returning timeline entry, doodleImageData bytes: \(entry.doodleImageData?.count ?? -1)")
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
    func widgetImage(for pet: Pet) -> String {

        // Prefer the emotion your partner just sent.
        if let pm = partnerMessage() { return pm.image }

        let hour = currentHour()

        let hoursAway = hoursSinceLastOpen()

        if hour >= 22 || hour < 7 {

            return "ziggy_sleep"
        }

        if hoursAway < 3 {

            return "ziggy_loveeyes"
        }

        if hoursAway < 8 {

            return "ziggy_happie"
        }

        if hoursAway < 16 {

            return "ziggy_tears"
        }

        if hoursAway < 24 {

            return "ziggy_angrywithmark"
        }

        return "ziggy_fireangry"
    }

    func widgetMessage(for pet: Pet) -> String {

        // Prefer the actual cute message your partner just sent.
        if let pm = partnerMessage() { return pm.text }

        let hour = currentHour()

        let hoursAway = hoursSinceLastOpen()

        if hour >= 22 || hour < 7 {

            return [
                "Dreaming of you 😴",
                "Good night ❤️",
                "See you tomorrow 🌙",
                "Zzz..."
            ].randomElement()!
        }

        if hoursAway < 3 {

            return [
                "Thinking about you ❤️",
                "You're my favorite ❤️",
                "Best day ever ✨",
                "Can we cuddle?"
            ].randomElement()!
        }

        if hoursAway < 8 {

            return [
                "Let's play soon!",
                "Hope you're smiling ✨",
                "Having a good day?",
                "Miss you a little ❤️"
            ].randomElement()!
        }

        if hoursAway < 16 {

            return [
                "Where are you? 🥺",
                "I've been waiting...",
                "Come back ❤️",
                "Miss you..."
            ].randomElement()!
        }

        if hoursAway < 24 {

            return [
                "You forgot me 😤",
                "Still waiting...",
                "Not fair.",
                "Hello???"
            ].randomElement()!
        }

        return [
            "OPEN \(pet.name.uppercased()) NOW 🔥",
            "WE NEED TO TALK 😤",
            "I'M UPSET 😭",
            "HELLO HUMAN."
        ].randomElement()!
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

// 3. THE VIEW (The Look)
struct ZiggyWidgetEntryView: View {

    var entry: Provider.Entry

    var body: some View {

        if let data = entry.doodleImageData {
            if let uiImage = UIImage(data: data) {
                let _ = print("🖼️ [Widget] View rendering DOODLE, \(data.count) bytes decoded fine")
                doodleBody(uiImage)
            } else {
                let _ = print("🖼️ [Widget] ❌ View has \(data.count) bytes but UIImage(data:) failed to decode — falling back")
                defaultBody
            }
        } else {
            let _ = print("🖼️ [Widget] View rendering DEFAULT — entry.doodleImageData is nil")
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

    private var defaultBody: some View {

        VStack(spacing: 4) {

            Text(entry.message)
                .font(
                    .system(
                        size: 14,
                        weight: .heavy,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.horizontal, 8)

            Image(entry.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: .infinity)
                .padding(.bottom, 6)
        }
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

                        LinearGradient(
                            colors: entry.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 140)
                            .offset(x: 50, y: 50)

                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 90)
                            .offset(x: -60, y: -40)
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
