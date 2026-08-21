//
//  BouquetBuilderView.swift
//  Ziggy
//
//  Making the bouquet.
//
//  The bouquet fills the screen and the flowers sit in a strip beneath it, so
//  the thing being made is the biggest thing on the page rather than a column
//  squeezed beside a shop shelf.
//
//  A stem is *aimed*, never moved. Its cut end is pinned to the tie and a drag
//  swings the head about it — further round to lean it, further away to
//  lengthen it. That is why a flower can no longer be pulled out of the
//  bouquet, and why tilting one no longer leaves its stalk hanging outside the
//  wrap: there is no longer any way to express either.
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
    @State private var showingDressing = false
    @State private var showingLayers = false
    @State private var paywall: PaywallReason?

    /// The layer being dragged along the strip, and how far it has moved.
    @State private var draggingLayer: String?
    @State private var layerShift: CGFloat = 0

    /// The stem under the finger, so aiming feels immediate.
    @State private var aiming: (id: String, rotation: Double, scale: Double)?
    @State private var draggingLetter = false

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.96, green: 0.93, blue: 0.89)
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
                canvas
                controls
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

            if sent { sentOverlay.zIndex(20) }
        }
        .paywall($paywall)
    }

    // MARK: Header

    private var header: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.92)))
            }
            .buttonStyle(BubblePress())

            Spacer()

            VStack(spacing: 1) {
                Text("Build a bouquet")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                Text(hint)
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
                    .background(Circle().fill(.white.opacity(0.92)))
            }
            .buttonStyle(BubblePress())
            .disabled(bouquet.stems.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// Says what to do next rather than what has happened — a count of stems
    /// tells nobody how to use this.
    private var hint: String {
        if bouquet.stems.isEmpty { return "Tap a flower below to start" }
        if selected != nil       { return "Drag the bloom to aim it" }
        if showingLayers         { return "Tap a layer to edit it" }
        return "\(bouquet.stems.count) stems · keep tapping to add"
    }

    // MARK: The bouquet

    private var canvas: some View {

        GeometryReader { proxy in

            let size = proxy.size

            ZStack {

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BouquetPalette.paper.opacity(0.7))

                if bouquet.stems.isEmpty { emptyHint }

                BouquetView(bouquet: live, showsLetter: !draggingLetter)

                if !bouquet.letter.isEmpty { letterHandle(in: size) }

                ForEach(bouquet.stems.sorted { $0.z < $1.z }) { stem in
                    stemHandle(stem, in: size)
                }

                noteButton
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { selectedID = nil } }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    /// The bouquet with whatever aim is in flight applied on top.
    private var live: Bouquet {

        guard let aiming,
              let index = bouquet.stems.firstIndex(where: { $0.id == aiming.id })
        else { return bouquet }

        var copy = bouquet
        copy.stems[index].rotation = aiming.rotation
        copy.stems[index].scale = aiming.scale
        return copy
    }

    private func unit(in size: CGSize) -> CGFloat {
        BouquetLayout.unit(size)
    }

    /// Where a stem's head lands, given how far it leans and how long it is.
    private func head(of stem: BouquetStem, in size: CGSize) -> CGPoint {

        let length = stem.flower.size.height * stem.scale * unit(in: size) * 0.78
        let radians = stem.rotation * .pi / 180
        let tie = BouquetLayout.tie(size)

        return CGPoint(x: tie.x + sin(radians) * length,
                       y: tie.y - cos(radians) * length)
    }

    private func stemHandle(_ stem: BouquetStem, in size: CGSize) -> some View {

        let shown = live.stems.first { $0.id == stem.id } ?? stem
        let spot = head(of: shown, in: size)
        let grab = max(stem.flower.size.width * shown.scale * unit(in: size), 42)
        let isOn = stem.id == selectedID

        return Circle()
            .fill(Color.white.opacity(0.001))
            .overlay(
                Circle()
                    .stroke(isOn ? accent.opacity(0.45) : .clear,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .frame(width: grab, height: grab)
            .position(spot)
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    selectedID = stem.id
                }
            }
            .gesture(aim(stem, in: size))
    }

    /// Aiming: the angle follows the finger and the length is how far away it
    /// is. Both bounded, so a stem can lean and stretch but never leave.
    private func aim(_ stem: BouquetStem, in size: CGSize) -> some Gesture {

        DragGesture(minimumDistance: 2)
            .onChanged { value in

                if selectedID != stem.id { selectedID = stem.id }

                let tie = BouquetLayout.tie(size)
                let dx = value.location.x - tie.x
                let dy = tie.y - value.location.y

                let angle = atan2(dx, max(dy, 1)) * 180 / .pi
                let reach = sqrt(dx * dx + dy * dy)
                let natural = stem.flower.size.height * unit(in: size) * 0.78

                aiming = (
                    stem.id,
                    min(max(Double(angle), -BouquetStem.maxLean), BouquetStem.maxLean),
                    min(max(Double(reach / max(natural, 1)), 0.6), 1.6)
                )
            }
            .onEnded { _ in
                if let aiming,
                   let index = bouquet.stems.firstIndex(where: { $0.id == aiming.id }) {
                    bouquet.stems[index].rotation = aiming.rotation
                    bouquet.stems[index].scale = aiming.scale
                }
                aiming = nil
            }
    }

    private func letterHandle(in size: CGSize) -> some View {

        let u = unit(in: size)

        return Color.white.opacity(0.001)
            .frame(width: 62 * bouquet.letter.scale * u,
                   height: 45 * bouquet.letter.scale * u)
            .overlay {
                if draggingLetter {
                    BouquetEnvelope(ribbon: ribbon)
                        .frame(width: 62 * bouquet.letter.scale * u,
                               height: 45 * bouquet.letter.scale * u)
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
                        bouquet.letter.x = min(max(Double(value.location.x / size.width), 0.14), 0.86)
                        bouquet.letter.y = min(max(Double(value.location.y / size.height), 0.16), 0.86)
                    }
                    .onEnded { _ in draggingLetter = false }
            )
    }

    /// Writing the note, offered on the bouquet itself.
    ///
    /// It used to live behind the wrapping-paper toggle, which meant finding
    /// it required already knowing it was there — and a note is half the
    /// point of sending flowers.
    private var noteButton: some View {

        Button { writingLetter = true } label: {
            HStack(spacing: 5) {
                Image(systemName: bouquet.letter.isEmpty ? "envelope" : "envelope.open.fill")
                Text(bouquet.letter.isEmpty ? "Add a note" : "Edit note")
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(.white.opacity(0.95)))
            .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
        }
        .buttonStyle(BubblePress())
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down")
                .font(.system(size: 24, weight: .light))
            Text("Tap the flowers below\nand they'll gather here")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(accent.opacity(0.35))
        .allowsHitTesting(false)
    }

    // MARK: Controls

    private var controls: some View {

        VStack(spacing: 9) {

            if selected != nil {
                stemControls
            } else if showingLayers {
                layersPanel
            } else if showingDressing {
                dressingControls
            } else {
                flowerStrip
            }

            HStack(spacing: 10) {

                modeButton(showingDressing ? "leaf.fill" : "paintpalette.fill",
                           on: showingDressing) {
                    showingDressing.toggle()
                    showingLayers = false
                }

                modeButton("square.3.layers.3d", on: showingLayers) {
                    showingLayers.toggle()
                    showingDressing = false
                }
                .disabled(bouquet.stems.isEmpty)
                .opacity(bouquet.stems.isEmpty ? 0.4 : 1)

                Button { send() } label: {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending…" : "Give it to her")
                            .fontWeight(.black)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: bouquet.isEmpty
                                ? [.gray.opacity(0.45), .gray.opacity(0.38)]
                                : [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(BubblePress())
                .disabled(bouquet.isEmpty || isSending)
            }

            if !errorText.isEmpty {
                Text(errorText).font(.caption).foregroundStyle(.red.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    /// The flowers, along the bottom where there's room for them to be big
    /// enough to tell apart.
    private var flowerStrip: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BouquetFlower.allCases) { flower in
                    Button { add(flower) } label: {
                        VStack(spacing: 0) {

                            // Just the bloom. Shown whole, a tall stem either
                            // shrinks the head to nothing or runs down over
                            // the label — and it is the head you pick by.
                            flower.view()
                                .frame(width: flower.size.width, height: flower.size.height)
                                .scaleEffect(0.62, anchor: .top)
                                .frame(width: 62, height: 56, alignment: .top)
                                .clipped()

                            Text(flower.label)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.top, 3)
                                .padding(.bottom, 6)
                        }
                        .frame(width: 68, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.92))
                        )
                    }
                    .buttonStyle(BubblePress())
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 82)
    }

    /// Wrapping paper, ribbon and the note.
    private var dressingControls: some View {

        VStack(spacing: 10) {

            HStack(spacing: 8) {

                Text("Paper")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(BouquetPalette.wraps.enumerated()), id: \.offset) { index, wrap in
                            swatch(wrap.paper, on: bouquet.wrapIndex == index) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    bouquet.wrapIndex = index
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Ribbon")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BouquetPalette.ribbons, id: \.self) { hex in
                            swatch(Color(scrapbookHex: hex), on: bouquet.ribbonHex == hex) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    bouquet.ribbonHex = hex
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 82)
    }

    /// What to do with the stem you've picked.
    private var stemControls: some View {

        VStack(spacing: 8) {

            HStack(spacing: 8) {
                stemAction("Behind", "arrow.down.backward.square") { sendBack() }
                stemAction("Front", "arrow.up.forward.square") { bringForward() }
                stemAction("Copy", "plus.square.on.square") { duplicate() }
                stemAction("Remove", "trash",
                           tint: Color(red: 0.85, green: 0.3, blue: 0.3)) { remove() }
                stemAction("Done", "checkmark") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        selectedID = nil
                    }
                }
            }

            if selected?.flower.takesColour == true {
                HStack(spacing: 8) {

                    Text("Colour")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {

                            swatch(selected?.flower.defaultTint ?? .pink,
                                   on: selected?.tintHex.isEmpty == true) { recolour("") }

                            ForEach(BouquetPalette.tints, id: \.self) { hex in
                                swatch(Color(scrapbookHex: hex),
                                       on: selected?.tintHex == hex) { recolour(hex) }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 82)
    }

    private func modeButton(
        _ icon: String,
        on: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                selectedID = nil
                action()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(on ? .white : accent)
                .frame(width: 50, height: 50)
                .background(Circle().fill(on ? accent : .white.opacity(0.92)))
        }
        .buttonStyle(BubblePress())
    }

    /// Every stem, front of the bouquet first.
    ///
    /// Tapping one picks it up and swaps in the editing controls, the way
    /// selecting a layer does in any design tool. Dragging one along the strip
    /// reorders it, so a bloom can be brought in front of another without
    /// nudging Front repeatedly and counting.
    private var layersPanel: some View {

        let ordered = bouquet.stems.sorted { $0.z > $1.z }

        return VStack(alignment: .leading, spacing: 5) {

            Text("Layers · drag to reorder, tap to edit")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.layerGap) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, stem in
                        layerChip(stem, at: index, of: ordered.count)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 82)
    }

    private static let layerWidth: CGFloat = 56
    private static let layerGap: CGFloat = 8

    private func layerChip(_ stem: BouquetStem, at index: Int, of count: Int) -> some View {

        let lifted = draggingLayer == stem.id

        return stem.flower.view(tint: stem.tint)
            .frame(width: stem.flower.size.width, height: stem.flower.size.height)
            .scaleEffect(0.60, anchor: .top)
            .frame(width: Self.layerWidth, height: 50, alignment: .top)
            .clipped()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(stem.id == selectedID ? accent : .clear, lineWidth: 2)
                    )
            )
            .scaleEffect(lifted ? 1.1 : 1)
            .shadow(color: .black.opacity(lifted ? 0.2 : 0), radius: 8, y: 4)
            .offset(x: lifted ? layerShift : 0)
            .zIndex(lifted ? 1 : 0)
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    selectedID = stem.id
                }
            }
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if draggingLayer != stem.id {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                draggingLayer = stem.id
                            }
                        }
                        layerShift = value.translation.width
                    }
                    .onEnded { value in

                        // How many places it travelled, from how far it moved
                        // against the width of one chip.
                        let step = Self.layerWidth + Self.layerGap
                        let moved = Int((value.translation.width / step).rounded())

                        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                            reorder(stem.id, by: moved, within: count)
                            draggingLayer = nil
                            layerShift = 0
                        }
                    }
            )
    }

    /// Moves a stem through the running order and rewrites every z from it.
    ///
    /// The list runs front-first, so index 0 is the top of the pile — dragging
    /// left brings a bloom forward and right pushes it behind.
    private func reorder(_ id: String, by steps: Int, within count: Int) {

        guard steps != 0 else { return }

        var ordered = bouquet.stems.sorted { $0.z > $1.z }
        guard let from = ordered.firstIndex(where: { $0.id == id }) else { return }

        let to = min(max(from + steps, 0), count - 1)
        guard to != from else { return }

        let moving = ordered.remove(at: from)
        ordered.insert(moving, at: to)

        for (place, stem) in ordered.enumerated() {
            if let index = bouquet.stems.firstIndex(where: { $0.id == stem.id }) {
                bouquet.stems[index].z = ordered.count - place
            }
        }
    }

    private func swatch(_ colour: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(colour)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().strokeBorder(on ? accent : .black.opacity(0.12),
                                          lineWidth: on ? 2.5 : 1)
                )
        }
        .buttonStyle(BubblePress())
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
                    .fill(.white.opacity(0.92))
            )
        }
        .buttonStyle(BubblePress())
    }

    // MARK: Editing

    /// Places a new stem so the bouquet arranges itself.
    ///
    /// Stems alternate sides and lean a little further with each pair, which
    /// is what gives a bouquet its dome. Every cut end sits at the tie.
    private func add(_ flower: BouquetFlower) {

        let count = bouquet.stems.count
        let side: Double = count.isMultiple(of: 2) ? -1 : 1
        let step = Double(count / 2)

        var stem = BouquetStem(kind: flower.rawValue)
        stem.x = BouquetStem.tie.x
        stem.y = BouquetStem.tie.y
        stem.rotation = side * min(step * 10.5, BouquetStem.maxLean)
            + Double.random(in: -3...3)
        stem.scale = 1 - min(step * 0.045, 0.24)
        stem.z = count

        // Deliberately not selected. Selecting swapped the flower strip for
        // the editing controls, so every single flower had to be added, then
        // dismissed with Done, before the next one could be picked. Tap a
        // bloom on the canvas when you actually want to change it.
        withAnimation(.spring(response: 0.44, dampingFraction: 0.7)) {
            bouquet.stems.append(stem)
        }
    }

    private func recolour(_ hex: String) {
        guard let index = bouquet.stems.firstIndex(where: { $0.id == selectedID }) else { return }
        withAnimation(.easeOut(duration: 0.2)) { bouquet.stems[index].tintHex = hex }
    }

    private func bringForward() {
        guard let index = bouquet.stems.firstIndex(where: { $0.id == selectedID }) else { return }
        withAnimation { bouquet.stems[index].z = (bouquet.stems.map(\.z).max() ?? 0) + 1 }
    }

    private func sendBack() {
        guard let index = bouquet.stems.firstIndex(where: { $0.id == selectedID }) else { return }
        withAnimation { bouquet.stems[index].z = (bouquet.stems.map(\.z).min() ?? 0) - 1 }
    }

    private func duplicate() {
        guard var copy = selected else { return }
        copy.id = UUID().uuidString
        copy.rotation = min(max(copy.rotation + 9, -BouquetStem.maxLean), BouquetStem.maxLean)
        copy.z = (bouquet.stems.map(\.z).max() ?? 0) + 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.74)) {
            bouquet.stems.append(copy)
            selectedID = copy.id
        }
    }

    private func remove() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            bouquet.stems.removeAll { $0.id == selectedID }
            selectedID = nil
        }
    }

    // MARK: Sending

    private func send() {

        guard !bouquet.isEmpty, !isSending else { return }

        isSending = true
        errorText = ""
        selectedID = nil

        // The wall is really put up at the shop button, so nobody spends ten
        // minutes arranging flowers they are then refused. This is the backstop
        // for the case where the count moved underneath us — the partner sent
        // one while this bouquet was being made.
        guard !ZiggySubscription.shared.isSubscribed else {
            deliver()
            return
        }

        FirestoreManager.shared.countBouquets { sentSoFar in

            guard ZiggySubscription.shared.canSendBouquet(sentSoFar: sentSoFar) else {
                isSending = false
                paywall = .bouquets
                return
            }

            deliver()
        }
    }

    private func deliver() {

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
                    .frame(width: 200, height: 244)

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
