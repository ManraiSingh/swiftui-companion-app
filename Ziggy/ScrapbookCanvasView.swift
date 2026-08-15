//
//  ScrapbookCanvasView.swift
//  Ziggy
//
//  The editor. Photos, brush, text and stickers on a page both partners can
//  work on at the same time.
//
//  Transforms are committed to Firestore when a gesture ends rather than
//  while it runs — a drag fires sixty times a second and each one would be a
//  write.
//

import SwiftUI
import PhotosUI

struct ScrapbookCanvasView: View {

    let book: ScrapbookBook
    let page: ScrapbookPage

    @StateObject private var manager = ScrapbookManager.shared
    @Environment(\.dismiss) private var dismiss

    enum Tool: String, CaseIterable, Identifiable {
        case select, brush, eraser
        var id: String { rawValue }
    }

    @State private var tool: Tool = .select
    @State private var selectedID: String?

    // Brush
    @State private var brushColor = "#2E2A27"
    @State private var brushWidth: Double = 6
    @State private var livePoints: [CGPoint] = []

    // Live gesture state, so dragging feels immediate without a round trip.
    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: Double = 1
    @State private var spinAngle: Double = 0

    // Sheets
    @State private var photoItem: PhotosPickerItem?
    @State private var showingStickers = false
    @State private var showingPaper = false
    @State private var showingCamera = false
    @State private var textFontIndex = 0
    @State private var textColor = "#2E2A27"

    /// The text element being typed into, straight on the page.
    @State private var typingID: String?
    @State private var typedText = ""
    @FocusState private var typingFocused: Bool

    @State private var paperIndex: Int
    @State private var photoPickerOpen = false

    /// Set while the picker is open to swap one element's picture rather than
    /// place a new one.
    @State private var replacingID: String?

    init(book: ScrapbookBook, page: ScrapbookPage) {
        self.book = book
        self.page = page
        _paperIndex = State(initialValue: page.paperIndex)
    }

    private var selected: ScrapbookElement? {
        manager.elements.first { $0.id == selectedID }
    }

    var body: some View {

        VStack(spacing: 0) {

            topBar

            GeometryReader { proxy in
                canvas(size: proxy.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Trimmed right back — the page is the point of this screen, so
            // it gets everything the toolbars don't need.
            .padding(.horizontal, 4)
            .padding(.vertical, 2)

            if let element = selected, tool == .select {
                SelectedElementBar(
                    element: element,
                    onFrame: { cycleFrame(element) },
                    onReplace: { replacePhoto(element) },
                    onLock: { toggleLock(element) },
                    onForward: { bringForward(element) },
                    onDuplicate: { duplicate(element) },
                    onDelete: { deleteSelected(element) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if typingID != nil {
                TypingBar(
                    fontIndex: $textFontIndex,
                    colorHex: $textColor,
                    onDone: { finishTyping() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if tool == .brush || tool == .eraser {
                BrushBar(color: $brushColor, width: $brushWidth, isEraser: tool == .eraser)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            toolbar
        }
        .background(Color(red: 0.13, green: 0.12, blue: 0.17).ignoresSafeArea())
        .onAppear { manager.startElements(bookID: book.id, pageID: page.id) }
        .photosPicker(isPresented: $photoPickerOpen, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in Task { await addPhoto(item) } }
        .sheet(isPresented: $showingStickers) {
            StickerPicker { emoji in addSticker(emoji) }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingPaper) {
            CanvasPaperPicker(selected: paperIndex) { index in
                paperIndex = index
                manager.setPaper(bookID: book.id, pageID: page.id, paperIndex: index)
            }
            .presentationDetents([.height(300)])
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ScrapbookCameraPicker { image in addPhoto(image) }
                .ignoresSafeArea()
        }
    }

    // MARK: Top bar

    private var topBar: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.22))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
            }

            Spacer()

            Text(book.title)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            Button { showingPaper = true } label: {
                Image(systemName: "doc.plaintext")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: Canvas

    private func canvas(size: CGSize) -> some View {

        // The page keeps a fixed proportion so both phones lay it out the
        // same way; normalised coordinates depend on it.
        let width = min(size.width, size.height * 0.74)
        let height = width / 0.74
        let canvasSize = CGSize(width: width, height: height)

        return ZStack {

            ScrapbookPaper(paperIndex: paperIndex)

            ForEach(manager.elements) { element in
                ScrapbookElementView(
                    element: live(element),
                    canvasSize: canvasSize,
                    isSelected: element.id == selectedID && tool == .select
                )
                // The one being typed into is drawn by the field instead, so
                // the words don't appear twice.
                .opacity(element.id == typingID ? 0 : 1)
                .allowsHitTesting(tool == .select)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedID = element.id
                    }
                }
                .gesture(transformGesture(for: element, canvasSize: canvasSize))
            }

            // The caret, sitting where the finished text will sit.
            if let id = typingID,
               let element = manager.elements.first(where: { $0.id == id }) {

                TextField("Type…", text: $typedText, axis: .vertical)
                    .font(ScrapbookStyle.font(textFontIndex, size: element.widthValue * 3))
                    .foregroundStyle(Color(scrapbookHex: textColor))
                    .multilineTextAlignment(.center)
                    .lineLimit(1...4)
                    .focused($typingFocused)
                    .submitLabel(.done)
                    .onSubmit { finishTyping() }
                    .frame(width: canvasSize.width * 0.82)
                    .position(
                        x: element.x * canvasSize.width,
                        y: element.y * canvasSize.height
                    )
            }

            // The stroke in progress.
            if !livePoints.isEmpty {
                ScrapbookStroke.path(for: livePoints, in: canvasSize)
                    .stroke(
                        Color(scrapbookHex: brushColor),
                        style: StrokeStyle(lineWidth: brushWidth, lineCap: .round, lineJoin: .round)
                    )
            }

            if manager.elements.isEmpty && livePoints.isEmpty {
                emptyHint
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        .contentShape(Rectangle())
        .gesture(canvasGesture(canvasSize: canvasSize))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 24, weight: .light))
            Text("Add a photo, draw, or write something")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(ScrapbookStyle.defaultInk(onPaper: paperIndex).opacity(0.35))
        .padding(.horizontal, 40)
        .allowsHitTesting(false)
    }

    /// The element with any in-flight gesture applied on top.
    private func live(_ element: ScrapbookElement) -> ScrapbookElement {

        guard element.id == selectedID, tool == .select, !element.locked else { return element }

        var copy = element
        copy.x += Double(dragOffset.width)
        copy.y += Double(dragOffset.height)
        copy.scale = max(0.2, element.scale * pinchScale)
        copy.rotation = element.rotation + spinAngle
        return copy
    }

    // MARK: Gestures

    private func transformGesture(for element: ScrapbookElement, canvasSize: CGSize) -> some Gesture {

        // Whichever element the fingers land on becomes the live one. Before
        // this, a pinch or a turn did nothing until you had tapped the element
        // first, which made two-finger rotating look like it wasn't working.
        func engage() -> Bool {
            guard tool == .select, !element.locked else { return false }
            if selectedID != element.id { selectedID = element.id }
            return true
        }

        let drag = DragGesture()
            .onChanged { value in
                guard engage() else { return }
                dragOffset = CGSize(
                    width: value.translation.width / canvasSize.width,
                    height: value.translation.height / canvasSize.height
                )
            }

        let pinch = MagnifyGesture()
            .onChanged { value in
                guard engage() else { return }
                pinchScale = value.magnification
            }

        let spin = RotateGesture()
            .onChanged { value in
                guard engage() else { return }
                spinAngle = value.rotation.degrees
            }

        // Pinch and turn are paired first so two fingers can do both at once,
        // with the drag riding alongside.
        //
        // The three only report movement. Committing is done once, here, when
        // the whole gesture ends.
        //
        // Each used to write on its own end, and each wrote the full set of
        // fields off the element as it was before the gesture. So lifting after
        // a turn fired the drag's commit too, which wrote back the original
        // angle — the turn was applied and then immediately undone. Position
        // and scale were being clobbered the same way; a turn just made it
        // visible.
        return drag.simultaneously(with: pinch.simultaneously(with: spin))
            .onEnded { _ in

                defer {
                    dragOffset = .zero
                    pinchScale = 1
                    spinAngle = 0
                }

                guard tool == .select, selectedID == element.id, !element.locked else { return }

                var settled = element
                settled.x = min(max(element.x + Double(dragOffset.width), 0.02), 0.98)
                settled.y = min(max(element.y + Double(dragOffset.height), 0.02), 0.98)
                settled.scale = min(max(element.scale * pinchScale, 0.2), 4)
                settled.rotation = element.rotation + spinAngle

                manager.move(settled, bookID: book.id, pageID: page.id)
            }
    }

    /// Drawing, erasing, and tapping empty paper to deselect.
    private func canvasGesture(canvasSize: CGSize) -> some Gesture {

        DragGesture(minimumDistance: 0)
            .onChanged { value in

                let point = CGPoint(
                    x: value.location.x / canvasSize.width,
                    y: value.location.y / canvasSize.height
                )

                if tool == .eraser {
                    erase(at: point, canvasSize: canvasSize)
                    return
                }

                guard tool == .brush else { return }

                // Sampling every point makes for enormous payloads; a stroke
                // reads the same with a small minimum step between samples.
                if let last = livePoints.last {
                    let dx = last.x - point.x
                    let dy = last.y - point.y
                    guard (dx * dx + dy * dy) > 0.00004 else { return }
                }

                livePoints.append(point)
            }
            .onEnded { _ in

                if tool == .select {
                    withAnimation { selectedID = nil }
                    return
                }

                guard tool == .brush, livePoints.count > 1 else {
                    livePoints = []
                    return
                }

                var element = ScrapbookElement(id: UUID().uuidString, kind: .stroke)
                element.payload = ScrapbookStroke.encode(livePoints)
                element.colorHex = brushColor
                element.widthValue = brushWidth
                element.z = manager.nextZ
                element.x = 0.5
                element.y = 0.5

                manager.add(element, bookID: book.id, pageID: page.id)
                livePoints = []
            }
    }

    /// Rubs out the drawing under the finger, and only the drawing.
    ///
    /// It used to paint a paper-coloured stroke instead, which covered photos
    /// and text as readily as pencil and left a smear of paint behind that
    /// couldn't itself be removed. Working on the strokes themselves means it
    /// can't touch anything that isn't drawn.
    private func erase(at point: CGPoint, canvasSize: CGSize) {

        // The eraser's reach, in the page's normalised units.
        let reach = (brushWidth / 2 + 6) / canvasSize.width

        for element in manager.elements where element.kind == .stroke && !element.locked {

            let points = ScrapbookStroke.decode(element.payload)

            // Compared in page proportions rather than raw numbers — the page
            // is taller than it is wide, so a plain distance would make the
            // eraser reach further vertically than it looks.
            let aspect = canvasSize.height / canvasSize.width

            let touched = points.contains { sample in
                let dx = sample.x - point.x
                let dy = (sample.y - point.y) * aspect
                return (dx * dx + dy * dy) <= reach * reach
            }

            if touched {
                manager.delete(element.id, bookID: book.id, pageID: page.id)
            }
        }
    }

    // MARK: Adding

    private func addPhoto(_ item: PhotosPickerItem?) async {

        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        addPhoto(image)
        photoItem = nil
    }

    private func addPhoto(_ image: UIImage) {

        guard let base64 = image.scrapbookBase64() else { return }

        // Replacing rather than adding: keep everything about the element
        // except the picture itself.
        if let id = replacingID, var existing = manager.elements.first(where: { $0.id == id }) {
            existing.payload = base64
            existing.aspect = Double(image.size.width / max(image.size.height, 1))
            manager.update(existing, bookID: book.id, pageID: page.id)
            ScrapbookImageCache.shared.forget(id)
            replacingID = nil
            showingCamera = false
            return
        }

        var element = ScrapbookElement(id: UUID().uuidString, kind: .photo)
        element.payload = base64
        element.aspect = Double(image.size.width / max(image.size.height, 1))
        element.frameIndex = ScrapbookStyle.Frame.polaroid.rawValue
        element.z = manager.nextZ

        // A little tilt out of the box — a photo laid down perfectly square
        // looks like a form field, not a scrapbook.
        element.rotation = Double.random(in: -5...5)
        element.x = Double.random(in: 0.38...0.62)
        element.y = Double.random(in: 0.34...0.62)

        manager.add(element, bookID: book.id, pageID: page.id)
        selectedID = element.id
        showingCamera = false
    }

    private func addSticker(_ emoji: String) {

        var element = ScrapbookElement(id: UUID().uuidString, kind: .sticker)
        element.payload = emoji
        element.widthValue = 7
        element.z = manager.nextZ
        element.rotation = Double.random(in: -12...12)
        element.x = Double.random(in: 0.35...0.65)
        element.y = Double.random(in: 0.35...0.65)

        manager.add(element, bookID: book.id, pageID: page.id)
        selectedID = element.id
    }

    /// Starts a new piece of text on the page and puts the caret in it.
    ///
    /// Typing happens on the page itself rather than in a sheet — you see the
    /// words in place, in the font and colour they'll keep, instead of writing
    /// them somewhere else and finding out afterwards.
    private func startTyping() {

        if typingID != nil { finishTyping(); return }

        var element = ScrapbookElement(id: UUID().uuidString, kind: .text)
        element.payload = ""
        element.fontIndex = textFontIndex
        element.colorHex = textColor
        element.widthValue = 7
        element.z = manager.nextZ
        element.x = 0.5
        element.y = 0.42

        manager.add(element, bookID: book.id, pageID: page.id)

        typedText = ""
        typingID = element.id
        selectedID = nil
        tool = .select
        typingFocused = true
    }

    /// Puts the typed words on the page. Text nobody typed is thrown away
    /// rather than left as an invisible element to trip over later.
    private func finishTyping() {

        guard let id = typingID,
              var element = manager.elements.first(where: { $0.id == id }) else {
            typingID = nil
            return
        }

        let clean = typedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            manager.delete(id, bookID: book.id, pageID: page.id)
        } else {
            element.payload = clean
            element.fontIndex = textFontIndex
            element.colorHex = textColor
            manager.update(element, bookID: book.id, pageID: page.id)
        }

        typingID = nil
        typedText = ""
        typingFocused = false
    }

    // MARK: Selected element actions

    /// Swaps the picture inside an element, keeping its place, frame, size
    /// and angle — so replacing a photo doesn't undo the arranging.
    private func replacePhoto(_ element: ScrapbookElement) {
        guard element.kind == .photo else { return }
        replacingID = element.id
        photoPickerOpen = true
    }

    private func toggleLock(_ element: ScrapbookElement) {
        var updated = element
        updated.locked.toggle()
        manager.update(updated, bookID: book.id, pageID: page.id)
    }

    private func cycleFrame(_ element: ScrapbookElement) {
        guard element.kind == .photo else { return }
        var updated = element
        updated.frameIndex = (element.frameIndex + 1) % ScrapbookStyle.Frame.allCases.count
        manager.update(updated, bookID: book.id, pageID: page.id)
    }

    private func bringForward(_ element: ScrapbookElement) {
        var updated = element
        updated.z = manager.nextZ
        manager.move(updated, bookID: book.id, pageID: page.id)
    }

    private func duplicate(_ element: ScrapbookElement) {
        var copy = element
        copy.id = UUID().uuidString
        copy.x = min(element.x + 0.06, 0.95)
        copy.y = min(element.y + 0.06, 0.95)
        copy.z = manager.nextZ
        manager.add(copy, bookID: book.id, pageID: page.id)
        selectedID = copy.id
    }

    private func deleteSelected(_ element: ScrapbookElement) {
        manager.delete(element.id, bookID: book.id, pageID: page.id)
        selectedID = nil
    }

    // MARK: Toolbar

    private var toolbar: some View {

        HStack(spacing: 6) {

            toolButton("photo.on.rectangle", "Photo") {
                photoPickerOpen = true
            }

            toolButton("camera.fill", "Camera") {
                showingCamera = true
            }

            toolButton("scribble.variable", "Draw", active: tool == .brush) {
                withAnimation { tool = tool == .brush ? .select : .brush; selectedID = nil }
            }

            toolButton("textformat", "Text", active: typingID != nil) {
                startTyping()
            }

            toolButton("face.smiling", "Stickers") {
                showingStickers = true
            }

            toolButton("eraser.fill", "Erase", active: tool == .eraser) {
                withAnimation { tool = tool == .eraser ? .select : .eraser; selectedID = nil }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Color(red: 0.10, green: 0.09, blue: 0.13))
    }

    private func toolButton(
        _ icon: String,
        _ label: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? Color(red: 0.16, green: 0.14, blue: 0.22) : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? Color.white : Color.white.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selected element bar

private struct SelectedElementBar: View {

    let element: ScrapbookElement
    let onFrame: () -> Void
    let onReplace: () -> Void
    let onLock: () -> Void
    let onForward: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {

        HStack(spacing: 8) {

            if element.kind == .photo {
                action("Frame", "square.on.square", onFrame)
                action("Replace", "arrow.triangle.2.circlepath", onReplace)
            }

            action(
                element.locked ? "Locked" : "Unlocked",
                element.locked ? "lock.fill" : "lock.open",
                onLock,
                tint: element.locked
                    ? Color(red: 1.0, green: 0.82, blue: 0.42)
                    : .white
            )

            action("Front", "square.3.layers.3d.top.filled", onForward)
            action("Copy", "plus.square.on.square", onDuplicate)
            action("Delete", "trash", onDelete,
                   tint: Color(red: 1.0, green: 0.45, blue: 0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func action(
        _ label: String,
        _ icon: String,
        _ perform: @escaping () -> Void,
        tint: Color = .white
    ) -> some View {

        Button(action: perform) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(label).font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Brush bar

private struct BrushBar: View {

    @Binding var color: String
    @Binding var width: Double
    let isEraser: Bool

    var body: some View {

        VStack(spacing: 8) {

            if !isEraser {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ScrapbookStyle.inkPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(scrapbookHex: hex))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().strokeBorder(.white,
                                                          lineWidth: color == hex ? 3 : 1)
                                )
                                .onTapGesture { color = hex }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                Slider(value: $width, in: 2...40)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Circle()
                    .fill(isEraser ? Color.white : Color(scrapbookHex: color))
                    .frame(width: max(width / 2, 6), height: max(width / 2, 6))
                    .frame(width: 22, height: 22)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Sticker picker

private struct StickerPicker: View {

    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                Text("Stickers")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                ForEach(ScrapbookStyle.stickerGroups, id: \.0) { group in

                    VStack(alignment: .leading, spacing: 10) {

                        Text(group.0)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(group.1, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.secondary.opacity(0.10))
                                    )
                                    .onTapGesture {
                                        onPick(emoji)
                                        dismiss()
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Text composer

// MARK: - Typing bar

/// Font and colour, while the words are being typed on the page.
private struct TypingBar: View {

    @Binding var fontIndex: Int
    @Binding var colorHex: String
    let onDone: () -> Void

    var body: some View {

        VStack(spacing: 8) {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(ScrapbookStyle.fonts.enumerated()), id: \.offset) { index, choice in
                        Text(choice.label)
                            .font(ScrapbookStyle.font(index, size: 14))
                            .foregroundStyle(fontIndex == index
                                             ? Color(red: 0.16, green: 0.14, blue: 0.22)
                                             : .white)
                            .lineLimit(1)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(fontIndex == index
                                               ? Color.white
                                               : Color.white.opacity(0.12))
                            )
                            .onTapGesture { fontIndex = index }
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ScrapbookStyle.inkPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(scrapbookHex: hex))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().strokeBorder(.white,
                                                          lineWidth: colorHex == hex ? 3 : 1)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.leading, 16)
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.22))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Paper picker

private struct CanvasPaperPicker: View {

    let selected: Int
    let onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 14)]

    var body: some View {

        VStack(spacing: 18) {

            Text("Paper")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .padding(.top, 20)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(ScrapbookStyle.papers.enumerated()), id: \.offset) { index, paper in
                    VStack(spacing: 6) {
                        ScrapbookPaper(paperIndex: index)
                            .frame(width: 62, height: 78)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.primary.opacity(0.85),
                                                  lineWidth: selected == index ? 3 : 0.5)
                            )
                        Text(paper.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .onTapGesture {
                        onPick(index)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Camera

struct ScrapbookCameraPicker: UIViewControllerRepresentable {

    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject,
                             UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {

        let onCapture: (UIImage) -> Void
        let dismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Compression

private extension UIImage {

    /// Scrapbook photos are kept rather than glanced at, so they get more
    /// budget than an instant does — but still well inside Firestore's 1 MB
    /// document ceiling once base64 has added its third.
    func scrapbookBase64(maxBytes: Int = 420_000) -> String? {

        for maxSide in [1200, 1000, 820, 640] as [CGFloat] {

            let resized = scaled(maxSide: maxSide)
            var quality: CGFloat = 0.72

            while quality >= 0.3 {
                if let data = resized.jpegData(compressionQuality: quality),
                   data.count <= maxBytes {
                    return data.base64EncodedString()
                }
                quality -= 0.1
            }
        }

        return scaled(maxSide: 560)
            .jpegData(compressionQuality: 0.3)?
            .base64EncodedString()
    }

    func scaled(maxSide: CGFloat) -> UIImage {

        let factor = min(maxSide / size.width, maxSide / size.height, 1)
        guard factor < 1 else { return self }

        let target = CGSize(width: size.width * factor, height: size.height * factor)

        // Scale 1 — the default is the screen's, which would silently triple
        // every dimension and blow the byte budget we just measured.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
