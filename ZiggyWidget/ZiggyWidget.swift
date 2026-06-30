//
//  ZiggyWidget.swift
//  ZiggyWidget
//
//  Created by Manrai Singh on 09/05/26.
//

import WidgetKit
import SwiftUI
import Foundation
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
    /// still fresh (within 12 hours). Returns nil to fall back to the
    /// default mood-based widget.
    func partnerMessage() -> (text: String, image: String)? {
        let d = UserDefaults(suiteName: "group.com.manrai.ziggy")
        guard
            let text = d?.string(forKey: "ziggy_widget_msg"),
            let image = d?.string(forKey: "ziggy_widget_img"),
            let time = d?.object(forKey: "ziggy_widget_msg_time") as? Date,
            Date().timeIntervalSince(time) < 12 * 3600
        else { return nil }
        return (text, image)
    }
    func placeholder(in context: Context) -> SimpleEntry {
        let pet = loadPet()

        return SimpleEntry(
            date: Date(),
            imageName: widgetImage(for: pet),
            message: widgetMessage(for: pet),
            mood: pet.mood,
            loveScore: pet.loveScore,
            relationshipDays: pet.relationshipDays,
            colors: widgetColors(for: pet)
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let pet = loadPet()

        return SimpleEntry(
            date: Date(),
            imageName: widgetImage(for: pet),
            message: widgetMessage(for: pet),
            mood: pet.mood,
            loveScore: pet.loveScore,
            relationshipDays: pet.relationshipDays,
            colors: widgetColors(for: pet)
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
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let pet = loadPet()

        let entry = SimpleEntry(
            date: currentDate,
            imageName: widgetImage(for: pet),
            message: widgetMessage(for: pet),
            mood: pet.mood,
            loveScore: pet.loveScore,
            relationshipDays: pet.relationshipDays,
            colors: widgetColors(for: pet)
        )
        return Timeline(entries: [entry], policy: .after(nextUpdate))
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
            "OPEN ZIGGY NOW 🔥",
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
}

// 3. THE VIEW (The Look)
struct ZiggyWidgetEntryView: View {

    var entry: Provider.Entry

    var body: some View {

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
