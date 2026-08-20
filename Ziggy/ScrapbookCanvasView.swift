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
    @State private var brushIndex = 0
    @State private var livePoints: [CGPoint] = []

    // Live gesture state, so dragging feels immediate without a round trip.
    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: Double = 1
    @State private var spinAngle: Double = 0

    // Sheets
    @State private var photoItem: PhotosPickerItem?
    @State private var showingStickers = false
    @State private var showingPaper = false
    @State private var showingFrames = false
    @State private var showingCamera = false
    @State private var textFontIndex = 0
    @State private var textColor = "#2E2A27"

    /// The text element being typed into, straight on the page.
    @State private var typingID: String?
    @State private var typedText = ""
    @State private var textSize: Double = 7
    @FocusState private var typingFocused: Bool

    /// The selected element's size, held here so the slider and a pinch drive
    /// the same number and the page can show the change as it happens.
    @State private var draftScale: Double = 1

    @State private var paperIndex: Int
    @State private var photoPickerOpen = false

    /// Set while the picker is open to swap one element's picture rather than
    /// place a new one.
    @State private var replacingID: String?

    /// The element a delete has been asked about but not yet confirmed.
    @State private var pendingDelete: ScrapbookElement?

    /// Set while the picker is open to put the chosen picture inside a sticker
    /// — the stamp, the frame, the bubble, the film — rather than on the page.
    @State private var fillingID: String?

    init(book: ScrapbookBook, page: ScrapbookPage) {
        self.book = book
        self.page = page
        _paperIndex = State(initialValue: page.paperIndex)
    }

    private var selected: ScrapbookElement? {
        manager.elements.first { $0.id == selectedID }
    }

    /// The piece of paper being written on, if the words being typed belong to
    /// a sticker rather than to the page.
    private var typingDecoration: ScrapbookDecoration? {
        guard let id = typingID,
              let element = manager.elements.first(where: { $0.id == id }),
              element.kind == .sticker else { return nil }
        return ScrapbookDecoration.from(payload: element.payload)
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

            bars

            toolbar
        }
        .background(Color(red: 0.13, green: 0.12, blue: 0.17).ignoresSafeArea())
        .onAppear { manager.startElements(bookID: book.id, pageID: page.id) }
        .onChange(of: selectedID) { _, _ in
            draftScale = selected?.scale ?? 1
        }
        .photosPicker(isPresented: $photoPickerOpen, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in Task { await addPhoto(item) } }
        .sheet(isPresented: $showingStickers) {
            StickerPicker(
                onEmoji: { addSticker($0) },
                onDecoration: { addDecoration($0) },
                onLetter: { addLetter($0) },
                onPet: { addPet($0) }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingFrames) {
            if let element = selected {
                FramePicker(
                    element: element,
                    onFrame: { setFrame(element, to: $0) },
                    onColour: { setFrameColour(element, to: $0) }
                )
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingPaper) {
            CanvasPaperPicker(selected: paperIndex) { index in
                paperIndex = index
                manager.setPaper(bookID: book.id, pageID: page.id, paperIndex: index)
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ScrapbookCameraPicker { image in addPhoto(image) }
                .ignoresSafeArea()
        }
        .confirmationDialog(
            pendingDelete.map(describe) ?? "Delete this?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {

            Button("Delete", role: .destructive) {
                if let pendingDelete { remove(pendingDelete) }
            }

            Button("Keep it", role: .cancel) { pendingDelete = nil }

        } message: {
            Text("This can't be undone.")
        }
    }

    /// Whichever context bar belongs to what's happening.
    ///
    /// Pulled out of `body` because the three of them inline pushed the view
    /// past what the type checker will infer in reasonable time.
    @ViewBuilder
    private var bars: some View {

        if let element = selected, tool == .select {
            SelectedElementBar(
                element: element,
                scale: $draftScale,
                onScaleCommit: { commitScale(element) },
                onFrame: { showingFrames = true },
                onReplace: { replacePhoto(element) },
                onLabel: labelling(element),
                onInlay: filling(element),
                onTint: tinting(element),
                onInk: inking(element),
                onFont: fonting(element),
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
                size: $textSize,
                // A caption's size is a proportion of the paper it sits on, not
                // a point size, so the readout says so.
                onSticker: typingDecoration != nil,
                onDone: { finishTyping() }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        if tool == .brush || tool == .eraser {
            BrushBar(
                color: $brushColor,
                width: $brushWidth,
                brushIndex: $brushIndex,
                isEraser: tool == .eraser
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                // Whatever is being typed into is drawn by the field instead,
                // so the words don't appear twice. A sticker keeps its paper —
                // only its caption is held back.
                .opacity(element.id == typingID && element.kind == .text ? 0 : 1)
                .allowsHitTesting(tool == .select)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedID = element.id
                    }
                }
                .gesture(transformGesture(for: element, canvasSize: canvasSize))
            }

            // The caret, sitting where the finished words will sit.
            if let id = typingID,
               let element = manager.elements.first(where: { $0.id == id }) {
                typingField(for: element, canvasSize: canvasSize)
            }

            // The stroke in progress, drawn through the same brush the
            // finished one will use. It was a plain round line before, so
            // every pen looked identical until you lifted your finger.
            if !livePoints.isEmpty {
                ScrapbookStrokeView(
                    points: livePoints,
                    canvasSize: canvasSize,
                    colorHex: brushColor,
                    width: brushWidth,
                    brushIndex: brushIndex
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

    /// The field you actually type into, drawn where the words will end up.
    ///
    /// A caption is bound to the sticker's own box and set at the size the
    /// caption will be — it used to be typed at page-text size across most of
    /// the width of the paper, so a date being written ran well outside the
    /// strip of tape it belonged to and then jumped into place on Done.
    private func typingField(for element: ScrapbookElement, canvasSize: CGSize) -> some View {

        let unit = max(canvasSize.width, 1) / ScrapbookStyle.pageReferenceWidth
        let zoom = CGFloat(min(max(element.scale, 0.2), 4)) * unit
        let decoration = ScrapbookDecoration.from(payload: element.payload)

        // Sized through the element's own scale as well as the page's, so
        // picking an enlarged caption back up shows it at the size it already
        // is rather than at its resting size and then jumping on Done.
        let size: CGFloat = decoration.map { $0.captionSize(widthValue: textSize) * zoom }
            ?? CGFloat(textSize) * 3 * zoom

        let width: CGFloat = decoration.map { $0.size.width * zoom * 0.86 }
            ?? min(canvasSize.width * 0.80 * CGFloat(element.scale),
                   canvasSize.width * 0.94)

        return TextField("Type…", text: $typedText, axis: .vertical)
            .font(ScrapbookStyle.font(textFontIndex, size: size))
            .foregroundStyle(Color(scrapbookHex: textColor))
            .multilineTextAlignment(.center)
            .lineLimit(1...4)
            .focused($typingFocused)
            .submitLabel(.done)
            .onSubmit { finishTyping() }
            // Return finishes the words rather than starting another line.
            //
            // A field that grows downwards is what lets you see a long caption
            // wrap as it will sit on the page, but iOS gives such a field a
            // return key that only ever inserts a newline — `onSubmit` is
            // never called. Catching the newline here keeps the wrapping and
            // makes the key do what it says.
            .onChange(of: typedText) { _, value in
                guard value.contains("\n") else { return }
                typedText = value
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                finishTyping()
            }
            .frame(width: width)
            // Turned with the paper it is being written on, so the words lie
            // along a tilted strip rather than across it.
            .rotationEffect(.degrees(decoration == nil ? 0 : element.rotation))
            .position(
                x: element.x * canvasSize.width,
                y: element.y * canvasSize.height
            )
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

        if element.id == typingID, element.kind == .sticker {
            var hidden = element
            hidden.caption = ""
            return hidden
        }

        guard element.id == selectedID, tool == .select, !element.locked else { return element }

        var copy = element
        copy.x += Double(dragOffset.width)
        copy.y += Double(dragOffset.height)
        copy.scale = min(max(draftScale * pinchScale, 0.2), 4)
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

            if selectedID != element.id {
                selectedID = element.id
                // Taken now rather than left to `onChange`, which lands a
                // frame later: the pinch would spend that frame scaling from
                // the previously selected element's size, and finger and
                // slider would end up disagreeing.
                draftScale = element.scale
            }

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
                settled.scale = min(max(draftScale * pinchScale, 0.2), 4)
                settled.rotation = element.rotation + spinAngle

                draftScale = settled.scale
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
                element.brushIndex = brushIndex
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

        // Filling a sticker rather than laying a photo on the page: the
        // picture goes inside the piece of paper, which keeps its size, angle
        // and any words already on it.
        if let id = fillingID, var host = manager.elements.first(where: { $0.id == id }) {
            host.imagePayload = base64
            manager.update(host, bookID: book.id, pageID: page.id)
            ScrapbookImageCache.shared.forget(id + "#inlay")
            fillingID = nil
            showingCamera = false
            selectedID = id
            return
        }

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
        place(element)
        showingCamera = false
    }

    /// Hands the page over to whatever was just added.
    ///
    /// The tool has to come back to select as well: adding a photo while the
    /// brush was in hand used to leave the brush active, so the first attempt
    /// to move or turn the new photo drew a line across it instead.
    private func place(_ element: ScrapbookElement) {
        tool = .select
        selectedID = element.id
        draftScale = element.scale
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
        place(element)
    }

    /// Drops one of the drawn paper bits on the page.
    ///
    /// It goes in as an ordinary sticker, so it's draggable, resizable,
    /// turnable and lockable like everything else without the editor needing
    /// to know it's any different.
    private func addDecoration(_ decoration: ScrapbookDecoration) {

        var element = ScrapbookElement(id: UUID().uuidString, kind: .sticker)
        element.payload = decoration.token
        element.colorHex = brushColor
        element.widthValue = 7
        element.z = manager.nextZ
        element.rotation = Double.random(in: -8...8)
        element.x = Double.random(in: 0.35...0.65)
        element.y = Double.random(in: 0.35...0.65)

        manager.add(element, bookID: book.id, pageID: page.id)
        place(element)
    }

    /// Drops a single cut-out letter on the page.
    ///
    /// Each is its own sticker rather than a word being one element, which is
    /// what lets a title be arranged letter by letter — turned, resized and
    /// nudged apart the way a real ransom-note heading is.
    private func addLetter(_ character: String) {

        var element = ScrapbookElement(id: UUID().uuidString, kind: .sticker)
        element.payload = ScrapbookLetter.token(character)
        element.widthValue = 7
        element.z = manager.nextZ
        element.rotation = Double.random(in: -7...7)
        element.x = Double.random(in: 0.30...0.70)
        element.y = Double.random(in: 0.30...0.70)

        manager.add(element, bookID: book.id, pageID: page.id)
        place(element)
    }

    /// Drops Ziggy on the page, in one of his moods.
    private func addPet(_ asset: String) {

        var element = ScrapbookElement(id: UUID().uuidString, kind: .sticker)
        element.payload = ScrapbookPet.token(asset)
        element.widthValue = 7
        element.z = manager.nextZ
        element.rotation = Double.random(in: -8...8)
        element.x = Double.random(in: 0.35...0.65)
        element.y = Double.random(in: 0.35...0.65)

        manager.add(element, bookID: book.id, pageID: page.id)
        place(element)
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
        element.widthValue = textSize
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

        // A sticker keeps its shape whether or not there are words on it, so
        // clearing a label empties the caption rather than removing the paper.
        if element.kind == .sticker {
            element.caption = clean
            element.fontIndex = textFontIndex
            element.widthValue = textSize
            element.captionColorHex = textColor
            manager.update(element, bookID: book.id, pageID: page.id)
            typingID = nil
            typedText = ""
            typingFocused = false
            return
        }

        if clean.isEmpty {
            manager.delete(id, bookID: book.id, pageID: page.id)
        } else {
            element.payload = clean
            element.fontIndex = textFontIndex
            element.colorHex = textColor
            element.widthValue = textSize
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

    private func commitScale(_ element: ScrapbookElement) {
        var updated = element
        updated.scale = draftScale
        manager.move(updated, bookID: book.id, pageID: page.id)
    }

    /// The action for writing words: on a piece of text already on the page, or
    /// on a paper sticker. Nothing for anything else.
    private func labelling(_ element: ScrapbookElement) -> (() -> Void)? {

        if element.kind == .text {
            return { startEditing(element) }
        }

        guard let decoration = decoration(of: element), decoration.holdsText
        else { return nil }

        return { startLabelling(element) }
    }

    /// Picks a finished piece of text back up.
    ///
    /// The words go back in the field and the bar opens on the font, colour and
    /// size they were written with, so changing any of them shows on the page
    /// as you choose rather than only once you are done. Before this, text was
    /// settled the moment you tapped Done — selecting it again offered no way
    /// to restyle it at all.
    private func startEditing(_ element: ScrapbookElement) {

        // Any line break already in there is flattened on the way in, so
        // re-opening old text doesn't trip the return-key handling below and
        // finish the moment it opens.
        typedText = element.payload.replacingOccurrences(of: "\n", with: " ")
        textFontIndex = element.fontIndex
        textColor = element.colorHex
        textSize = min(max(element.widthValue, 3), 20)

        typingID = element.id
        selectedID = nil
        tool = .select
        typingFocused = true
    }

    /// The action for putting a picture inside a sticker, for the ones that are
    /// a container rather than a shape.
    private func filling(_ element: ScrapbookElement) -> (() -> Void)? {

        guard let decoration = decoration(of: element), decoration.holdsImage
        else { return nil }

        return {
            fillingID = element.id
            photoPickerOpen = true
        }
    }

    /// The colour to change while something is selected: a piece of text's ink,
    /// the paper a drawn sticker is cut from, or the scrap a cut-out letter is
    /// snipped from. Only an emoji has nothing to change.
    private func tinting(_ element: ScrapbookElement) -> ((String) -> Void)? {

        let isLetter = element.kind == .sticker
            && ScrapbookLetter.character(from: element.payload) != nil

        guard element.kind == .text || decoration(of: element) != nil || isLetter
        else { return nil }

        return { hex in
            var updated = element
            // A letter's paper is its own field: `colorHex` on a letter has
            // always been the ink default nobody set, and reading it as paper
            // would turn every letter already on a page dark.
            if isLetter {
                updated.paperColorHex = hex
            } else {
                updated.colorHex = hex
            }
            manager.update(updated, bookID: book.id, pageID: page.id)
        }
    }

    /// The letter's own ink, alongside the scrap it is cut from.
    private func inking(_ element: ScrapbookElement) -> ((String) -> Void)? {

        guard element.kind == .sticker,
              ScrapbookLetter.character(from: element.payload) != nil
        else { return nil }

        return { hex in
            var updated = element
            updated.captionColorHex = hex
            manager.update(updated, bookID: book.id, pageID: page.id)
        }
    }

    /// Changing the lettering of something already written, without having to
    /// pick the words back up first.
    private func fonting(_ element: ScrapbookElement) -> ((Int) -> Void)? {

        let writing = element.kind == .text
            || (decoration(of: element)?.holdsText ?? false)

        guard writing else { return nil }

        return { index in
            var updated = element
            updated.fontIndex = index
            manager.update(updated, bookID: book.id, pageID: page.id)
        }
    }

    private func decoration(of element: ScrapbookElement) -> ScrapbookDecoration? {
        guard element.kind == .sticker else { return nil }
        return ScrapbookDecoration.from(payload: element.payload)
    }

    /// Types straight onto the sticker, the same way text goes on the page.
    ///
    /// The bar opens on the label's own size and ink rather than on whatever
    /// the last piece of page text used, so picking up an existing caption
    /// doesn't resize or recolour it the moment you touch anything.
    private func startLabelling(_ element: ScrapbookElement) {

        typedText = element.caption.replacingOccurrences(of: "\n", with: " ")
        textFontIndex = element.fontIndex
        textSize = min(max(element.widthValue, 3), 20)

        textColor = element.captionColorHex.isEmpty
            ? (ScrapbookStyle.isDark(hex: element.colorHex) ? "#FAF7F0" : "#332B24")
            : element.captionColorHex

        typingID = element.id
        selectedID = nil
        tool = .select
        typingFocused = true
    }

    private func toggleLock(_ element: ScrapbookElement) {
        var updated = element
        updated.locked.toggle()
        manager.update(updated, bookID: book.id, pageID: page.id)
    }

    private func setFrame(_ element: ScrapbookElement, to frame: ScrapbookStyle.Frame) {
        guard element.kind == .photo else { return }
        var updated = element
        updated.frameIndex = frame.rawValue
        manager.update(updated, bookID: book.id, pageID: page.id)
    }

    private func setFrameColour(_ element: ScrapbookElement, to hex: String) {
        guard element.kind == .photo else { return }
        var updated = element
        updated.frameColorHex = hex
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

    /// Removes an element, asking first when it holds something that cannot
    /// simply be tapped back into place.
    ///
    /// There is no undo anywhere in this editor, so Delete is final. A photo
    /// was imported, framed, turned and sized, and words were written — losing
    /// either to a mis-tap means doing all of it again. A sticker or a brush
    /// stroke is one tap to recreate, and asking every time would only teach
    /// people to dismiss the question without reading it.
    private func deleteSelected(_ element: ScrapbookElement) {

        if worthConfirming(element) {
            pendingDelete = element
        } else {
            remove(element)
        }
    }

    private func worthConfirming(_ element: ScrapbookElement) -> Bool {

        switch element.kind {
        case .photo:
            return true
        case .text:
            return !element.payload.isEmpty
        case .sticker:
            return !element.imagePayload.isEmpty
        case .stroke:
            return false
        }
    }

    /// What the question calls the thing being removed.
    private func describe(_ element: ScrapbookElement) -> String {

        switch element.kind {
        case .photo:  return "Delete this photo?"
        case .text:   return "Delete these words?"
        default:      return "Delete the picture inside this?"
        }
    }

    private func remove(_ element: ScrapbookElement) {
        manager.delete(element.id, bookID: book.id, pageID: page.id)
        selectedID = nil
        pendingDelete = nil
    }

    // MARK: Toolbar

    private var toolbar: some View {

        HStack(spacing: 6) {

            // Both clear whatever the last picker was aimed at. A cancelled
            // replace or fill otherwise stays armed, and the next picture
            // meant for the page would land inside that element instead.
            toolButton("photo.on.rectangle", "Photo") {
                replacingID = nil
                fillingID = nil
                photoPickerOpen = true
            }

            toolButton("camera.fill", "Camera") {
                replacingID = nil
                fillingID = nil
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
    @Binding var scale: Double
    let onScaleCommit: () -> Void
    let onFrame: () -> Void
    let onReplace: () -> Void

    /// Present only for paper stickers, which are the ones words look right on.
    let onLabel: (() -> Void)?

    /// Present only for the stickers a picture can go inside.
    let onInlay: (() -> Void)?

    /// Present for text, whose ink it changes, and for the stickers cut from
    /// paper, whose paper it changes.
    let onTint: ((String) -> Void)?

    /// Present for cut-out letters, which have a paper *and* a letter on it.
    let onInk: ((String) -> Void)?

    /// Present for anything with words on it.
    let onFont: ((Int) -> Void)?

    let onLock: () -> Void
    let onForward: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    /// The lettering is a row of sixteen, so it stays folded away until asked
    /// for rather than standing between the page and everything else.
    @State private var showingFonts = false

    var body: some View {

        VStack(spacing: 8) {

            // Same number the two-finger pinch drives, so the two ways of
            // resizing agree instead of fighting each other.
            if !element.locked {
                SizeSlider(
                    label: String(format: "%.0f%%", scale * 100),
                    value: $scale,
                    range: 0.3...3,
                    onCommit: onScaleCommit
                )
            }

            if showingFonts, let onFont { lettering(onFont) }

            if let onTint {
                swatches(tintTitle,
                         palette: isLetter
                            ? ScrapbookStyle.framePalette
                            : ScrapbookStyle.inkPalette,
                         chosen: isLetter ? element.paperColorHex : element.colorHex,
                         pick: onTint)
            }

            if let onInk {
                swatches("Letter",
                         palette: ScrapbookStyle.inkPalette,
                         chosen: element.captionColorHex,
                         pick: onInk)
            }

            actions
        }
        .padding(.vertical, 8)
        // Folded away again when the selection moves on, so it isn't still
        // open over an element it has nothing to do with.
        .onChange(of: element.id) { _, _ in showingFonts = false }
    }

    /// Every font, applied to what's selected as it's tapped.
    private func lettering(_ pick: @escaping (Int) -> Void) -> some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(ScrapbookStyle.fonts.enumerated()), id: \.offset) { index, choice in
                    Text(choice.label)
                        .font(ScrapbookStyle.font(index, size: 14))
                        .foregroundStyle(element.fontIndex == index
                                         ? Color(red: 0.16, green: 0.14, blue: 0.22)
                                         : .white)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(element.fontIndex == index
                                           ? Color.white
                                           : Color.white.opacity(0.12))
                        )
                        .onTapGesture { pick(index) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var isLetter: Bool {
        element.kind == .sticker
            && ScrapbookLetter.character(from: element.payload) != nil
    }

    /// A cut-out letter carries two strips at once, so each says what it is.
    private var tintTitle: String {
        if element.kind == .text { return "Colour" }
        return "Paper"
    }

    /// One row of colours, applied to the selection as it is tapped.
    private func swatches(
        _ title: String,
        palette: [String],
        chosen: String,
        pick: @escaping (String) -> Void
    ) -> some View {

        HStack(spacing: 10) {

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 40, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(scrapbookHex: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().strokeBorder(.white,
                                                      lineWidth: chosen == hex ? 3 : 1)
                            )
                            .onTapGesture { pick(hex) }
                    }
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.leading, 16)
    }

    /// "Write" only where there is nothing written yet.
    private var labelTitle: String {
        if element.kind == .text { return "Edit" }
        return element.caption.isEmpty ? "Write" : "Edit"
    }

    private var actions: some View {

        HStack(spacing: 8) {

            if element.kind == .photo {
                action("Frame", "square.on.square", onFrame)
                action("Replace", "arrow.triangle.2.circlepath", onReplace)
            }

            if let onInlay {
                action(element.imagePayload.isEmpty ? "Photo" : "Change",
                       "photo.on.rectangle", onInlay)
            }

            if let onLabel {
                action(labelTitle, "character.cursor.ibeam", onLabel)
            }

            if onFont != nil {
                action("Font", "textformat", {
                    withAnimation(.easeOut(duration: 0.18)) { showingFonts.toggle() }
                }, tint: showingFonts
                    ? Color(red: 1.0, green: 0.82, blue: 0.42)
                    : .white)
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

/// A labelled slider sized to sit in the editor's bars.
private struct SizeSlider: View {

    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {

        HStack(spacing: 10) {

            Image(systemName: "textformat.size")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))

            // Committed on release only — dragging it writes nothing until
            // the finger comes up, but the page updates the whole time.
            Slider(value: $value, in: range) { editing in
                if !editing { onCommit() }
            }
            .tint(.white.opacity(0.9))

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 18)
    }
}

// MARK: - Brush bar

private struct BrushBar: View {

    @Binding var color: String
    @Binding var width: Double
    @Binding var brushIndex: Int
    let isEraser: Bool

    var body: some View {

        VStack(spacing: 8) {

            if !isEraser {

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(ScrapbookStyle.brushes.enumerated()), id: \.offset) { index, brush in
                            Button {
                                brushIndex = index
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: brush.icon)
                                        .font(.system(size: 15, weight: .bold))
                                    Text(brush.label)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(brushIndex == index
                                                 ? Color(red: 0.16, green: 0.14, blue: 0.22)
                                                 : .white)
                                .frame(width: 66)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(brushIndex == index
                                              ? Color.white
                                              : Color.white.opacity(0.12))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

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

            // Laid out the way the doodle's is: nib, a plain slider, and a dot
            // showing the true width — no stepper buttons pinching the track.
            HStack(spacing: 14) {

                Image(systemName: "pencil.tip")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))

                Slider(value: $width, in: 2...60)
                    .tint(.white.opacity(0.9))

                Circle()
                    .fill(isEraser ? Color.white.opacity(0.65) : Color(scrapbookHex: color))
                    .frame(width: min(width, 30), height: min(width, 30))
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Typing bar

/// Font and colour, while the words are being typed on the page.
private struct TypingBar: View {

    @Binding var fontIndex: Int
    @Binding var colorHex: String
    @Binding var size: Double

    /// Words on a sticker are sized against the paper they sit on rather than
    /// in points, so the readout is a proportion of it.
    let onSticker: Bool

    let onDone: () -> Void

    var body: some View {

        VStack(spacing: 8) {

            SizeSlider(
                label: onSticker
                    ? String(format: "%.0f%%", size / 7 * 100)
                    : String(format: "%.0f", size * 3),
                value: $size,
                range: 3...20,
                onCommit: {}
            )

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

// MARK: - Sticker picker

private struct StickerPicker: View {

    let onEmoji: (String) -> Void
    let onDecoration: (ScrapbookDecoration) -> Void
    let onLetter: (String) -> Void
    let onPet: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let emojiColumns = [GridItem(.adaptive(minimum: 52), spacing: 10)]
    private let paperColumns = [GridItem(.adaptive(minimum: 84), spacing: 12)]
    private let letterColumns = [GridItem(.adaptive(minimum: 54), spacing: 8)]
    private let petColumns = [GridItem(.adaptive(minimum: 82), spacing: 10)]

    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("Stickers")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                petSection
                paperSection
                letterSection
                emojiSections
            }
            .padding(.bottom, 24)
        }
    }

    /// Ziggy first — he's the one thing here that's yours rather than everyone's.
    private var petSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Ziggy")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: petColumns, spacing: 10) {
                ForEach(ScrapbookPet.poses, id: \.asset) { pose in
                    VStack(spacing: 4) {

                        Image(pose.asset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 62, height: 62)

                        Text(pose.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 82, height: 88)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onPet(pose.asset)
                        dismiss()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// The paper bits come next — they're what makes a page look made rather
    /// than typed.
    private var paperSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Paper")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: paperColumns, spacing: 12) {
                ForEach(ScrapbookDecoration.allCases) { decoration in
                    tile(decoration)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func tile(_ decoration: ScrapbookDecoration) -> some View {

        // Drawn at tile size rather than drawn full size and shrunk. A
        // `scaleEffect` magnifies a picture that has already been rendered, so
        // the preview came out soft and — worse — its detail no longer matched
        // the proportions it lands on the page with.
        let fit = min(72 / decoration.size.width, 50 / decoration.size.height)

        return VStack(spacing: 5) {

            decoration.view(tint: ScrapbookStyle.terracotta, zoom: fit)
                .frame(width: decoration.size.width * fit,
                       height: decoration.size.height * fit)
                .frame(width: 78, height: 52)

            Text(decoration.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 84, height: 78)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onDecoration(decoration)
            dismiss()
        }
    }

    /// The cut-out alphabet. Tapping the same letter twice gives two of them,
    /// so a title gets spelled out one scrap at a time.
    private var letterSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Cut-out letters")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: letterColumns, spacing: 8) {
                ForEach(ScrapbookLetter.characters, id: \.self) { character in
                    ScrapbookLetterSticker(character: character)
                        .frame(width: 54, height: 58)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onLetter(character)
                            dismiss()
                        }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var emojiSections: some View {

        ForEach(ScrapbookStyle.stickerGroups, id: \.0) { group in

            VStack(alignment: .leading, spacing: 10) {

                Text(group.0)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: emojiColumns, spacing: 10) {
                    ForEach(group.1, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondary.opacity(0.10))
                            )
                            .onTapGesture {
                                onEmoji(emoji)
                                dismiss()
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Frame picker

/// Every frame, previewed on the actual photo, plus the paper it's cut from.
private struct FramePicker: View {

    let element: ScrapbookElement
    let onFrame: (ScrapbookStyle.Frame) -> Void
    let onColour: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    // Two to a row rather than four. The old tiles were 92pt wide with the
    // photo inside them, which left the actual frame too small to judge.
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {

        VStack(spacing: 16) {

            Text("Frame")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .padding(.top, 18)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ScrapbookStyle.Frame.allCases) { frame in
                        tile(frame)
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 8) {

                Text("Frame colour")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ScrapbookStyle.framePalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(scrapbookHex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(
                                        .primary.opacity(0.7),
                                        lineWidth: element.frameColorHex == hex ? 3 : 1
                                    )
                                )
                                .onTapGesture { onColour(hex) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 14)
        }
    }

    /// Each option drawn on a neutral sample, so the frame is the only thing
    /// that differs between tiles.
    private func tile(_ frame: ScrapbookStyle.Frame) -> some View {

        let chosen = element.frameIndex == frame.rawValue

        return VStack(spacing: 8) {

            ScrapbookFrameSample(frame: frame, paperHex: element.frameColorHex)
                .frame(height: 152)

            Text(frame.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(chosen ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(chosen ? 0.20 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(chosen ? Color.accentColor : .clear, lineWidth: 2)
                )
        )
        .contentShape(Rectangle())
        // Choosing the frame is the last thing you do here, so the sheet gets
        // out of the way by itself. The colour swatches below don't close it —
        // those you try against each other before settling on one.
        .onTapGesture {
            onFrame(frame)
            dismiss()
        }
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
    ///
    /// 1600px on the long side because a photo can be blown up to four times
    /// its resting size on the page. At the old 1200 the picture ran out of
    /// pixels before the zoom ran out of room, so it went soft at the top of
    /// the range no matter how it was drawn.
    ///
    /// 500 KB encodes to about 667 KB of base64, which leaves comfortable
    /// headroom under the 1,048,576-byte limit for the rest of the document.
    func scrapbookBase64(maxBytes: Int = 500_000) -> String? {

        for maxSide in [1600, 1300, 1000, 760] as [CGFloat] {

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
