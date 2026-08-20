//
//  BouquetBuilderView.swift
//  Ziggy
//
//  Making the bouquet.
//
//  Flowers down the left, the bouquet on the right, growing as you tap. New
//  stems are placed for you — fanned out from the tie, tallest in the middle —
//  because a pile of flowers dropped at the same point is not a bouquet, and
//  asking someone to arrange fourteen stems by hand before it looks like
//  anything is asking too much. Everything can still be moved afterwards.
//

import SwiftUI

struct BouquetBuilderView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var bouquet = Bouquet()
    @State private var selectedID: String?
    @State private var writingLetter = false
    @State private var isSending = false
    @State private var sent = false
    @State private var errorText = ""

    // Live gesture state, so a drag feels immediate.
    @State private var dragOffset: CGSize = .zero
    @State private var pinch: Double = 1
    @State private var spin: Double = 0
    @State private var draggingLetter = false

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.96, blue: 0.92),
            Color(red: 0.96, green: 0.93, blue: 0.88)
        ],
        startPoint: .top, endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var ribbon: Color { Color(scrapbookHex: bouquet.ribbonHex) }

    private var selected: BouquetStem? {
        bouquet.stems.first { $0.id == selectedID }
    }

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                HStack(spacing: 0) {
                    palette
                    canvas
                }

                bottomBar
            }

            if writingLetter {
                BouquetLetterEditor(
                    letter: $bouquet.letter,
                    ribbon: ribbon,
                    onDone: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                            writingLetter = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }

            if sent {
                sentOverlay.zIndex(20)
            }
        }
    }

    // MARK: Header

    private var header: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.9)))
            }
            .buttonStyle(BubblePress())

            Spacer()

            VStack(spacing: 1) {
                Text("Build a bouquet")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                Text(bouquet.stems.isEmpty
                     ? "Tap a flower to begin"
                     : "\(bouquet.stems.count) stems")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    guard let last = bouquet.stems.last else { return }
                    bouquet.stems.removeAll { $0.id == last.id }
                    selectedID = nil
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(bouquet.stems.isEmpty ? .secondary : accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.9)))
            }
            .buttonStyle(BubblePress())
            .disabled(bouquet.stems.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: The flower rail

    private var palette: some View {

        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(BouquetFlower.allCases) { flower in
                    Button { add(flower) } label: {
                        flower.view
                            .frame(width: flower.size.width, height: flower.size.height)
                            .scaleEffect(0.44)
                            .frame(width: 68, height: 66)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.85))
                            )
                    }
                    .buttonStyle(BubblePress())
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 10)
            .padding(.trailing, 6)
        }
        .frame(width: 84)
    }

    // MARK: The bouquet

    private var canvas: some View {

        GeometryReader { proxy in

            let size = proxy.size

            ZStack {

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(BouquetPalette.paper.opacity(0.55))

                if bouquet.stems.isEmpty {
                    emptyHint
                }

                BouquetView(bouquet: live, showsLetter: !draggingLetter)

                // The letter rides above the flowers and can be put anywhere.
                if !bouquet.letter.isEmpty {
                    letterHandle(in: size)
                }

                // Taps land on stems through this, and on nothing else.
                ForEach(bouquet.stems.sorted { $0.z < $1.z }) { stem in
                    stemHitArea(stem, in: size)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { selectedID = nil } }
        }
        .padding(.trailing, 10)
        .padding(.vertical, 4)
    }

    /// The bouquet with whatever gesture is in flight applied on top.
    private var live: Bouquet {

        guard let id = selectedID,
              let index = bouquet.stems.firstIndex(where: { $0.id == id })
        else { return bouquet }

        var copy = bouquet
        copy.stems[index].x += Double(dragOffset.width)
        copy.stems[index].y += Double(dragOffset.height)
        copy.stems[index].scale = min(max(copy.stems[index].scale * pinch, 0.4), 2.4)
        copy.stems[index].rotation += spin
        return copy
    }

    private func stemHitArea(_ stem: BouquetStem, in size: CGSize) -> some View {

        let unit = size.width / 280
        let w = stem.flower.size.width * stem.scale * unit
        let h = stem.flower.size.height * stem.scale * unit
        let isOn = stem.id == selectedID

        return RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.001))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? accent.opacity(0.5) : .clear,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            // Only the head is grabbable — the stalk runs down through every
            // other flower and would steal all their taps. Sized and turned
            // exactly like the stem it belongs to, then shifted up its own
            // length so it lands on the head.
            .frame(width: max(w, 34), height: max(h * 0.30, 34))
            .rotationEffect(.degrees(stem.rotation), anchor: .center)
            .offset(
                x: -sin(stem.rotation * .pi / 180) * h * 0.36,
                y: -cos(stem.rotation * .pi / 180) * h * 0.36
            )
            .position(x: stem.x * size.width, y: stem.y * size.height)
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    selectedID = stem.id
                }
            }
            .gesture(transform(stem, in: size))
    }

    private func transform(_ stem: BouquetStem, in size: CGSize) -> some Gesture {

        func engage() {
            if selectedID != stem.id { selectedID = stem.id }
        }

        let drag = DragGesture()
            .onChanged { value in
                engage()
                dragOffset = CGSize(width: value.translation.width / size.width,
                                    height: value.translation.height / size.height)
            }

        let magnify = MagnifyGesture()
            .onChanged { value in
                engage()
                pinch = value.magnification
            }

        let rotate = RotateGesture()
            .onChanged { value in
                engage()
                spin = value.rotation.degrees
            }

        return drag.simultaneously(with: magnify.simultaneously(with: rotate))
            .onEnded { _ in

                defer { dragOffset = .zero; pinch = 1; spin = 0 }

                guard let index = bouquet.stems.firstIndex(where: { $0.id == stem.id })
                else { return }

                bouquet.stems[index].x = min(max(stem.x + Double(dragOffset.width), 0.06), 0.94)
                bouquet.stems[index].y = min(max(stem.y + Double(dragOffset.height), 0.10), 0.92)
                bouquet.stems[index].scale = min(max(stem.scale * pinch, 0.4), 2.4)
                bouquet.stems[index].rotation = stem.rotation + spin
            }
    }

    private func letterHandle(in size: CGSize) -> some View {

        let unit = size.width / 280

        return Color.white.opacity(0.001)
            .frame(width: 62 * bouquet.letter.scale * unit,
                   height: 45 * bouquet.letter.scale * unit)
            .overlay {
                if draggingLetter {
                    BouquetEnvelope(ribbon: ribbon)
                        .frame(width: 62 * bouquet.letter.scale * unit,
                               height: 45 * bouquet.letter.scale * unit)
                        .rotationEffect(.degrees(bouquet.letter.rotation))
                }
            }
            .position(x: bouquet.letter.x * size.width,
                      y: bouquet.letter.y * size.height)
            .onTapGesture { writingLetter = true }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        draggingLetter = true
                        bouquet.letter.x = min(max(
                            Double(value.location.x / size.width), 0.10), 0.90)
                        bouquet.letter.y = min(max(
                            Double(value.location.y / size.height), 0.12), 0.90)
                    }
                    .onEnded { _ in draggingLetter = false }
            )
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 26, weight: .light))
            Text("Pick flowers from the left\nand they'll gather here")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(accent.opacity(0.35))
        .allowsHitTesting(false)
    }

    // MARK: Bottom

    private var bottomBar: some View {

        VStack(spacing: 10) {

            if selected != nil {
                selectedBar
            } else {
                dressingBar
            }

            Button { send() } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(isSending ? "Sending…" : "Give it to her 💐")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: bouquet.isEmpty
                            ? [.gray.opacity(0.5), .gray.opacity(0.4)]
                            : [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(BubblePress())
            .disabled(bouquet.isEmpty || isSending)

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 4)
    }

    /// Wraps, ribbons and the note — what dresses the bouquet rather than
    /// what's in it.
    private var dressingBar: some View {

        VStack(spacing: 8) {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {

                    Button { writingLetter = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "envelope.fill")
                            Text(bouquet.letter.isEmpty ? "Add a note" : "Edit note")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(accent))
                    }
                    .buttonStyle(BubblePress())

                    ForEach(Array(BouquetPalette.wraps.enumerated()), id: \.offset) { index, wrap in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                bouquet.wrapIndex = index
                            }
                        } label: {
                            Circle()
                                .fill(wrap.paper)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(
                                        bouquet.wrapIndex == index ? accent : .black.opacity(0.12),
                                        lineWidth: bouquet.wrapIndex == index ? 2.5 : 1
                                    )
                                )
                        }
                        .buttonStyle(BubblePress())
                    }

                    Rectangle()
                        .fill(.black.opacity(0.08))
                        .frame(width: 1, height: 26)

                    ForEach(BouquetPalette.ribbons, id: \.self) { hex in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                bouquet.ribbonHex = hex
                            }
                        } label: {
                            Circle()
                                .fill(Color(scrapbookHex: hex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().strokeBorder(
                                        bouquet.ribbonHex == hex ? accent : .black.opacity(0.12),
                                        lineWidth: bouquet.ribbonHex == hex ? 2.5 : 1
                                    )
                                )
                        }
                        .buttonStyle(BubblePress())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// What to do with the stem you've picked up.
    private var selectedBar: some View {

        HStack(spacing: 8) {

            stemAction("Bigger", "plus.magnifyingglass") { resize(by: 1.15) }
            stemAction("Smaller", "minus.magnifyingglass") { resize(by: 0.87) }
            stemAction("Turn", "rotate.right") { turn(by: 9) }
            stemAction("Front", "square.3.layers.3d.top.filled") { bringForward() }
            stemAction("Remove", "trash", tint: Color(red: 0.85, green: 0.3, blue: 0.3)) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    bouquet.stems.removeAll { $0.id == selectedID }
                    selectedID = nil
                }
            }
        }
    }

    private func stemAction(
        _ label: String,
        _ icon: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(label).font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint ?? accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.9))
            )
        }
        .buttonStyle(BubblePress())
    }

    // MARK: Editing

    /// Places a new stem so the bouquet arranges itself.
    ///
    /// Stems fan out from the tie: the further from the middle, the more they
    /// lean and the lower they sit, which is what gives a bouquet its dome.
    /// Dropping every flower at the same point would just make a stack.
    private func add(_ flower: BouquetFlower) {

        let count = bouquet.stems.count

        // Alternate sides, leaning a little further out with each pair. The
        // cut ends stay bunched at the tie and only the angle changes, which
        // is what gives a bouquet its dome rather than a row of flowers.
        let side: Double = count.isMultiple(of: 2) ? -1 : 1
        let step = Double(count / 2)

        var stem = BouquetStem(kind: flower.rawValue)
        stem.x = 0.5 + side * min(step * 0.013, 0.055)
        stem.y = 0.80 + Double.random(in: -0.015...0.015)
        stem.rotation = side * min(step * 11.5, 47) + Double.random(in: -3...3)
        stem.scale = 1 - min(step * 0.055, 0.28)
        stem.z = count

        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            bouquet.stems.append(stem)
            selectedID = stem.id
        }
    }

    private func resize(by factor: Double) {
        guard let index = bouquet.stems.firstIndex(where: { $0.id == selectedID }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            bouquet.stems[index].scale = min(max(bouquet.stems[index].scale * factor, 0.4), 2.4)
        }
    }

    private func turn(by degrees: Double) {
        guard let index = bouquet.stems.firstIndex(where: { $0.id == selectedID }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            bouquet.stems[index].rotation += degrees
        }
    }

    private func bringForward() {
        guard let index = bouquet.stems.firstIndex(where: { $0.id == selectedID }) else { return }
        let top = (bouquet.stems.map(\.z).max() ?? 0) + 1
        withAnimation { bouquet.stems[index].z = top }
    }

    // MARK: Sending

    private func send() {

        guard !bouquet.isEmpty, !isSending else { return }

        isSending = true
        errorText = ""
        selectedID = nil

        FirestoreManager.shared.sendBouquet(bouquet) { ok in

            isSending = false

            guard ok else {
                errorText = "Couldn't send. Check your connection 💐"
                return
            }

            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { sent = true }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { dismiss() }
        }
    }

    private var sentOverlay: some View {

        ZStack {

            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 14) {

                BouquetView(bouquet: bouquet)
                    .frame(width: 190, height: 230)

                Text("On its way 💐")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(accent)

                Text("She'll see it the moment she opens Ziggy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.96, blue: 0.93))
            )
            .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}
