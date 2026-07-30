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
    @State private var brushWidth: CGFloat = 22
    @State private var isEraser = false
    @State private var inkType: PKInkingTool.InkType = .pen
    @State private var isSending = false
    @State private var showSentToast = false
    @State private var showPinPrompt = false
    @State private var showPartnerDoodlePopup = false

    @State private var textItems: [DoodleTextItem] = []
    @State private var emojiItems: [DoodleEmojiItem] = []
    @State private var showTextInput = false
    @State private var pendingText = ""
    @State private var showEmojiPicker = false

    @State private var partnerDoodle: UIImage?
    @State private var partnerDoodleSender = ""

    private let emojiChoices = [
        "😍", "😂", "🥰", "😘", "🤩", "😎",
        "🥳", "😴", "🤔", "😢", "😡", "🥺",
        "👍", "👎", "👏", "🙌", "🤗", "💕",
        "❤️", "💖", "💗", "💛", "💜", "🧡",
        "🔥", "✨", "🌟", "🎉", "🎈", "🍕",
        "🍔", "🍩", "☕️", "🌈", "🐶", "🐱",
        "🦄", "🌸", "🌻", "⭐️"
    ]

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
        .alert("Add Text", isPresented: $showTextInput) {
            TextField("Type something…", text: $pendingText)
            Button("Add") {
                let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                textItems.append(
                    DoodleTextItem(
                        text: trimmed,
                        position: CGPoint(x: 0.5, y: 0.5),
                        color: selectedColor
                    )
                )
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEmojiPicker) {
            emojiPickerSheet
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
                DoodleCanvas(canvasView: canvasView)
                    .background(.white)

                ForEach(textItems) { item in
                    textItemView(item)
                        .position(
                            x: item.position.x * geo.size.width,
                            y: item.position.y * geo.size.height
                        )
                        .gesture(textDragGesture(for: item, in: geo.size))
                }

                ForEach(emojiItems) { item in
                    emojiItemView(item)
                        .position(
                            x: item.position.x * geo.size.width,
                            y: item.position.y * geo.size.height
                        )
                        .gesture(emojiDragGesture(for: item, in: geo.size))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }

    // MARK: - Text & emoji stickers

    private func textItemView(_ item: DoodleTextItem) -> some View {
        Text(item.text)
            .font(.system(size: item.fontSize, weight: .bold))
            .foregroundColor(item.color)
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                stickerDeleteBadge {
                    textItems.removeAll { $0.id == item.id }
                }
            }
    }

    private func emojiItemView(_ item: DoodleEmojiItem) -> some View {
        Text(item.emoji)
            .font(.system(size: item.fontSize))
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                stickerDeleteBadge {
                    emojiItems.removeAll { $0.id == item.id }
                }
            }
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

    private var emojiPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 6),
                    spacing: 16
                ) {
                    ForEach(emojiChoices, id: \.self) { emoji in
                        Button {
                            emojiItems.append(
                                DoodleEmojiItem(emoji: emoji, position: CGPoint(x: 0.5, y: 0.5))
                            )
                            showEmojiPicker = false
                        } label: {
                            Text(emoji).font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Pick an emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showEmojiPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(palette, id: \.hex) { item in
                        Button {
                            selectedHex = item.hex
                            isEraser = false
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    if selectedHex == item.hex && !isEraser {
                                        Circle().stroke(.white, lineWidth: 3)
                                    }
                                }
                                .shadow(radius: selectedHex == item.hex ? 3 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        pendingText = ""
                        showTextInput = true
                    } label: {
                        toolChipLabel(icon: "character.cursor.ibeam", label: "Text")
                    }
                    .buttonStyle(.plain)

                    Button {
                        showEmojiPicker = true
                    } label: {
                        toolChipLabel(icon: "face.smiling", label: "Emoji")
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
            canvasView.tool = PKEraserTool(.bitmap)
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
            UIColor.white.setFill()
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

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

private extension UIColor {
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
