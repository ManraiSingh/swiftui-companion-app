//
//  ZiggyParkControls.swift
//  Ziggy
//
//  Everything you touch in the park, kept apart from the world itself.
//
//  The thumb pad sits at the bottom of the screen, in the middle, where
//  either thumb reaches it. Everywhere else is for looking around: drag to
//  swing the camera, pinch to move it in and out. Both work at once.
//
//  Ziggy's tricks — and petting him, giving him a treat and playing catch —
//  live behind his picture in the corner, and drop down when you tap him. Below him is voice chat; along the bottom, a present that
//  does something fun when you open it.
//

import SwiftUI

private let parkPink = Color(red: 0.93, green: 0.36, blue: 0.53)

// MARK: - The touch layer

@available(iOS 18.0, *)
struct ParkTouchPad: View {

    /// The thumb pad, -1...1 on each axis. Up on screen is negative y.
    let onStick: (SIMD2<Float>) -> Void
    /// How far the look-around finger moved since last time.
    let onLook: (CGSize) -> Void
    /// The pinch so far, or nil when it ends.
    let onPinch: (CGFloat?) -> Void
    @Binding var autoWalk: Bool

    @State private var walked = false
    @State private var looked = false
    @State private var lastDrag: CGSize = .zero

    var body: some View {
        ZStack(alignment: .bottom) {
            // Anywhere else on the screen looks around.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { drag in
                            onLook(CGSize(width: drag.translation.width - lastDrag.width,
                                          height: drag.translation.height - lastDrag.height))
                            lastDrag = drag.translation
                            if !looked { withAnimation(.easeOut(duration: 0.3)) { looked = true } }
                        }
                        .onEnded { _ in lastDrag = .zero }
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { onPinch($0.magnification) }
                        .onEnded { _ in onPinch(nil) }
                )

            VStack(spacing: 12) {
                if !walked {
                    walkHint.transition(.opacity.combined(with: .scale(scale: 0.8))).allowsHitTesting(false)
                } else if !looked {
                    lookHint.transition(.opacity).allowsHitTesting(false)
                }
                ParkStick(onChange: onStick, autoWalk: $autoWalk) {
                    if !walked { withAnimation(.easeOut(duration: 0.3)) { walked = true } }
                }
            }
            .padding(.bottom, 44)
        }
    }

    private var walkHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.point.up.left.fill")
                .phaseAnimator([0.0, -6.0]) { hand, y in hand.offset(y: y) } animation: { _ in .easeInOut(duration: 0.6) }
            Text("Touch to move")
        }
        .font(.system(size: 14, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(parkPink.opacity(0.9), in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    private var lookHint: some View {
        Label("Drag anywhere to look around", systemImage: "hand.draw.fill")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.22), in: Capsule())
    }
}

// MARK: - The thumb pad

/// Always there at the bottom of the screen. Push the knob the way you want
/// to walk; let go and it springs back.
///
/// Hold it pushed right up for a moment and a lock appears above it; slide
/// your thumb on up onto the lock and let go, and you keep walking on your
/// own until you touch the pad again — auto-run, the way it works in games.
@available(iOS 18.0, *)
private struct ParkStick: View {

    let onChange: (SIMD2<Float>) -> Void
    @Binding var autoWalk: Bool
    let onFirstTouch: () -> Void

    /// Gesture state rather than plain state: it clears by itself when the
    /// touch ends *or is cancelled*, and a cancelled drag never calls
    /// `onEnded` — which left you walking on your own after a notification
    /// or a system swipe interrupted the thumb.
    @GestureState private var touch: CGSize?
    @State private var heldUpSince: Date?
    @State private var offerLock = false
    @State private var overLock = false

    private let reach: CGFloat = 46
    private var padSize: CGFloat { reach * 2 + 30 }
    /// How far up the thumb has to slide to reach the lock.
    private let lockReach: CGFloat = 120

    private var knob: CGSize {
        if autoWalk && touch == nil { return CGSize(width: 0, height: -reach) }
        guard var offset = touch else { return .zero }
        let length = (offset.width * offset.width + offset.height * offset.height).squareRoot()
        if length > reach {
            offset.width *= reach / length
            offset.height *= reach / length
        }
        return offset
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(touch == nil ? 0.16 : 0.24))
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2.5))
                .overlay {
                    // Four little arrows round the rim.
                    ForEach(0..<4, id: \.self) { k in
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.75))
                            .offset(y: -padSize / 2 + 13)
                            .rotationEffect(.degrees(Double(k) * 90))
                    }
                }
                .frame(width: padSize, height: padSize)
                .overlay {
                    if autoWalk && touch == nil {
                        Circle()
                            .stroke(parkPink.opacity(0.8), lineWidth: 3)
                            .phaseAnimator([1.0, 1.3]) { ring, scale in
                                ring.scaleEffect(scale).opacity(Double(1.3 - scale) * 3)
                            } animation: { _ in .easeOut(duration: 1.1) }
                    }
                }

            Circle()
                .fill(autoWalk && touch == nil ? parkPink : .white)
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .overlay {
                    Image(systemName: autoWalk && touch == nil ? "figure.walk.motion" : "figure.walk")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(autoWalk && touch == nil ? .white : parkPink)
                        .overlay(alignment: .bottomTrailing) {
                            if autoWalk && touch == nil {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(parkPink)
                                    .padding(3)
                                    .background(.white, in: Circle())
                                    .offset(x: 9, y: 7)
                            }
                        }
                }
                .offset(knob)
                .animation(.spring(duration: 0.25, bounce: 0.35), value: touch == nil)

            if offerLock {
                lockBubble
                    .offset(y: -lockReach - 14)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .frame(width: padSize, height: padSize)
        .contentShape(Circle().inset(by: -24))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($touch) { value, state, _ in
                    // Measured from the middle of the pad, so touching
                    // anywhere on it pushes that way straight away.
                    state = CGSize(width: value.location.x - padSize / 2, height: value.location.y - padSize / 2)
                }
                .onChanged { value in
                    onFirstTouch()
                    // Touching the pad again takes back control.
                    if autoWalk { withAnimation { autoWalk = false } }

                    let up = padSize / 2 - value.location.y
                    let across = value.location.x - padSize / 2
                    if up > reach * 0.85 && abs(across) < reach {
                        if heldUpSince == nil { heldUpSince = Date() }
                        if let since = heldUpSince, Date().timeIntervalSince(since) > 0.45, !offerLock {
                            withAnimation(.spring(duration: 0.3)) { offerLock = true }
                        }
                    } else if !overLock {
                        heldUpSince = nil
                        if offerLock { withAnimation { offerLock = false } }
                    }
                    let over = offerLock && up > lockReach
                    if over != overLock {
                        overLock = over
                        if over { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    }
                }
                .onEnded { _ in
                    lockIfOver()
                    reset()
                }
        )
        .onChange(of: touch == nil) { _, ended in
            guard ended else { return }
            // A touch the system ends early never reaches `onEnded`; if the
            // thumb was on the lock when that happened, lock all the same.
            lockIfOver()
            reset()
        }
        .onChange(of: touch) { _, _ in
            let k = touch == nil ? CGSize.zero : knob
            onChange([Float(k.width / reach), Float(k.height / reach)])
        }
    }

    /// The target to slide onto: a lock with an arrow pointing up to it,
    /// that fills in pink once your thumb is on it.
    private var lockBubble: some View {
        ZStack {
            Circle()
                .fill(overLock ? parkPink : .white.opacity(0.94))
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            VStack(spacing: 1) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .heavy))
                Image(systemName: overLock ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(overLock ? .white : parkPink)
        }
        .scaleEffect(overLock ? 1.12 : 1)
        .animation(.spring(duration: 0.2), value: overLock)
    }

    private func lockIfOver() {
        guard overLock else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(duration: 0.3)) { autoWalk = true }
    }

    private func reset() {
        heldUpSince = nil
        overLock = false
        if offerLock { withAnimation { offerLock = false } }
    }
}

// MARK: - Little illustrations

/// A heart, drawn rather than typed, so it matches everything else.
struct ParkHeartShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY + h * 0.95))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.32),
                   control1: CGPoint(x: r.minX + w * 0.28, y: r.minY + h * 0.75),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.55))
        p.addArc(center: CGPoint(x: r.minX + w * 0.25, y: r.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: r.minX + w * 0.75, y: r.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + h * 0.95),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.55),
                   control2: CGPoint(x: r.maxX - w * 0.28, y: r.minY + h * 0.75))
        return p
    }
}

/// The little person you are in the park, drawn as a chibi face: the same
/// big round head, short brown hair for the boy, long hair and a pink bow
/// for the girl, rosy cheeks. Used for emotes and for picking who you are.
@available(iOS 18.0, *)
struct ParkChibi: View {

    enum Eyes { case open, happy, closed }
    enum Mouth { case smile, open }

    let look: ParkLook
    var eyes: Eyes = .open
    var mouth: Mouth = .smile
    var shoulders = false
    var size: CGFloat = 40

    private let skin = Color(red: 0.97, green: 0.84, blue: 0.75)
    private var hair: Color { look == .casual ? Color(red: 0.23, green: 0.15, blue: 0.11) : Color(red: 0.29, green: 0.18, blue: 0.13) }
    private let ink = Color(red: 0.18, green: 0.11, blue: 0.08)
    private let blush = Color(red: 0.96, green: 0.6, blue: 0.62)

    var body: some View {
        let s = size
        ZStack {
            if shoulders {
                // Jumper or dress, with a little collar.
                Capsule()
                    .fill(look == .casual ? Color(red: 0.94, green: 0.89, blue: 0.8) : Color(red: 0.97, green: 0.73, blue: 0.8))
                    .frame(width: s * 0.95, height: s * 0.5)
                    .offset(y: s * 0.55)
                HStack(spacing: s * 0.02) {
                    Ellipse().fill(.white).frame(width: s * 0.16, height: s * 0.1)
                    Ellipse().fill(.white).frame(width: s * 0.16, height: s * 0.1)
                }
                .offset(y: s * 0.36)
            }
            if look == .sundress {
                // Long hair falling behind.
                RoundedRectangle(cornerRadius: s * 0.3)
                    .fill(hair)
                    .frame(width: s * 0.98, height: s * 0.95)
                    .offset(y: s * 0.18)
            }
            Circle().fill(skin).frame(width: s * 0.86, height: s * 0.86).offset(y: s * 0.03)
            // Hair over the top, a soft fringe at the front.
            Circle()
                .fill(hair)
                .frame(width: s * 0.94, height: s * 0.94)
                .offset(y: -s * 0.2)
                .mask(Rectangle().frame(width: s, height: s * 0.7).offset(y: -s * 0.4))
            HStack(spacing: -s * 0.05) {
                ForEach(0..<4, id: \.self) { i in
                    Ellipse().fill(hair).frame(width: s * 0.24, height: s * (i % 3 == 0 ? 0.2 : 0.24))
                }
            }
            .offset(y: -s * 0.08)
            if look == .sundress {
                HStack(spacing: s * 0.01) {
                    Ellipse().fill(Color(red: 0.93, green: 0.36, blue: 0.53)).frame(width: s * 0.2, height: s * 0.15).rotationEffect(.degrees(-20))
                    Circle().fill(Color(red: 0.8, green: 0.25, blue: 0.4)).frame(width: s * 0.08)
                    Ellipse().fill(Color(red: 0.93, green: 0.36, blue: 0.53)).frame(width: s * 0.2, height: s * 0.15).rotationEffect(.degrees(20))
                }
                .offset(x: s * 0.26, y: -s * 0.33)
            }
            // Eyes, cheeks, mouth.
            HStack(spacing: s * 0.2) {
                eye(s)
                eye(s)
            }
            .offset(y: s * 0.1)
            HStack(spacing: s * 0.36) {
                Ellipse().fill(blush.opacity(0.75)).frame(width: s * 0.14, height: s * 0.08)
                Ellipse().fill(blush.opacity(0.75)).frame(width: s * 0.14, height: s * 0.08)
            }
            .offset(y: s * 0.22)
            mouthShape(s).offset(y: s * 0.27)
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder private func eye(_ s: CGFloat) -> some View {
        switch eyes {
        case .open:
            Ellipse().fill(ink)
                .frame(width: s * 0.11, height: s * 0.14)
                .overlay(alignment: .topTrailing) { Circle().fill(.white).frame(width: s * 0.045).offset(x: -s * 0.012, y: s * 0.015) }
        case .happy:
            Path { p in
                p.move(to: CGPoint(x: 0, y: s * 0.07))
                p.addQuadCurve(to: CGPoint(x: s * 0.13, y: s * 0.07), control: CGPoint(x: s * 0.065, y: -s * 0.03))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: max(1.5, s * 0.035), lineCap: .round))
            .frame(width: s * 0.13, height: s * 0.08)
        case .closed:
            Path { p in
                p.move(to: CGPoint(x: 0, y: s * 0.02))
                p.addQuadCurve(to: CGPoint(x: s * 0.13, y: s * 0.02), control: CGPoint(x: s * 0.065, y: s * 0.08))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: max(1.5, s * 0.035), lineCap: .round))
            .frame(width: s * 0.13, height: s * 0.08)
        }
    }

    @ViewBuilder private func mouthShape(_ s: CGFloat) -> some View {
        switch mouth {
        case .smile:
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: s * 0.12, y: 0), control: CGPoint(x: s * 0.06, y: s * 0.07))
            }
            .stroke(Color(red: 0.77, green: 0.32, blue: 0.37), style: StrokeStyle(lineWidth: max(1.2, s * 0.03), lineCap: .round))
            .frame(width: s * 0.12, height: s * 0.05)
        case .open:
            Ellipse().fill(Color(red: 0.77, green: 0.32, blue: 0.37))
                .frame(width: s * 0.13, height: s * 0.1)
                .overlay(alignment: .bottom) { Ellipse().fill(Color(red: 1, green: 0.6, blue: 0.65)).frame(width: s * 0.08, height: s * 0.04) }
        }
    }
}

/// One emote, drawn: you, doing it.
@available(iOS 18.0, *)
struct ParkEmoteIllustration: View {

    let emote: ParkEmote
    let look: ParkLook
    var size: CGFloat = 36

    var body: some View {
        let s = size
        ZStack {
            switch emote {
            case .wave:
                ParkChibi(look: look, eyes: .happy, mouth: .smile, size: s * 0.82)
                    .offset(x: -s * 0.06, y: s * 0.04)
                hand(s).offset(x: s * 0.32, y: -s * 0.12).rotationEffect(.degrees(-12))
                motion(s).offset(x: s * 0.44, y: -s * 0.3)
            case .love:
                ParkChibi(look: look, eyes: .happy, mouth: .smile, size: s * 0.8)
                    .offset(y: s * 0.08)
                ParkHeartShape()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.55, blue: 0.68), parkPink], startPoint: .top, endPoint: .bottom))
                    .overlay(ParkHeartShape().stroke(.white, lineWidth: max(1, s * 0.04)))
                    .frame(width: s * 0.42, height: s * 0.38)
                    .offset(x: s * 0.3, y: -s * 0.3)
            case .yay:
                ParkChibi(look: look, eyes: .happy, mouth: .open, size: s * 0.8)
                    .offset(y: s * 0.08)
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill([parkPink, Color(red: 1, green: 0.8, blue: 0.3), Color(red: 0.5, green: 0.8, blue: 0.95), Color(red: 0.65, green: 0.85, blue: 0.5), Color(red: 0.75, green: 0.6, blue: 0.95)][i])
                        .frame(width: s * 0.08, height: s * 0.14)
                        .rotationEffect(.degrees(Double(i) * 37))
                        .offset(x: s * (CGFloat(i) - 2) * 0.2, y: -s * (0.36 + CGFloat(i % 2) * 0.08))
                }
            case .dance:
                ParkChibi(look: look, eyes: .happy, mouth: .open, size: s * 0.8)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -s * 0.04, y: s * 0.06)
                Image(systemName: "music.note")
                    .font(.system(size: s * 0.3, weight: .black))
                    .foregroundStyle(parkPink)
                    .offset(x: s * 0.36, y: -s * 0.3)
                Image(systemName: "music.note")
                    .font(.system(size: s * 0.2, weight: .black))
                    .foregroundStyle(Color(red: 0.75, green: 0.6, blue: 0.95))
                    .offset(x: -s * 0.38, y: -s * 0.26)
            case .pat, .offer, .toss:
                ParkChibi(look: look, eyes: .happy, mouth: .smile, size: s * 0.8)
            case .bow:
                ParkChibi(look: look, eyes: .closed, mouth: .smile, size: s * 0.8)
                    .rotationEffect(.degrees(10))
                    .scaleEffect(x: 1, y: 0.94)
                    .offset(y: s * 0.12)
                Image(systemName: "sparkle")
                    .font(.system(size: s * 0.22, weight: .black))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.3))
                    .offset(x: s * 0.36, y: -s * 0.3)
            }
        }
        .frame(width: s, height: s)
    }

    /// A little mitten hand, waving.
    private func hand(_ s: CGFloat) -> some View {
        ZStack {
            Capsule().fill(Color(red: 0.97, green: 0.84, blue: 0.75)).frame(width: s * 0.2, height: s * 0.26)
            Capsule().fill(Color(red: 0.97, green: 0.84, blue: 0.75)).frame(width: s * 0.09, height: s * 0.14)
                .rotationEffect(.degrees(-40)).offset(x: -s * 0.1, y: s * 0.03)
        }
        .overlay(Capsule().stroke(Color(red: 0.85, green: 0.66, blue: 0.56), lineWidth: max(0.8, s * 0.02)).frame(width: s * 0.2, height: s * 0.26))
    }

    private func motion(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.03) {
            Capsule().fill(parkPink.opacity(0.7)).frame(width: s * 0.03, height: s * 0.09).rotationEffect(.degrees(30))
            Capsule().fill(parkPink.opacity(0.7)).frame(width: s * 0.03, height: s * 0.07).rotationEffect(.degrees(55))
        }
    }
}

/// A little dog bone, drawn.
struct ParkBoneShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let k = r.height * 0.32
        for (x, y) in [(r.minX + k, r.minY + k), (r.minX + k, r.maxY - k), (r.maxX - k, r.minY + k), (r.maxX - k, r.maxY - k)] {
            p.addEllipse(in: CGRect(x: x - k, y: y - k, width: 2 * k, height: 2 * k))
        }
        p.addRoundedRect(in: CGRect(x: r.minX + k, y: r.midY - r.height * 0.22, width: r.width - 2 * k, height: r.height * 0.44),
                         cornerSize: CGSize(width: 2, height: 2))
        return p
    }
}

// MARK: - Emotes

/// A smiley in the corner. Tap it and a row of emotes slides out beside
/// it; pick one and you do it, and the row tucks itself away again.
@available(iOS 18.0, *)
struct ParkEmoteMenu: View {

    let look: ParkLook
    let perform: (ParkEmote) -> Void
    @State private var open = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { open.toggle() }
        } label: {
            ParkChibi(look: look, eyes: .happy, mouth: .open, size: 34)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.94)))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: open ? "chevron.right" : "chevron.left")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(parkPink, in: Circle())
                        .offset(x: 2, y: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Emotes")
        // Floats out to the left over the screen, so it moves nothing.
        .overlay(alignment: .trailing) {
            if open {
                row
                    .fixedSize()
                    .offset(x: -54)
                    .transition(.scale(scale: 0.4, anchor: .trailing).combined(with: .opacity))
            }
        }
    }

    private var row: some View {
        HStack(spacing: 4) {
            ForEach(ParkEmote.menu, id: \.self) { emote in
                Button {
                    perform(emote)
                    withAnimation(.spring(duration: 0.3)) { open = false }
                } label: {
                    VStack(spacing: 1) {
                        ParkEmoteIllustration(emote: emote, look: look, size: 30)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(parkPink.opacity(0.1)))
                        Text(emote.title)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(parkPink)
                    }
                    .frame(width: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emote.title)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(.white.opacity(0.65)))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: parkPink.opacity(0.18), radius: 10, y: 4)
        )
    }
}

// MARK: - Who are you today?

/// Shown over the park before the walk, while the two of you stand side by
/// side facing the camera: pick yourself, then off you go.
@available(iOS 18.0, *)
struct ParkChooseCard: View {

    let picked: ParkLook
    let pick: (ParkLook) -> Void
    let go: () -> Void

    private let blue = Color(red: 0.45, green: 0.62, blue: 0.98)

    var body: some View {
        VStack {
            VStack(spacing: 4) {
                Text("Who's walking with Ziggy?")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(parkPink)
                Text("Tap to pick yourself 🐾")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule(style: .continuous).fill(.white.opacity(0.94)))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(.top, 70)

            Spacer()

            HStack(spacing: 14) {
                option(.casual, title: "Boy", colour: blue)
                option(.sundress, title: "Girl", colour: parkPink)
            }

            Button(action: go) {
                HStack(spacing: 8) {
                    Text("Let's walk!")
                    Image(systemName: "pawprint.fill")
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 15)
                .background(Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.72), parkPink], startPoint: .top, endPoint: .bottom)))
                .shadow(color: parkPink.opacity(0.35), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 20)
    }

    private func option(_ look: ParkLook, title: String, colour: Color) -> some View {
        let on = picked == look
        return Button { pick(look) } label: {
            VStack(spacing: 4) {
                ParkChibi(look: look, eyes: on ? .happy : .open, mouth: on ? .open : .smile, size: 48)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.white.opacity(on ? 0.9 : 0)))
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(on ? .white : colour)
            }
            .frame(width: 128, height: 92)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(on ? colour : .white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(on ? .white : colour.opacity(0.35), lineWidth: on ? 3 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white, colour)
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(on ? 1.05 : 1)
            .shadow(color: (on ? colour : .black).opacity(on ? 0.35 : 0.1), radius: on ? 12 : 6, y: 4)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: on)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice chat

/// Under Ziggy in the corner: one round button. Before you join, it starts
/// the talking. Once you are in, it shows your partner's face, ringed in
/// pink that glows and swells as you talk; tap it and mute, speaker and
/// hang up drop down, tap again and they tuck away.
@available(iOS 18.0, *)
struct ParkVoicePanel: View {

    let voice: ZiggyParkVoice
    /// Your partner's name from the walk, if they are in the park.
    let partnerName: String?

    private let rose = Color(red: 1.0, green: 0.62, blue: 0.74)
    private let sky = Color(red: 0.62, green: 0.72, blue: 1.0)
    private let coral = Color(red: 1.0, green: 0.45, blue: 0.5)

    @State private var open = false

    var body: some View {
        Group {
            if voice.isOn {
                activeButton.transition(.scale.combined(with: .opacity))
            } else {
                joinButton.transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.35), value: voice.isOn)
        .onChange(of: voice.isOn) { _, on in if !on { open = false } }
    }

    private var joinButton: some View {
        Button { voice.join() } label: {
            VStack(spacing: 3) {
                Image(systemName: voice.state == .noMic ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(parkPink)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.94)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(parkPink, in: Circle())
                            .offset(x: 2, y: 2)
                    }
                Text(voice.state == .noMic ? "Mic is off" : "Talk")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start voice chat")
    }

    /// In a call: one round button, the same size as the others. Your
    /// partner's face, ringed in pink when they talk; tap it for the
    /// controls, which drop down over the screen rather than taking room.
    private var activeButton: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { open.toggle() }
        } label: {
            VStack(spacing: 3) {
                face(letter: initial(of: voice.partnerName.isEmpty ? (partnerName ?? "") : voice.partnerName, fallback: "♥"),
                     colour: rose, level: max(voice.partnerLevel, voice.myLevel * 0.6), here: voice.state == .live, muted: false)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.94)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: voice.muted ? "mic.slash.fill" : (open ? "chevron.up" : "chevron.down"))
                            .font(.system(size: voice.muted ? 7 : 8, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(voice.muted ? coral : parkPink, in: Circle())
                            .offset(x: 2, y: 2)
                    }
                Text(voice.state == .live ? "Live" : "Waiting…")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.state == .live ? "Voice chat on. Show controls" : "Waiting for your partner to join voice chat")
        .overlay(alignment: .topTrailing) {
            if open {
                controls
                    .fixedSize()
                    .offset(y: 72)
                    .transition(.scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    /// Mute, speaker and hang up, in a little frosted row.
    private var controls: some View {
        HStack(spacing: 8) {
            face(letter: initial(of: UserManager.shared.username, fallback: "Me"),
                 colour: sky, level: voice.myLevel, here: true, muted: voice.muted)
            control(voice.muted ? "mic.slash.fill" : "mic.fill", on: voice.muted) { voice.toggleMute() }
                .accessibilityLabel(voice.muted ? "Unmute" : "Mute")
            control(voice.speaker ? "speaker.wave.2.fill" : "ear.fill", on: false) { voice.toggleSpeaker() }
                .accessibilityLabel(voice.speaker ? "Use earpiece" : "Use speaker")
            Button { voice.leave() } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(coral))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Leave voice chat")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(.white.opacity(0.6)))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: parkPink.opacity(0.18), radius: 10, y: 4)
        )
    }

    /// A round face with your initial; a pink ring lights up and swells
    /// with your voice. Waiting for your partner, a dotted ring turns.
    private func face(letter: String, colour: Color, level: Float, here: Bool, muted: Bool) -> some View {
        let speaking = here && !muted && level > 0.06
        let glow = CGFloat(min(1, level * 1.4))
        return ZStack {
            if here {
                Circle()
                    .stroke(parkPink, lineWidth: 2.5)
                    .frame(width: 42, height: 42)
                    .scaleEffect(1 + glow * 0.2)
                    .opacity(speaking ? 0.45 + Double(glow) * 0.55 : 0)
                    .shadow(color: parkPink.opacity(speaking ? 0.8 : 0), radius: 3 + glow * 6)
            } else {
                Circle()
                    .stroke(parkPink.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    .frame(width: 42, height: 42)
                    .phaseAnimator([0.0, 360.0]) { ring, angle in ring.rotationEffect(.degrees(angle)) } animation: { _ in .linear(duration: 6) }
            }
            Text(letter)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(LinearGradient(colors: [colour.opacity(0.8), colour], startPoint: .top, endPoint: .bottom)))
                .opacity(here ? 1 : 0.45)
                .overlay(alignment: .bottomTrailing) {
                    if muted {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(parkPink, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .offset(x: 3, y: 3)
                    }
                }
        }
        .frame(width: 44, height: 44)
        .animation(.easeOut(duration: 0.12), value: glow)
    }

    private func control(_ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(on ? .white : parkPink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(on ? parkPink : parkPink.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func initial(of name: String, fallback: String) -> String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? fallback
    }
}

// MARK: - Surprise me

/// A present in the corner. Tap it and something fun happens.
@available(iOS 18.0, *)
struct ParkSurpriseButton: View {

    let action: () -> Void
    @State private var wiggle = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
            wiggle.toggle()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: wiggle)
                    .frame(width: 54, height: 54)
                    .background(
                        LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.4), parkPink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.yellow)
                            .phaseAnimator([0.7, 1.2]) { s, k in s.scaleEffect(k) } animation: { _ in .easeInOut(duration: 0.7) }
                            .offset(x: 3, y: -3)
                    }
                Text("Surprise me")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ziggy's tricks

/// Ziggy's face in the corner. Tap him and a card drops down with what he
/// can do; pick one and the card tucks itself away again.
@available(iOS 18.0, *)
struct ParkTrickMenu: View {

    let perform: (Ziggy3DTrick) -> Void
    let play: (ZiggyPlay) -> Void
    @State private var open = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.3)) { open.toggle() }
            } label: {
                Image("ziggy_happie")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .padding(4)
                    .background(Circle().fill(.white.opacity(0.94)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(parkPink, in: Circle())
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.plain)
            // Floats over the screen rather than taking up room, so opening
            // it never shoves the rest of the top bar about.
            .overlay(alignment: .topTrailing) {
                if open {
                    card
                        .fixedSize()
                        .offset(y: 56)
                        .transition(.scale(scale: 0.4, anchor: .topTrailing).combined(with: .opacity))
                }
            }
        }
    }

    private var card: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill")
                Text("Ask Ziggy to…")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(parkPink)
            .padding(.bottom, 2)

            ForEach(Ziggy3DTrick.allCases, id: \.self) { trick in
                Button {
                    perform(trick)
                    withAnimation(.spring(duration: 0.3)) { open = false }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: trick.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(parkPink.opacity(0.14), in: Circle())
                        Text(trick.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(parkPink)
                    .padding(.horizontal, 8)
                    .frame(width: 136, height: 36)
                    .background(Color(red: 1, green: 0.95, blue: 0.96), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                Text("Play with Ziggy")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(parkPink)
            .padding(.top, 6)
            .padding(.bottom, 2)

            ForEach(ZiggyPlay.allCases, id: \.self) { kind in
                Button {
                    play(kind)
                    withAnimation(.spring(duration: 0.3)) { open = false }
                } label: {
                    HStack(spacing: 8) {
                        Group {
                            if kind == .treat {
                                ParkBoneShape().fill(.white).frame(width: 16, height: 9).rotationEffect(.degrees(-25))
                            } else {
                                Image(systemName: kind == .pet ? "hand.raised.fill" : "tennisball.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.25), in: Circle())
                        Text(kind.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(width: 136, height: 36)
                    .background(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.72), parkPink], startPoint: .top, endPoint: .bottom), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        // A few paw prints wandering across the card, like Ziggy walked on it.
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { k in
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 7))
                        .rotationEffect(.degrees(Double(k) * 18 - 20))
                        .offset(y: k % 2 == 0 ? 0 : -4)
                }
            }
            .foregroundStyle(parkPink.opacity(0.25))
            .offset(x: 12, y: 10)
        }
    }
}
