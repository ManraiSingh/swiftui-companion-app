//
//  PhotoboothLiveFeed.swift
//  Ziggy
//
//  Seeing the other person while you pose.
//
//  Not video — a few small frames a second, relayed through the database the
//  app already talks to. You can see them move, wave and get into position,
//  which is the thing that was missing: posing together is impossible if you
//  cannot see what the other half of the frame is doing.
//
//  Why not a video SDK: that means a third-party account, keys and a monthly
//  bill. Why not Firebase's Realtime Database, which is built for exactly
//  this: adding it means surgery on the Xcode project and switching another
//  product on in the console. Firestore is already here and already open, and
//  at this frame rate it is comfortably inside what it is built for.
//
//  The trick is the rotation. Firestore asks for no more than about one
//  sustained write a second to any single document, so one document at 3fps
//  would be leaning on it. Three documents written in turn are one write a
//  second each, and the reader simply shows whichever is newest.
//

import SwiftUI
import UIKit
import Combine
import FirebaseFirestore

@MainActor
final class PhotoboothLiveFeed: ObservableObject {

    /// The most recent frame from the other side, or nil if nothing has
    /// arrived yet — they may not be in the booth.
    @Published private(set) var partnerFrame: UIImage?

    /// Whether anything has come through recently. Goes false when their
    /// frames dry up, so the screen can say so rather than freezing on a
    /// stale picture of somebody who has walked away.
    @Published private(set) var partnerIsLive = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var mySide = ""
    private var slot = 0
    private var lastSent = Date.distantPast
    private var lastReceived = Date.distantPast
    private var staleCheck: Timer?

    /// Three slots at roughly one write a second each.
    private let slots = 3
    private let interval: TimeInterval = 0.34

    private var liveRef: CollectionReference? {
        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return nil }
        return db.collection("relationships")
            .document(code)
            .collection("games")
            .document("photobooth")
            .collection("live")
    }

    // MARK: Start / stop

    func start(mySide side: String) {

        mySide = side
        let theirs = side == "left" ? "right" : "left"

        guard let ref = liveRef else { return }

        listener?.remove()
        listener = ref
            .whereField("side", isEqualTo: theirs)
            .addSnapshotListener { [weak self] snapshot, error in

                guard error == nil, let docs = snapshot?.documents else { return }

                // Whichever slot was written most recently.
                let newest = docs
                    .compactMap { doc -> (Date, String)? in
                        guard let ts = doc.data()["at"] as? Timestamp,
                              let b64 = doc.data()["frame"] as? String
                        else { return nil }
                        return (ts.dateValue(), b64)
                    }
                    .max { $0.0 < $1.0 }

                guard let newest,
                      let data = Data(base64Encoded: newest.1),
                      let image = UIImage(data: data)
                else { return }

                Task { @MainActor in
                    guard let self else { return }
                    self.partnerFrame = image
                    self.lastReceived = Date()
                    self.partnerIsLive = true
                }
            }

        staleCheck?.invalidate()
        staleCheck = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Three missed frames and they have stopped sending.
                self.partnerIsLive = Date().timeIntervalSince(self.lastReceived) < 2.0
            }
        }
    }

    func stop() {

        listener?.remove()
        listener = nil
        staleCheck?.invalidate()
        staleCheck = nil
        partnerFrame = nil
        partnerIsLive = false

        // Leave nothing of yourself behind in the booth.
        guard let ref = liveRef, !mySide.isEmpty else { return }
        for i in 0..<slots {
            ref.document("\(mySide)\(i)").delete()
        }
    }

    // MARK: Sending

    /// Offers a frame. Most are dropped — only one every `interval` is sent.
    func offer(_ image: UIImage) {

        let now = Date()
        guard now.timeIntervalSince(lastSent) >= interval else { return }
        guard let ref = liveRef, !mySide.isEmpty else { return }

        lastSent = now

        let doc = ref.document("\(mySide)\(slot)")
        slot = (slot + 1) % slots

        let side = mySide

        // Shrinking and encoding is the expensive part, and it has no business
        // on the main thread while a camera preview is running.
        Task.detached(priority: .utility) {
            guard let b64 = image.liveFrameBase64() else { return }
            try? await doc.setData([
                "side": side,
                "frame": b64,
                "at": Timestamp(date: Date())
            ])
        }
    }
}

// MARK: - Sizing

private extension UIImage {

    /// Small and cheap: this is a window onto somebody, not a photograph.
    ///
    /// Around 10 KB a frame at three a second is roughly 30 KB/s each way —
    /// a minute in the booth costs a couple of megabytes.
    nonisolated func liveFrameBase64() -> String? {

        let maxSide: CGFloat = 260
        let scale = min(maxSide / size.width, maxSide / size.height, 1.0)
        let newSize = CGSize(width: (size.width * scale).rounded(),
                             height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let small = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }

        return small.jpegData(compressionQuality: 0.4)?.base64EncodedString()
    }
}
