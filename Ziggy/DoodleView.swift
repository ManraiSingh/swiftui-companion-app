import SwiftUI
import PencilKit

// Position is normalized (0...1 in each axis) relative to the square
// canvas, so it scales correctly however large the exported image ends up.
private struct DoodleTextItem: Identifiable {
    let id = UUID()
    var text: String
    var position: CGPoint
    var color: Color
    var fontSize: CGFloat = 32
}

/// A circle with a tail pointing right — the colour preview that appears
/// while a finger is on the spectrum bar.
private struct ColorPin: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.height / 2
        let centre = CGPoint(x: rect.minX + r, y: rect.midY)
        let tip = CGPoint(x: rect.maxX, y: rect.midY)
        let d = tip.x - centre.x
        guard d > r else { return Path(ellipseIn: rect) }

        let tangent = acos(r / d)
        var path = Path()
        path.addArc(
            center: centre,
            radius: r,
            startAngle: .radians(tangent),
            endAngle: .radians(-tangent),
            clockwise: false
        )
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }
}

private struct DoodleEmojiItem: Identifiable {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var fontSize: CGFloat = 48
}

struct DoodleView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var selectedHex = "#FF4FA3"

    /// How far down the spectrum bar the current colour sits, 0...1.
    @State private var colorBarFraction: CGFloat = 0.92

    /// The preview pin only exists while a finger is on the bar.
    @State private var isPickingColor = false

    /// The bar starts open, shrinks to a bead once you begin drawing, and
    /// toggles back open when the bead is tapped.
    @State private var isColorBarOpen = true
    // The canvas's own colour, set from the swatch on the canvas corner.
    @State private var canvasBGHex = "#FFFFFF"
    @State private var showBGPicker = false
    @State private var brushWidth: CGFloat = 22
    @State private var isEraser = false
    @State private var inkType: PKInkingTool.InkType = .pen
    @State private var isSending = false
    @State private var showSentToast = false
    @State private var showPinPrompt = false
    @State private var showPartnerDoodlePopup = false

    @State private var textItems: [DoodleTextItem] = []
    @State private var emojiItems: [DoodleEmojiItem] = []

    // Which sticker the colour palette acts on, and which text / emoji item
    // is currently being typed into directly on the canvas. Only one thing
    // can be edited at a time, so both editors share one focus flag.
    @State private var selectedItemID: UUID?
    @State private var editingTextID: UUID?
    @State private var editingEmojiID: UUID?
    @FocusState private var canvasTextFocused: Bool

    // Font size a sticker had when the current pinch started, so scaling
    // is applied to that rather than compounding every frame.
    @State private var pinchBaseSize: CGFloat?

    @State private var partnerDoodle: UIImage?
    @State private var partnerDoodleSender = ""

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private let palette: [(hex: String, color: Color)] = [
        ("#FF4FA3", .pink),
        ("#9B5DE5", .purple),
        ("#00A6FB", .blue),
        ("#2DD4BF", .mint),
        ("#FFD166", .yellow),
        ("#F97316", .orange),
        ("#EF4444", .red),
        ("#111827", .black),
        ("#FF8FB3", Color(red: 1.0, green: 0.56, blue: 0.70)),
        ("#C77DFF", Color(red: 0.78, green: 0.49, blue: 1.0)),
        ("#4CC9F0", Color(red: 0.30, green: 0.79, blue: 0.94)),
        ("#06D6A0", Color(red: 0.02, green: 0.84, blue: 0.63)),
        ("#8D5524", Color(red: 0.55, green: 0.33, blue: 0.14)),
        ("#7C7C7C", .gray),
        ("#FFFFFF", .white),
        ("#FF477E", Color(red: 1.0, green: 0.28, blue: 0.49))
    ]

    private let inkTypes: [(type: PKInkingTool.InkType, label: String, icon: String)] = [
        (.pen, "Pen", "pencil.tip"),
        (.fountainPen, "Fountain", "paintbrush.pointed.fill"),
        (.marker, "Marker", "highlighter"),
        (.pencil, "Pencil", "pencil"),
        (.monoline, "Monoline", "scribble"),
        (.watercolor, "Watercolor", "drop.fill"),
        (.crayon, "Crayon", "paintpalette.fill")
    ]

    private var username: String { UserManager.shared.username }
    private var selectedColor: Color { Color(UIColor(hex: selectedHex)) }
    private var canvasBGColor: Color { Color(UIColor(hex: canvasBGHex)) }

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                if let partnerDoodle {
                    partnerCard(partnerDoodle)
                }

                canvasCard

                toolbar

                sendButton
            }
            .padding()
            // Without this the keyboard shrinks the whole stack, and since
            // the canvas is a fixed square that pulls its width in too —
            // leaving a narrow strip of canvas with gaps either side. The
            // layout now stays put and the keyboard simply covers the
            // toolbar, with new stickers placed high enough to stay visible.
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if showSentToast {
                toast
            }

            if showPinPrompt {
                pinPromptOverlay
            }

            if showPartnerDoodlePopup, let partnerDoodle {
                partnerDoodlePopupOverlay(partnerDoodle)
            }
        }
        .onAppear {
            configureTool()
            listenForPartner()
        }
        .onChange(of: selectedHex) { configureTool() }
        .onChange(of: brushWidth) { configureTool() }
        .onChange(of: isEraser) { configureTool() }
        .onChange(of: inkType) { configureTool() }
        .onDisappear {
            FirestoreManager.shared.stopDoodleListener()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(accent)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.84))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Doodle 🎨")
                    .font(.title2).fontWeight(.black)
                    .foregroundColor(accent)
                Text("Lands on their Home Screen")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Circle().fill(.clear).frame(width: 42, height: 42)
        }
    }

    // MARK: - Partner's latest doodle

    private func partnerCard(_ image: UIImage) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(width: 64, height: 64)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.pink.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("From \(partnerDoodleSender.isEmpty ? "your partner" : partnerDoodleSender)")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(accent)
                Text("Their latest doodle 💕")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
        .onTapGesture {
            showPartnerDoodlePopup = true
        }
    }

    private func partnerDoodlePopupOverlay(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { showPartnerDoodlePopup = false }

            VStack(spacing: 16) {
                Text("From \(partnerDoodleSender.isEmpty ? "your partner" : partnerDoodleSender)")
                    .font(.headline).fontWeight(.black)
                    .foregroundColor(accent)

                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.pink.opacity(0.2), lineWidth: 1)
                    )

                Button {
                    showPartnerDoodlePopup = false
                } label: {
                    Text("Close")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    // MARK: - Canvas

    private var canvasCard: some View {
        // Square canvas — matches the Home Screen widget's shape (especially
        // the small widget, which is roughly square), so the exported doodle
        // needs no cropping to cover it.
        GeometryReader { geo in
            ZStack {
                DoodleCanvas(
                    canvasView: canvasView,
                    background: UIColor(hex: canvasBGHex),
                    onDrawingBegan: {
                        guard isColorBarOpen else { return }
                        withAnimation(bubble) { isColorBarOpen = false }
                    }
                )
                    .background(canvasBGColor)

                // Bound so the text of the item being edited can be typed
                // straight into on the canvas, rather than through a popup.
                ForEach($textItems) { $item in
                    textItemView(item, text: $item.text)
                        .position(
                            x: item.position.x * geo.size.width,
                            y: item.position.y * geo.size.height
                        )
                        .gesture(textDragGesture(for: item, in: geo.size))
                        .simultaneousGesture(textMagnifyGesture(for: item))
                }

                ForEach($emojiItems) { $item in
                    emojiItemView(item, emoji: $item.emoji)
                        .position(
                            x: item.position.x * geo.size.width,
                            y: item.position.y * geo.size.height
                        )
                        .gesture(emojiDragGesture(for: item, in: geo.size))
                        .simultaneousGesture(emojiMagnifyGesture(for: item))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        // No `maxWidth: .infinity` here. The canvas is square, so when a
        // partner's doodle is sitting above it there's less height to work
        // with and the square comes out narrower than the screen. Stretching
        // the frame anyway left the rounded border spanning the full width
        // with dead space between it and the canvas. Letting the card hug the
        // square keeps them the same size; with no partner doodle there's
        // room for the square to fill the width and nothing changes.
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white, lineWidth: 3)
        )
        .overlay(alignment: .topTrailing) {
            backgroundColorControl
        }
        // Sits on the canvas edge like Snapchat's. Applied after the
        // clipShape above so the preview pin can hang outside the card.
        .overlay(alignment: .trailing) {
            verticalColorBar
                .padding(.vertical, 64)
                .padding(.trailing, 12)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }

    // Sits in the canvas's own top-right corner rather than the toolbar, so
    // it's right where the paper is and costs the toolbar no height.
    private var backgroundColorControl: some View {
        VStack(alignment: .trailing, spacing: 8) {

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    showBGPicker.toggle()
                }
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.94)))
                    .overlay(Circle().stroke(canvasBGColor, lineWidth: 3))
                    .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            if showBGPicker {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(palette, id: \.hex) { item in
                        Button {
                            canvasBGHex = item.hex
                            withAnimation(.easeOut(duration: 0.2)) {
                                showBGPicker = false
                            }
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    Circle().stroke(Color.black.opacity(0.12), lineWidth: 1)
                                    if canvasBGHex == item.hex {
                                        Circle().stroke(accent, lineWidth: 2.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                // 4 swatches of 26 plus the 8pt gaps between them — without
                // this the grid stretches to the canvas's full width.
                .frame(width: 4 * 26 + 3 * 8)
                .padding(10)
                // Shifted inward while the spectrum bar is open, or the
                // right-hand swatches sit underneath it.
                .padding(.trailing, isColorBarOpen ? 30 : 0)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .padding(10)
    }

    // MARK: - Text & emoji stickers

    @ViewBuilder
    private func textItemView(
        _ item: DoodleTextItem,
        text: Binding<String>
    ) -> some View {

        if editingTextID == item.id {

            // No box or border — the placeholder and caret are enough to
            // show where you're typing, so what you see on the canvas is
            // just the text itself.
            TextField("Type…", text: text)
                .font(.system(size: item.fontSize, weight: .bold))
                .foregroundColor(item.color)
                .multilineTextAlignment(.center)
                .focused($canvasTextFocused)
                .submitLabel(.done)
                .onSubmit { finishEditingText() }
                // Capped so a long entry doesn't stretch the field out past
                // the canvas edges while you're typing.
                .frame(minWidth: 140, maxWidth: 230)

        } else {

            Text(item.text)
                .font(.system(size: item.fontSize, weight: .bold))
                .foregroundColor(item.color)
                .fixedSize()
                .shadow(color: selectionGlow(item.id), radius: 7)
                .overlay(alignment: .topTrailing) {
                    stickerDeleteBadge {
                        deleteItem(id: item.id)
                    }
                }
                // Double-tap re-opens it for typing; a single tap picks it
                // out so the toolbar's colours recolour it, and tapping it
                // again lets go so the colours drive the pen once more.
                .onTapGesture(count: 2) { beginEditingText(item.id) }
                .onTapGesture { toggleSelection(item.id) }
        }
    }

    @ViewBuilder
    private func emojiItemView(
        _ item: DoodleEmojiItem,
        emoji: Binding<String>
    ) -> some View {

        if editingEmojiID == item.id {

            // A plain field on the canvas — switch to the emoji keyboard
            // with the 🙂 / globe key and every emoji on the system keyboard
            // is available, not just a fixed grid of favourites.
            TextField("…", text: emoji)
                .font(.system(size: item.fontSize))
                .multilineTextAlignment(.center)
                .focused($canvasTextFocused)
                .submitLabel(.done)
                .onSubmit { finishEditingEmoji() }
                .frame(minWidth: 90, maxWidth: 230)

        } else {

            Text(item.emoji)
                .font(.system(size: item.fontSize))
                .fixedSize()
                .shadow(color: selectionGlow(item.id), radius: 7)
                .overlay(alignment: .topTrailing) {
                    stickerDeleteBadge {
                        deleteItem(id: item.id)
                    }
                }
                .onTapGesture(count: 2) { beginEditingEmoji(item.id) }
                .onTapGesture { toggleSelection(item.id) }
        }
    }

    private func selectionGlow(_ id: UUID) -> Color {
        selectedItemID == id ? accent.opacity(0.55) : .clear
    }

    private func toggleSelection(_ id: UUID) {
        selectedItemID = (selectedItemID == id) ? nil : id
    }

    private func stickerDeleteBadge(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .background(Circle().fill(.white))
        }
        .offset(x: 12, y: -12)
    }

    // MARK: - Sticker selection / editing helpers

    private func recolorSelectedText(to hex: String) {
        guard
            let id = selectedItemID,
            let i = textItems.firstIndex(where: { $0.id == id })
        else { return }

        textItems[i].color = Color(UIColor(hex: hex))
    }

    private func deleteItem(id: UUID) {
        textItems.removeAll { $0.id == id }
        emojiItems.removeAll { $0.id == id }
        if selectedItemID == id { selectedItemID = nil }
        if editingTextID == id { editingTextID = nil }
        if editingEmojiID == id { editingEmojiID = nil }
    }

    private func addTextItem() {
        // Starts near the top of the canvas so it stays visible above the
        // keyboard while you type into it.
        let item = DoodleTextItem(
            text: "",
            position: CGPoint(x: 0.5, y: 0.28),
            color: selectedColor
        )
        textItems.append(item)
        beginEditingText(item.id)
    }

    private func beginEditingText(_ id: UUID) {
        selectedItemID = id
        editingEmojiID = nil
        editingTextID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            canvasTextFocused = true
        }
    }

    private func addEmojiItem() {
        // Same upper-third placement as new text, so it stays visible above
        // the keyboard while you pick an emoji.
        let item = DoodleEmojiItem(
            emoji: "",
            position: CGPoint(x: 0.5, y: 0.28)
        )
        emojiItems.append(item)
        beginEditingEmoji(item.id)
    }

    private func beginEditingEmoji(_ id: UUID) {
        selectedItemID = id
        editingTextID = nil
        editingEmojiID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            canvasTextFocused = true
        }
    }

    private func finishEditingEmoji() {
        canvasTextFocused = false

        if let id = editingEmojiID,
           let i = emojiItems.firstIndex(where: { $0.id == id }),
           emojiItems[i].emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emojiItems.remove(at: i)
            if selectedItemID == id { selectedItemID = nil }
        }

        editingEmojiID = nil
    }

    /// Commits whatever was typed. An item left blank is removed rather than
    /// lingering as an invisible sticker that still counts as canvas content.
    private func finishEditingText() {
        canvasTextFocused = false

        if let id = editingTextID,
           let i = textItems.firstIndex(where: { $0.id == id }),
           textItems[i].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textItems.remove(at: i)
            if selectedItemID == id { selectedItemID = nil }
        }

        editingTextID = nil
    }

    private func textDragGesture(for item: DoodleTextItem, in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let idx = textItems.firstIndex(where: { $0.id == item.id }) else { return }
                textItems[idx].position = CGPoint(
                    x: min(max(value.location.x / size.width, 0.05), 0.95),
                    y: min(max(value.location.y / size.height, 0.05), 0.95)
                )
            }
    }

    private func emojiDragGesture(for item: DoodleEmojiItem, in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let idx = emojiItems.firstIndex(where: { $0.id == item.id }) else { return }
                emojiItems[idx].position = CGPoint(
                    x: min(max(value.location.x / size.width, 0.05), 0.95),
                    y: min(max(value.location.y / size.height, 0.05), 0.95)
                )
            }
    }

    // Two-finger pinch straight on the sticker, the way you'd resize a
    // photo. The size it had when the pinch started is held in
    // `pinchBaseSize` so the scale is applied to that once, rather than
    // multiplying on top of itself every frame.
    private func textMagnifyGesture(for item: DoodleTextItem) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let idx = textItems.firstIndex(where: { $0.id == item.id }) else { return }

                let base = pinchBaseSize ?? textItems[idx].fontSize
                if pinchBaseSize == nil { pinchBaseSize = base }

                textItems[idx].fontSize = min(max(base * value.magnification, 12), 140)
            }
            .onEnded { _ in
                pinchBaseSize = nil
            }
    }

    private func emojiMagnifyGesture(for item: DoodleEmojiItem) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let idx = emojiItems.firstIndex(where: { $0.id == item.id }) else { return }

                let base = pinchBaseSize ?? emojiItems[idx].fontSize
                if pinchBaseSize == nil { pinchBaseSize = base }

                emojiItems[idx].fontSize = min(max(base * value.magnification, 16), 180)
            }
            .onEnded { _ in
                pinchBaseSize = nil
            }
    }

    // MARK: - Colour bar

    /// The stops the bar is drawn from. Picking samples this same array, so
    /// the colour you get is exactly the one under your finger.
    private var barStops: [UIColor] {
        var stops: [UIColor] = [.white]
        for i in 0...11 {
            stops.append(UIColor(hue: CGFloat(i) / 12.0, saturation: 1, brightness: 1, alpha: 1))
        }
        stops.append(.black)
        return stops
    }

    private func barColor(at fraction: CGFloat) -> UIColor {
        let stops = barStops
        let last = stops.count - 1
        let pos = min(max(fraction, 0), 1) * CGFloat(last)
        let i = min(Int(pos), last - 1)
        let t = pos - CGFloat(i)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        stops[i].getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        stops[i + 1].getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red:   r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue:  b1 + (b2 - b1) * t,
            alpha: 1
        )
    }

    /// A thin spectrum strip down the edge of the canvas. Hold it and slide,
    /// and a teardrop shows the colour you're on — the same gesture as
    /// Snapchat's, so it needs no explaining.
    ///
    /// Once you start drawing it shrinks to a bead the size of the background
    /// button, so it stops covering the canvas. It's the same `Capsule`
    /// throughout — a capsule at equal width and height is a circle — so the
    /// two states genuinely morph into each other rather than cross-fading.
    private var verticalColorBar: some View {

        GeometryReader { geo in

            let openHeight = geo.size.height

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LinearGradient(
                    colors: barStops.map(Color.init),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(
                    width: isColorBarOpen ? 14 : 32,
                    height: isColorBarOpen ? openHeight : 32
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.92), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 3, x: -1)
                // Widened well beyond the visible strip: 14pt is a hard
                // target for a thumb, and missing it would draw on the canvas.
                .contentShape(Capsule().inset(by: -16))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard isColorBarOpen else { return }
                            pickColor(atY: value.location.y, in: openHeight)
                            isPickingColor = true
                        }
                        .onEnded { _ in
                            if isColorBarOpen {
                                isPickingColor = false
                            } else {
                                withAnimation(bubble) { isColorBarOpen = true }
                            }
                        }
                )
                .overlay(alignment: .top) {
                    if isPickingColor && isColorBarOpen {
                        ColorPin()
                            .fill(selectedColor)
                            .overlay(ColorPin().stroke(.white, lineWidth: 3))
                            .frame(width: 78, height: 60)
                            .shadow(color: .black.opacity(0.28), radius: 5)
                            // Tail points back at the strip, centred on the touch.
                            .offset(x: -88, y: colorBarFraction * openHeight - 30)
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(bubble, value: isColorBarOpen)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPickingColor)
        }
        .frame(width: 32)
    }

    /// Loose enough to overshoot slightly, so the bar visibly pops between
    /// its two shapes instead of just resizing.
    private var bubble: Animation {
        .spring(response: 0.38, dampingFraction: 0.58)
    }

    private func pickColor(atY y: CGFloat, in height: CGFloat) {

        guard height > 0 else { return }

        let fraction = min(max(y / height, 0), 1)
        colorBarFraction = fraction
        selectedHex = barColor(at: fraction).hexString
        isEraser = false

        // Matches the old swatches: picking a colour also recolours the text
        // you have selected, and the pen always follows so you can never get
        // stuck unable to change ink colour.
        recolorSelectedText(to: selectedHex)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 12) {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        addTextItem()
                    } label: {
                        toolChipLabel(icon: "character.cursor.ibeam", label: "Text")
                    }
                    .buttonStyle(.plain)

                    ForEach(inkTypes, id: \.label) { item in
                        Button {
                            inkType = item.type
                            isEraser = false
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 15, weight: .bold))
                                Text(item.label)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(
                                inkType == item.type && !isEraser ? .white : accent
                            )
                            .frame(width: 68)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        inkType == item.type && !isEraser
                                            ? accent
                                            : Color.white.opacity(0.85)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 14) {
                Image(systemName: "pencil.tip").foregroundStyle(.secondary)

                Slider(value: $brushWidth, in: 4...160)

                Circle()
                    .fill(isEraser ? Color.secondary : selectedColor)
                    .frame(
                        width: min(brushWidth, 30),
                        height: min(brushWidth, 30)
                    )
                    .frame(width: 30, height: 30)

                toolButton(system: "eraser.fill", active: isEraser) {
                    isEraser.toggle()
                }
                toolButton(system: "arrow.uturn.backward", active: false) {
                    canvasView.undoManager?.undo()
                }
                toolButton(system: "trash", active: false, tint: .red) {
                    canvasView.drawing = PKDrawing()
                    textItems.removeAll()
                    emojiItems.removeAll()
                    selectedItemID = nil
                    editingTextID = nil
                    editingEmojiID = nil
                    canvasTextFocused = false
                    canvasBGHex = "#FFFFFF"
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func toolButton(
        system: String,
        active: Bool,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .foregroundColor(active ? .white : (tint ?? accent))
                .frame(width: 38, height: 38)
                .background(active ? accent : Color.white.opacity(0.85))
                .clipShape(Circle())
        }
    }

    private func toolChipLabel(icon: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(accent)
        .frame(width: 68)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
        )
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack {
                if isSending { ProgressView().tint(.white) }
                Text(isSending ? "Sending…" : "Send to their widget 🎨")
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .disabled(isSending)
    }

    private var toast: some View {
        Text("Sent 🎉")
            .font(.headline).fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(.black.opacity(0.75))
            .clipShape(Capsule())
    }

    // Asked right after tapping Send — short on purpose, not a sentence.
    private var pinPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { confirmSend(pinned: false) }

            VStack(spacing: 16) {
                Text("Pin to widget?")
                    .font(.headline).fontWeight(.black)
                    .foregroundColor(accent)

                HStack(spacing: 12) {
                    Button {
                        confirmSend(pinned: false)
                    } label: {
                        Text("Let it update")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                    }

                    Button {
                        confirmSend(pinned: true)
                    } label: {
                        Text("Pin it 📌")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    // MARK: - Logic

    private func configureTool() {
        if isEraser {
            // The width matters here too — without it the eraser ignores the
            // size slider and stays one fixed size, even though the slider
            // and its preview dot are right there suggesting otherwise.
            canvasView.tool = PKEraserTool(.bitmap, width: brushWidth)
        } else {
            canvasView.tool = PKInkingTool(
                inkType,
                color: UIColor(hex: selectedHex),
                width: brushWidth
            )
        }
    }

    private func listenForPartner() {
        FirestoreManager.shared.listenForDoodle { data in
            // Compare device IDs, not display names — two partners with the
            // same name would otherwise make every doodle look like "my own."
            guard
                let base64 = data?["imageBase64"] as? String,
                let sender = data?["sender"] as? String,
                let senderDeviceID = data?["senderDeviceID"] as? String,
                senderDeviceID != FirestoreManager.shared.currentDeviceID,
                let raw = Data(base64Encoded: base64),
                let image = UIImage(data: raw)
            else { return }

            // Push the doodle onto our widget too. This covers the app-open
            // case; the Cloud Function push covers the app-closed case.
            let pinned = data?["pinned"] as? Bool ?? false
            WidgetDataManager.shared.cachePartnerDoodle(base64: base64, sender: sender, pinned: pinned)

            DispatchQueue.main.async {
                partnerDoodle = image
                partnerDoodleSender = sender
            }
        }
    }

    private func send() {
        // Commit any in-progress typing first, so a blank text or emoji
        // item can't make an otherwise-empty canvas look like it has
        // content — and so the last thing typed is definitely included.
        finishEditingText()
        finishEditingEmoji()
        selectedItemID = nil

        guard !canvasView.drawing.strokes.isEmpty || !textItems.isEmpty || !emojiItems.isEmpty else {
            return
        }
        showPinPrompt = true
    }

    private func confirmSend(pinned: Bool) {
        showPinPrompt = false
        isSending = true

        let exported = exportDrawing()
        let resized = downscale(exported, maxDimension: 700)
        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            isSending = false
            return
        }
        let base64 = data.base64EncodedString()

        FirestoreManager.shared.sendDoodle(
            imageBase64: base64,
            sender: username,
            pinned: pinned
        ) { error in
            DispatchQueue.main.async {
                isSending = false
                guard error == nil else { return }
                canvasView.drawing = PKDrawing()
                textItems.removeAll()
                emojiItems.removeAll()
                selectedItemID = nil
                editingTextID = nil
                editingEmojiID = nil
                withAnimation { showSentToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { showSentToast = false }
                }
            }
        }
    }

    private func exportDrawing() -> UIImage {
        let size = canvasView.bounds.size == .zero
            ? CGSize(width: 600, height: 600)
            : canvasView.bounds.size

        let drawingImage = canvasView.drawing.image(
            from: CGRect(origin: .zero, size: size),
            scale: UIScreen.main.scale
        )

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Whatever the canvas is showing, so the sent image and the
            // widget match what you drew on.
            UIColor(hex: canvasBGHex).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            drawingImage.draw(in: CGRect(origin: .zero, size: size))

            // Stickers are stored as normalized (0...1) positions, so they
            // scale correctly onto the export size regardless of how big
            // the on-screen canvas actually was.
            for item in textItems {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: item.fontSize),
                    .foregroundColor: UIColor(item.color)
                ]
                let string = item.text as NSString
                let stringSize = string.size(withAttributes: attrs)
                string.draw(
                    at: CGPoint(
                        x: item.position.x * size.width - stringSize.width / 2,
                        y: item.position.y * size.height - stringSize.height / 2
                    ),
                    withAttributes: attrs
                )
            }

            for item in emojiItems {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: item.fontSize)
                ]
                let string = item.emoji as NSString
                let stringSize = string.size(withAttributes: attrs)
                string.draw(
                    at: CGPoint(
                        x: item.position.x * size.width - stringSize.width / 2,
                        y: item.position.y * size.height - stringSize.height / 2
                    ),
                    withAttributes: attrs
                )
            }
        }
    }

    private func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - PencilKit canvas wrapper

struct DoodleCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView
    var background: UIColor = .white

    /// Fires the moment a stroke starts, so the colour bar can get out of
    /// the way.
    var onDrawingBegan: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingBegan: onDrawingBegan)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingBegan: () -> Void
        init(onDrawingBegan: @escaping () -> Void) {
            self.onDrawingBegan = onDrawingBegan
        }
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            onDrawingBegan()
        }
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = background
        canvasView.isOpaque = true
        canvasView.delegate = context.coordinator
        // The canvas is a fixed square that never scrolls or zooms, but as a
        // scroll view it still owns a pinch recogniser that would otherwise
        // compete with pinching a sticker to resize it. Drawing is handled
        // by PencilKit's own recognisers, so this doesn't affect it.
        canvasView.isScrollEnabled = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.backgroundColor = background
        // Refreshed each pass so the closure never captures stale state.
        context.coordinator.onDrawingBegan = onDrawingBegan
    }
}

private extension UIColor {
    /// `#RRGGBB`. The doodle stores colours as hex strings, so a colour picked
    /// off the spectrum bar has to come back out in the same form.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(round(max(0, min(1, r)) * 255)),
            Int(round(max(0, min(1, g)) * 255)),
            Int(round(max(0, min(1, b)) * 255))
        )
    }

    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

#Preview {
    DoodleView()
}
