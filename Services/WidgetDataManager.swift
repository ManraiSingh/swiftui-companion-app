//
//  WidgetDataManager.swift
//  Ziggy
//

import Foundation
import WidgetKit
import UIKit

class WidgetDataManager {

    static let shared = WidgetDataManager()

    private let key = "ziggy_widget_pet"

    private let sharedDefaults = UserDefaults(
        suiteName: "group.com.manrai.ziggy"
    )

    func savePet(_ pet: Pet) {

        guard let data = try? JSONEncoder().encode(pet) else { return }

        // Nothing changed — usually the Firestore listener echoing back a
        // write we just made. Reloading here would spend one of the day's
        // widget refreshes to redraw the identical picture.
        //
        // iOS budgets a widget to roughly 40–70 reloads a day and silently
        // ignores the rest, which freezes it until the budget refills. The
        // Simulator enforces no budget at all, so this only ever goes wrong
        // on a real device.
        if sharedDefaults?.data(forKey: key) == data { return }

        sharedDefaults?.set(
            data,
            forKey: key
        )

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Stores the latest cute message + Ziggy emotion image for the widget
    /// (so the partner's widget shows what was just sent), then refreshes it.
    func savePartnerMessage(
        text: String,
        image: String,
        eventID: String = UUID().uuidString,
        expiresAfter seconds: TimeInterval = 30 * 60
    ) {
        sharedDefaults?.set(text, forKey: "ziggy_widget_msg")
        sharedDefaults?.set(image, forKey: "ziggy_widget_img")
        sharedDefaults?.set(Date(), forKey: "ziggy_widget_msg_time")
        sharedDefaults?.set(eventID, forKey: "ziggy_widget_msg_id")
        sharedDefaults?.set(
            Date().addingTimeInterval(seconds),
            forKey: "ziggy_widget_msg_expires_at"
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Partner doodle (dynamic hand-drawn image on the widget)

    /// Shared file location for the partner's latest doodle PNG.
    static func partnerDoodleURL() -> URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.manrai.ziggy"
            )?
            .appendingPathComponent("partner_doodle.png")
    }

    /// Decodes a base64 doodle, downsizes it for the widget's memory budget,
    /// writes it to the shared container, and refreshes the widget.
    /// `pinned` means: keep showing this doodle no matter what else happens
    /// (feed, play, a note, an emotion) until a new doodle arrives or the
    /// sender un-pins it on their next send.
    func cachePartnerDoodle(base64: String, sender: String, pinned: Bool = false) {
        guard let raw = Data(base64Encoded: base64) else { return }
        guard let image = UIImage(data: raw) else { return }
        guard let url = WidgetDataManager.partnerDoodleURL() else { return }

        let resized = WidgetDataManager.downscale(image, maxDimension: 420)
        guard let png = resized.pngData() else { return }

        do {
            try png.write(to: url, options: .atomic)
        } catch {
            return
        }

        // A pinned doodle sticks around indefinitely (30 days, effectively
        // "until replaced"); an unpinned one keeps the original 12h window.
        let expiryInterval: TimeInterval = pinned ? (30 * 24 * 3600) : (12 * 3600)

        sharedDefaults?.set(png, forKey: "ziggy_widget_doodle_png")
        sharedDefaults?.set(sender, forKey: "ziggy_widget_doodle_sender")
        sharedDefaults?.set(Date(), forKey: "ziggy_widget_doodle_time")
        sharedDefaults?.set(pinned, forKey: "ziggy_widget_doodle_pinned")
        sharedDefaults?.set(
            Date().addingTimeInterval(expiryInterval),
            forKey: "ziggy_widget_doodle_expires_at"
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clearDoodleIfExpired() {
        guard
            let expiresAt = sharedDefaults?.object(
                forKey: "ziggy_widget_doodle_expires_at"
            ) as? Date,
            expiresAt <= Date()
        else { return }

        if let url = WidgetDataManager.partnerDoodleURL() {
            try? FileManager.default.removeItem(at: url)
        }
        sharedDefaults?.removeObject(forKey: "ziggy_widget_doodle_sender")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_doodle_time")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_doodle_expires_at")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_doodle_png")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_doodle_pinned")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func downscale(
        _ image: UIImage,
        maxDimension: CGFloat
    ) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        // Force scale = 1 so the OUTPUT PIXEL dimensions actually match
        // newSize. UIGraphicsImageRenderer otherwise defaults to the
        // device's Retina scale (2x/3x), silently doubling/tripling the
        // real pixel size WidgetKit sees — which is what was blowing past
        // WidgetKit's image-archival size limit and hiding the doodle.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func clearPartnerMessageIfExpired() {
        guard
            let expiresAt = sharedDefaults?.object(
                forKey: "ziggy_widget_msg_expires_at"
            ) as? Date,
            expiresAt <= Date()
        else { return }

        sharedDefaults?.removeObject(forKey: "ziggy_widget_msg")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_img")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_msg_time")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_msg_id")
        sharedDefaults?.removeObject(forKey: "ziggy_widget_msg_expires_at")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveRemoteWidgetEvent(_ userInfo: [AnyHashable: Any]) {
        guard
            let title = userInfo["title"] as? String,
            let sender = userInfo["sender"] as? String,
            sender != UserDefaults.standard.string(
                forKey: "ziggy_username"
            )
        else { return }

        let relationshipCode = userInfo["relationshipCode"] as? String ?? ""
        let savedRelationshipCode = UserDefaults.standard.string(
            forKey: "relationship_code"
        ) ?? ""
        if !relationshipCode.isEmpty,
           relationshipCode != savedRelationshipCode {
            return
        }

        let type = userInfo["type"] as? String ?? "love"
        let emotion = userInfo["emotion"] as? String ?? ""
        let eventID = userInfo["eventID"] as? String
            ?? userInfo["emotionID"] as? String
            ?? UUID().uuidString

        let payload = widgetPayload(
            title: title,
            sender: sender,
            type: type,
            emotion: emotion
        )

        savePartnerMessage(
            text: payload.text,
            image: payload.image,
            eventID: eventID
        )
    }

    private func widgetPayload(
        title: String,
        sender: String,
        type: String,
        emotion: String
    ) -> (text: String, image: String) {

        if type == "instant" {
            // Matches the in-app instant widget (see PetViewModel.listenForInstant)
            return (
                "\(sender) sent you an Instant 📸",
                "ziggy_loveeyes"
            )
        }

        if type == "gameInvite" {
            return (
                "\(sender) is inviting you to play \(gameName(emotion)) 🎮",
                "ziggy_happie"
            )
        }

        if type == "activity" {
            let action: String
            if title.contains("fed") {
                action = "fed"
            } else if title.contains("played") {
                action = "played"
            } else if title.contains("pizza") {
                action = "pizza"
            } else if title.contains("hug") {
                action = "hug"
            } else {
                action = "activity"
            }

            return (
                activityText(action: action, sender: sender),
                activityImage(action: action)
            )
        }

        return (
            loveText(title: title, sender: sender),
            image(forEmotion: emotion)
        )
    }

    private func loveText(title: String, sender: String) -> String {
        if title.hasPrefix("custom:") {
            let note = title.replacingOccurrences(of: "custom:", with: "")
            return "\(sender) says: \(note)"
        }

        if title.contains("missing") {
            return "I think \(sender) misses you 🥺"
        }

        if title.contains("good night") {
            return "\(sender) wants you to sleep well 🌙"
        }

        if title.contains("good morning") {
            return "\(sender) says good morning ☀️"
        }

        if title.contains("hug") {
            return "\(sender) wants to hug you 🤗"
        }

        if title.contains("proud") {
            return "\(sender) is so proud of you ⭐️"
        }

        if title.contains("safe") {
            return "\(sender) feels safe with you 🏡"
        }

        return "\(sender) is thinking about you 💭"
    }

    private func activityText(action: String, sender: String) -> String {
        switch action {
        case "fed":
            return "\(sender) fed me just now 🍖"
        case "played":
            return "\(sender) played with me just now 🎾"
        case "pizza":
            return "\(sender) made me pizza just now 🍕"
        case "hug":
            return "\(sender) gave me a hug just now 🤗"
        default:
            return "\(sender) was here just now ✨"
        }
    }

    private func activityImage(action: String) -> String {
        switch action {
        case "hug":
            return "ziggy_loveeyes"
        case "fed", "played", "pizza":
            return "ziggy_happie"
        default:
            return "ziggy_loveeyes"
        }
    }

    private func gameName(_ gameID: String) -> String {
        switch gameID {
        case "traceDrawing":
            return "Trace Together"
        case "pizzaKitchen":
            return "Pizza Kitchen"
        case "airHockey":
            return "Air Hockey"
        case "ticTacToe":
            return "Tic Tac Toe"
        default:
            return "with \(loadPet()?.name ?? "Ziggy")"
        }
    }

    private func image(forEmotion emotion: String) -> String {
        switch emotion {
        case "love":
            return "ziggy_loveeyes"
        case "happy":
            return "ziggy_happie"
        case "sleepy":
            return "ziggy_sleep"
        case "sad", "miss":
            return "ziggy_tears"
        case "grr":
            return "ziggy_angrywithmark"
        default:
            return "ziggy_happie"
        }
    }

    func loadPet() -> Pet? {

        guard
            let data = sharedDefaults?.data(
                forKey: key
            ),
            let pet = try? JSONDecoder().decode(
                Pet.self,
                from: data
            )
        else {
            return nil
        }

        return pet
    }
}
