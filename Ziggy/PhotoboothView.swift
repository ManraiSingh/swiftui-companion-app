//
//  PhotoboothView.swift
//  Ziggy
//
//  A booth the two of you sit in from different cities.
//
//  Four phases on one screen: a waiting room, a countdown, three shots, and
//  the strip. The waiting room is the same shape as the games' — both people
//  present, both ready — because that is already how it feels to start
//  something together in this app.
//
//  What makes it a booth rather than two cameras is the clock. Nobody's tap
//  takes the picture: a start time is written once, both phones count down to
//  that same instant, and each fires its own shutter when it arrives. Your
//  half and their half of a frame are then the same moment, not two moments a
//  network round-trip apart.
//

import SwiftUI
import UIKit
// For `Timestamp` — the booth's start time arrives as one, and the whole
// point of it is that both phones read the same instant off the server.
import FirebaseFirestore

struct PhotoboothView: View {

    @ObservedObject var petVM: PetViewModel
    @ObservedObject private var themes = ThemeManager.shared
    @StateObject private var camera = PhotoboothCamera()

    // MARK: Session

    @State private var side: String?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var status = "lobby"
    @State private var startAt: Date?

    // MARK: Shooting

    @State private var ticker: Timer?
    @State private var secondsToNext: Int?
    @State private var shotsTaken = 0
    @State private var flash = false

    @State private var myShots: [UIImage] = []
    @State private var theirShots: [UIImage] = []
    @State private var waitingOnThem = false

    // MARK: The look

    @State private var film: PhotoboothFilm = .original
    @State private var paper: PhotoboothPaper = .classic
    @State private var backdrop: PhotoboothBackdrop = .asIs {
        didSet { camera.backdrop = backdrop }
    }

    @State private var savedToast = false

    @Environment(\.dismiss) private var dismiss

    /// Three shots, 2.5s apart, both phones working off the same start time.
    private let shotCount = 3
    private let gap: TimeInterval = 2.5

    private var username: String { UserManager.shared.username }
    private var iAmLeft: Bool { side == "left" }
    private var isReady: Bool { iAmLeft ? leftReady : rightReady }
    private var theirName: String {
        let n = iAmLeft ? rightPlayer : leftPlayer
        return n.isEmpty ? "your partner" : n
    }
    private var bothHere: Bool { !leftPlayer.isEmpty && !rightPlayer.isEmpty }
    private var bothReady: Bool { leftReady && rightReady }

    // MARK: Body

    var body: some View {

        ZStack {

            themes.theme.gradient.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                switch phase {
                case .lobby:   lobby
                case .shoot:   shooting
                case .review:  review
                }
            }

            if flash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }

            if savedToast { toast }
        }
        .onAppear(perform: connect)
        .onDisappear(perform: leave)
    }

    private enum Phase { case lobby, shoot, review }

    private var phase: Phase {
        if myShots.count >= shotCount && !waitingOnThem { return .review }
        if status == "counting" || status == "shooting" { return .shoot }
        if myShots.count >= shotCount { return .shoot }
        return .lobby
    }

    // MARK: Header

    private var header: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themes.theme.ink)
                    .frame(width: 40, height: 40)
                    .background(themes.theme.surface(0.85), in: Circle())
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Photobooth")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(themes.theme.ink)
                Text(phase == .review ? "Your strip" : "Three shots, together")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(themes.theme.inkSoft)
            }

            Spacer()

            Circle().fill(.clear).frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: Lobby

    private var lobby: some View {

        VStack(spacing: 18) {

            Spacer(minLength: 8)

            boothIllustration

            VStack(spacing: 5) {
                Text("Step in together")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(themes.theme.ink)

                Text("One booth, two cities. When you're both\nready, the countdown takes three shots.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themes.theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 9) {
                seat(name: leftPlayer.isEmpty ? "You" : leftPlayer,
                     ready: leftReady, isMe: iAmLeft)
                seat(name: rightPlayer.isEmpty ? "Waiting for your partner" : rightPlayer,
                     ready: rightReady, isMe: side == "right")
            }
            .padding(.horizontal, 22)

            // Chosen here rather than only at the end: the backdrop is live
            // in the preview now, so it is something you stand in front of
            // while you pose, not a coat of paint applied afterwards.
            picker("Backdrop", PhotoboothBackdrop.allCases, selected: backdrop) { b in
                swatchChip(b.swatch, label: b.label, on: backdrop == b) { backdrop = b }
            }

            Spacer(minLength: 8)

            VStack(spacing: 10) {

                Button(action: toggleReady) {
                    Text(isReady ? "Ready — waiting for them" : "I'm ready")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(isReady ? themes.theme.ink : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isReady
                                      ? AnyShapeStyle(themes.theme.surface(0.9))
                                      : AnyShapeStyle(accentGradient))
                        )
                }
                .disabled(side == nil || !bothHere)
                .opacity(side == nil || !bothHere ? 0.45 : 1)

                if !bothHere {
                    Text(theirName == "your partner"
                         ? "They need to open the booth too."
                         : "\(theirName) needs to open the booth too.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(themes.theme.inkSoft)
                }

                if camera.accessDenied {
                    note("Ziggy needs camera access to use the booth. Turn it on in Settings.")
                } else if camera.unavailable {
                    note("No camera on this device.")
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
    }

    private var boothIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(themes.theme.surface(0.8))
                .frame(width: 128, height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(themes.theme.outline(themes.theme.accent), lineWidth: 1.5)
                )

            VStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 4) {
                        pane
                        pane
                    }
                }
            }
        }
    }

    private var pane: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(themes.theme.accent.opacity(0.35))
            .frame(width: 44, height: 30)
    }

    private func seat(name: String, ready: Bool, isMe: Bool) -> some View {

        HStack(spacing: 11) {

            Image(systemName: ready ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ready ? Color(red: 0.36, green: 0.78, blue: 0.52)
                                       : themes.theme.inkSoft)

            Text(name)
                .font(.system(size: 14, weight: isMe ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(themes.theme.ink)
                .lineLimit(1)

            if isMe {
                Text("YOU")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(themes.theme.inkSoft)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(themes.theme.surface(0.95)))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(themes.theme.surface(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(themes.theme.quietEdge(themes.theme.accent.opacity(0.2)), lineWidth: 1)
        )
    }

    // MARK: Shooting

    private var shooting: some View {

        VStack(spacing: 14) {

            Spacer(minLength: 0)

            ZStack {

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black)

                if camera.isRunning {
                    PhotoboothPreview(session: camera.session, live: camera.liveFrame)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26, weight: .semibold))
                        Text(camera.accessDenied ? "Camera access is off" : "Starting the camera…")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }

                if let n = secondsToNext, n > 0 {
                    Text("\(n)")
                        .font(.system(size: 92, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 14)
                        .transition(.scale.combined(with: .opacity))
                        .id(n)
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding(.horizontal, 18)

            // Which of the three you're on.
            HStack(spacing: 8) {
                ForEach(0..<shotCount, id: \.self) { i in
                    Capsule()
                        .fill(i < shotsTaken
                              ? themes.theme.accent
                              : themes.theme.surface(0.9))
                        .frame(width: i < shotsTaken ? 26 : 18, height: 6)
                }
            }

            Text(waitingOnThem
                 ? "Waiting for \(theirName)'s shots…"
                 : "Shot \(min(shotsTaken + 1, shotCount)) of \(shotCount)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(themes.theme.inkSoft)

            if !waitingOnThem {
                picker("Backdrop", PhotoboothBackdrop.allCases, selected: backdrop) { b in
                    swatchChip(b.swatch, label: b.label, on: backdrop == b) { backdrop = b }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
    }

    // MARK: Review

    private var review: some View {

        VStack(spacing: 0) {

            ScrollView {

                VStack(spacing: 16) {

                    Image(uiImage: strip)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
                        .padding(.horizontal, 54)
                        .padding(.top, 6)

                    picker("Film", PhotoboothFilm.allCases, selected: film) { f in
                        swatchChip(f.swatch, label: f.label, on: film == f) { film = f }
                    }

                    picker("Paper", PhotoboothPaper.allCases, selected: paper) { p in
                        swatchChip([Color(p.background), Color(p.background)],
                                   label: p.label, on: paper == p) { paper = p }
                    }

                    picker("Backdrop", PhotoboothBackdrop.allCases, selected: backdrop) { b in
                        swatchChip(b.swatch, label: b.label, on: backdrop == b) {
                            backdrop = b
                        }
                    }
                }
                .padding(.bottom, 14)
            }

            HStack(spacing: 10) {

                Button(action: retake) {
                    Text("Retake")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(themes.theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(themes.theme.surface(0.9))
                        )
                }

                Button(action: save) {
                    Label("Save strip", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accentGradient)
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
    }

    /// The strip as it currently stands, rebuilt whenever a choice changes.
    private var strip: UIImage {

        let pairs: [(mine: UIImage?, theirs: UIImage?)] = (0..<shotCount).map { i in
            (dressed(myShots[safe: i]), dressed(theirShots[safe: i]))
        }

        return PhotoboothDarkroom.printStrip(
            pairs: pairs,
            film: film,
            paper: paper,
            caption: captionText
        )
    }

    private func dressed(_ image: UIImage?) -> UIImage? {
        guard let image else { return nil }
        guard backdrop != .asIs else { return image }
        return PhotoboothCutout.place(image, on: backdrop)
    }

    private var captionText: String {
        let names = [leftPlayer, rightPlayer].filter { !$0.isEmpty }
        let who = names.isEmpty ? "US" : names.joined(separator: "  &  ").uppercased()
        return "\(who)   ·   \(Date().formatted(.dateTime.day().month(.abbreviated)))"
    }

    private func picker<T: Identifiable, Row: View>(
        _ title: String,
        _ items: [T],
        selected: T,
        @ViewBuilder row: @escaping (T) -> Row
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(themes.theme.inkSoft)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(items) { row($0) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    private func swatchChip(
        _ colours: [Color],
        label: String,
        on: Bool,
        tap: @escaping () -> Void
    ) -> some View {

        Button(action: tap) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: colours,
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(on ? themes.theme.accent
                                       : themes.theme.quietEdge(.black.opacity(0.12)),
                                    lineWidth: on ? 2.5 : 1)
                    )

                Text(label)
                    .font(.system(size: 10, weight: on ? .black : .semibold, design: .rounded))
                    .foregroundStyle(on ? themes.theme.ink : themes.theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium, design: .rounded))
            .foregroundStyle(themes.theme.inkSoft)
            .multilineTextAlignment(.center)
    }

    private var toast: some View {
        VStack {
            Spacer()
            Text("Saved to your photos 📸")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(.black.opacity(0.82)))
                .padding(.bottom, 96)
        }
        .transition(.opacity)
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [themes.theme.accent,
                     themes.theme.accent.opacity(0.75)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    // MARK: Plumbing

    private func connect() {

        camera.backdrop = backdrop
        camera.start()

        FirestoreManager.shared.joinPhotobooth(username: username) { assigned in
            DispatchQueue.main.async { side = assigned }
        }

        FirestoreManager.shared.listenForPhotobooth { data in

            DispatchQueue.main.async {

                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                status = data["status"] as? String ?? "lobby"

                if let ts = data["startAt"] as? Timestamp {
                    let when = ts.dateValue()
                    if startAt != when { beginCountdown(to: when) }
                } else if status == "lobby" {
                    startAt = nil
                }

                // Whoever holds the left seat writes the start time, so two
                // phones can't both set one a moment apart.
                if bothReady, status == "lobby", iAmLeft {
                    FirestoreManager.shared.startPhotobooth()
                }
            }
        }

        if let theirSide = side == "left" ? "right" : "left" as String? {
            FirestoreManager.shared.listenForPhotoboothShots(side: theirSide) { encoded in
                DispatchQueue.main.async {
                    theirShots = encoded.compactMap(decode)
                    if theirShots.count >= shotCount { waitingOnThem = false }
                }
            }
        }
    }

    private func leave() {
        ticker?.invalidate()
        ticker = nil
        camera.stop()
        FirestoreManager.shared.stopPhotoboothListeners()
    }

    private func toggleReady() {
        guard let side else { return }
        FirestoreManager.shared.setPhotoboothReady(side: side, isReady: !isReady)
    }

    /// Counts down to the shared instant, then fires three shutters off it.
    private func beginCountdown(to when: Date) {

        startAt = when
        shotsTaken = 0
        myShots = []
        waitingOnThem = false

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in

            let now = Date()
            let due = when.addingTimeInterval(Double(shotsTaken) * gap)
            let left = due.timeIntervalSince(now)

            if left <= 0 {
                t.invalidate()
                fire()
                return
            }

            let whole = Int(ceil(left))
            if secondsToNext != whole { secondsToNext = whole }
        }
    }

    private func fire() {

        secondsToNext = nil

        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.18)) { flash = false }
        }

        camera.capture { image in

            if let image { myShots.append(image) }
            shotsTaken += 1

            if shotsTaken < shotCount, let when = startAt {
                beginNext(after: when)
            } else {
                finish()
            }
        }
    }

    private func beginNext(after when: Date) {

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in

            let due = when.addingTimeInterval(Double(shotsTaken) * gap)
            let left = due.timeIntervalSince(Date())

            if left <= 0 {
                t.invalidate()
                fire()
                return
            }

            let whole = Int(ceil(left))
            if secondsToNext != whole { secondsToNext = whole }
        }
    }

    private func finish() {

        ticker?.invalidate()
        ticker = nil
        secondsToNext = nil
        waitingOnThem = theirShots.count < shotCount

        guard let side else { return }

        let encoded = myShots.compactMap { $0.photoboothBase64() }
        FirestoreManager.shared.uploadPhotoboothShots(side: side, shots: encoded)
    }

    private func retake() {
        myShots = []
        theirShots = []
        shotsTaken = 0
        waitingOnThem = false
        startAt = nil
        FirestoreManager.shared.resetPhotobooth()
    }

    private func save() {
        UIImageWriteToSavedPhotosAlbum(strip, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { savedToast = false }
        }
    }

    private func decode(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Sizing

private extension UIImage {

    /// One booth shot, small enough that three of them share a document.
    ///
    /// A strip prints each half at roughly 430 points wide, so there is no
    /// use carrying a full-size photo across — and three of those would not
    /// fit under Firestore's ceiling anyway.
    func photoboothBase64(maxBytes: Int = 90_000) -> String? {

        for maxSide in [900, 720, 560] as [CGFloat] {

            let small = scaledForBooth(maxSide: maxSide)
            var quality: CGFloat = 0.7

            while quality >= 0.4 {
                if let data = small.jpegData(compressionQuality: quality),
                   data.count <= maxBytes {
                    return data.base64EncodedString()
                }
                quality -= 0.1
            }
        }

        return scaledForBooth(maxSide: 480)
            .jpegData(compressionQuality: 0.4)?
            .base64EncodedString()
    }

    func scaledForBooth(maxSide: CGFloat) -> UIImage {

        let scale = min(maxSide / size.width, maxSide / size.height, 1.0)
        let newSize = CGSize(width: (size.width * scale).rounded(),
                             height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
