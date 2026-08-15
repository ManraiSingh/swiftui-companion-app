//
//  ScrapbookShelfView.swift
//  Ziggy
//
//  The bookcase: an enclosed étagère of planks and posts, books standing on
//  it among the ornaments.
//
//  A tap opens a book. Holding one picks it up, which is the same state the
//  Edit button turns on — and in that state everything is draggable: books
//  shuffle along the row, ornaments go anywhere on any shelf.
//

import SwiftUI

enum ShelfSelection: Equatable {
    case book(String)
    case ornament(String)
}

// Geometry shared between the shelves and the ornament layer that floats over
// them. Both have to agree on where a shelf floor is, or a dragged object
// lands somewhere other than where it was dropped.
private enum ShelfMetrics {
    static let topCap: CGFloat = 13
    static let tierHeight: CGFloat = 200
    static let plankHeight: CGFloat = 13
    static let inset: CGFloat = 26
    static let ornamentBox: CGFloat = 134

    static var pitch: CGFloat { tierHeight + plankHeight }

    /// The y of the shelf surface objects on `tier` stand on.
    static func floorY(_ tier: Int) -> CGFloat {
        topCap + CGFloat(tier) * pitch + tierHeight
    }

    /// Which tier a point belongs to, for a drop.
    static func tier(forY y: CGFloat, tiers: Int) -> Int {
        let raw = Int(((y - topCap) / pitch).rounded(.down))
        return min(max(raw, 0), max(tiers - 1, 0))
    }
}

struct ScrapbookShelfView: View {

    @StateObject private var manager = ScrapbookManager.shared

    @State private var openBook: ScrapbookBook?
    @State private var showingNewBook = false
    @State private var renaming: ScrapbookBook?
    @State private var draftTitle = ""
    @State private var pendingDelete: ScrapbookBook?

    // Edit mode
    @State private var editing = false
    @State private var selection: ShelfSelection?
    @State private var draftTilt: Double = 0
    @State private var draftSize: Double = 1
    @State private var draftOrnamentScale: Double = 1

    // Live drag state
    @State private var draggingOrnament: String?
    @State private var ornamentDrag: CGSize = .zero
    @State private var draggingBook: String?
    @State private var bookDrag: CGFloat = 0
    @State private var bookDragConsumed: CGFloat = 0

    private static let perShelf = 3

    private var selectedBook: ScrapbookBook? {
        guard case .book(let id) = selection else { return nil }
        return manager.books.first { $0.id == id }
    }

    private var selectedOrnament: ScrapbookOrnamentPlacement? {
        guard case .ornament(let id) = selection else { return nil }
        return placements.first { $0.id == id }
    }

    private var shelves: [[ScrapbookBook]] {

        let filled = stride(from: 0, to: manager.books.count, by: Self.perShelf).map { start in
            Array(manager.books.dropFirst(start).prefix(Self.perShelf))
        }

        return filled + Array(repeating: [], count: max(3 - filled.count, 0))
    }

    private var placements: [ScrapbookOrnamentPlacement] {
        manager.resolvedOrnaments(tiers: shelves.count)
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [ScrapbookStyle.wallTop, ScrapbookStyle.wallBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    header

                    etagere
                        .padding(.horizontal, 14)
                        .padding(.bottom, selection == nil ? 26 : 300)

                    if let error = manager.lastError {
                        errorNote(error)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Dragging an object and scrolling the shelf are both vertical, so
            // the scroll view stands down while something is being moved.
            .scrollDisabled(draggingOrnament != nil || draggingBook != nil)
            .blur(radius: openBook == nil ? 0 : 7)
            .allowsHitTesting(openBook == nil)

            if openBook == nil { editPanel }

            if let book = openBook {
                ScrapbookBookView(book: book) {
                    withAnimation(.easeInOut(duration: 0.28)) { openBook = nil }
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .onAppear {
            manager.startShelf()
            manager.startOrnaments()
        }
        .sheet(isPresented: $showingNewBook) {
            NewBookSheet { title, cover in
                manager.createBook(title: title, coverIndex: cover)
            }
            .presentationDetents([.height(560)])
        }
        .alert("Rename book", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Title", text: $draftTitle)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let book = renaming { manager.renameBook(book.id, to: draftTitle) }
                renaming = nil
            }
        }
        .alert("Delete this book?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let book = pendingDelete {
                    manager.deleteBook(book.id)
                    if selection == .book(book.id) { selection = nil }
                }
                pendingDelete = nil
            }
        } message: {
            Text("Every page inside it goes too, for both of you. This can't be undone.")
        }
    }

    // MARK: Panel

    @ViewBuilder
    private var editPanel: some View {

        VStack {
            Spacer()

            if let book = selectedBook {
                BookEditPanel(
                    book: book,
                    tilt: $draftTilt,
                    size: $draftSize,
                    onCover: { manager.setCover(book.id, coverIndex: $0) },
                    onRename: {
                        draftTitle = book.title
                        renaming = book
                    },
                    onDelete: { pendingDelete = book },
                    onClose: { close() },
                    onCommit: {
                        manager.setLayout(book.id, tilt: draftTilt, sizeScale: draftSize)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))

            } else if let placement = selectedOrnament {
                OrnamentEditPanel(
                    placement: placement,
                    scale: $draftOrnamentScale,
                    onKind: { setKind(placement, to: $0) },
                    onRemove: { remove(placement) },
                    onClose: { close() },
                    onCommit: { setScale(placement, to: draftOrnamentScale) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(2)
    }

    private func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { selection = nil }
    }

    // MARK: Header

    private var header: some View {

        HStack(alignment: .firstTextBaseline) {

            VStack(alignment: .leading, spacing: 3) {

                Text("Scrapbook")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(ScrapbookStyle.outline)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ScrapbookStyle.outline.opacity(0.6))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                    editing.toggle()
                    if !editing { selection = nil }
                }
            } label: {
                Text(editing ? "Done" : "Edit")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(editing ? ScrapbookStyle.paperWhite : ScrapbookStyle.outline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(editing ? ScrapbookStyle.outline : ScrapbookStyle.cream)
                            .overlay(Capsule().stroke(ScrapbookStyle.outline, lineWidth: 2))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var subtitle: String {
        if editing { return "Drag anything to move it. Tap to resize." }
        if manager.books.isEmpty { return "Start a book. Fill it together." }
        return "\(manager.books.count) book\(manager.books.count == 1 ? "" : "s") on the shelf"
    }

    // MARK: The bookcase

    private var etagere: some View {

        ZStack(alignment: .topLeading) {

            HStack {
                post
                Spacer(minLength: 0)
                post
            }

            VStack(spacing: 0) {

                Outlined(radius: 3, fill: ScrapbookStyle.woodLight)
                    .frame(height: ShelfMetrics.topCap)

                ForEach(Array(shelves.enumerated()), id: \.offset) { index, row in
                    ShelfTier(
                        books: row,
                        showsAddSlot: index == manager.books.count / Self.perShelf,
                        editing: editing,
                        selection: selection,
                        draggingBook: draggingBook,
                        bookDrag: bookDrag,
                        onOpenBook: { book in
                            withAnimation(.easeInOut(duration: 0.3)) { openBook = book }
                        },
                        onSelectBook: { select($0) },
                        onDragBook: { book, translation in dragBook(book, by: translation) },
                        onDropBook: { endBookDrag() },
                        onAdd: { showingNewBook = true }
                    )
                }
            }

            // Ornaments float over the whole case rather than living inside a
            // shelf, which is what lets one be dragged from any shelf to any
            // other in a single movement.
            ornamentLayer
        }
    }

    private var ornamentLayer: some View {

        GeometryReader { proxy in

            ZStack(alignment: .topLeading) {

                ForEach(placements) { placement in

                    let isDragging = draggingOrnament == placement.id
                    let width = placement.displayWidth
                    let span = max(proxy.size.width - ShelfMetrics.inset * 2 - width, 1)

                    placement.ornament.view
                        .frame(width: width, height: ShelfMetrics.ornamentBox, alignment: .bottom)
                        .scaleEffect(placement.clampedScale, anchor: .bottom)
                        .overlay {
                            if selection == .ornament(placement.id) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(ScrapbookStyle.blossom, lineWidth: 3)
                                    .padding(-4)
                            }
                        }
                        .scaleEffect(isDragging ? 1.08 : 1)
                        .shadow(
                            color: ScrapbookStyle.outline.opacity(isDragging ? 0.35 : 0),
                            radius: 12, y: 8
                        )
                        .offset(
                            x: ShelfMetrics.inset + CGFloat(placement.x) * span,
                            y: ShelfMetrics.floorY(placement.tier) - ShelfMetrics.ornamentBox
                        )
                        .offset(isDragging ? ornamentDrag : .zero)
                        .contentShape(Rectangle())
                        .zIndex(isDragging ? 10 : 0)
                        .onTapGesture { select(ornament: placement) }
                        .onLongPressGesture(minimumDuration: 0.3) { select(ornament: placement) }
                        .gesture(ornamentGesture(placement, span: span), isEnabled: editing)
                        .animation(
                            .spring(response: 0.34, dampingFraction: 0.8),
                            value: isDragging ? -1 : placement.x
                        )
                }
            }
        }
        .allowsHitTesting(openBook == nil)
    }

    private func ornamentGesture(
        _ placement: ScrapbookOrnamentPlacement,
        span: CGFloat
    ) -> some Gesture {

        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggingOrnament != placement.id {
                    draggingOrnament = placement.id
                    select(ornament: placement)
                }
                ornamentDrag = value.translation
            }
            .onEnded { value in

                var moved = placement

                let newX = CGFloat(placement.x) + value.translation.width / span
                moved.x = Double(min(max(newX, 0), 1))

                let droppedY = ShelfMetrics.floorY(placement.tier) + value.translation.height
                moved.tier = ShelfMetrics.tier(forY: droppedY - 1, tiers: shelves.count)

                draggingOrnament = nil
                ornamentDrag = .zero

                var all = placements
                if let index = all.firstIndex(where: { $0.id == placement.id }) {
                    all[index] = moved
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        manager.saveOrnaments(all)
                    }
                }
            }
    }

    private var post: some View {
        Outlined(radius: 4, fill: ScrapbookStyle.woodDark)
            .frame(width: 15)
    }

    // MARK: Books

    /// Reordering while the finger is still down.
    ///
    /// Each time the drag passes one book's width, the book trades places with
    /// its neighbour and that distance is subtracted from the visible offset,
    /// so the spine keeps following the finger instead of snapping back.
    private func dragBook(_ book: ScrapbookBook, by translation: CGFloat) {

        if draggingBook != book.id {
            draggingBook = book.id
            bookDragConsumed = 0
            select(book)
        }

        let step = book.displayThickness + 7
        var net = translation - bookDragConsumed

        while net > step {
            manager.moveBook(book.id, by: 1)
            bookDragConsumed += step
            net -= step
        }

        while net < -step {
            manager.moveBook(book.id, by: -1)
            bookDragConsumed -= step
            net += step
        }

        bookDrag = net
    }

    private func endBookDrag() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            draggingBook = nil
            bookDrag = 0
            bookDragConsumed = 0
        }
    }

    // MARK: Selection

    private func select(_ book: ScrapbookBook) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            editing = true
            selection = .book(book.id)
            draftTilt = book.tilt
            draftSize = book.sizeScale
        }
    }

    private func select(ornament placement: ScrapbookOrnamentPlacement) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            editing = true
            selection = .ornament(placement.id)
            draftOrnamentScale = placement.scale
        }
    }

    // MARK: Ornament edits

    private func setKind(_ placement: ScrapbookOrnamentPlacement, to kind: Int) {
        var all = placements
        guard let index = all.firstIndex(where: { $0.id == placement.id }) else { return }
        all[index].kind = kind
        manager.saveOrnaments(all)
    }

    private func setScale(_ placement: ScrapbookOrnamentPlacement, to scale: Double) {
        var all = placements
        guard let index = all.firstIndex(where: { $0.id == placement.id }) else { return }
        all[index].scale = scale
        manager.saveOrnaments(all)
    }

    private func remove(_ placement: ScrapbookOrnamentPlacement) {
        let all = placements.filter { $0.id != placement.id }
        selection = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            manager.saveOrnaments(all)
        }
    }

    private func errorNote(_ text: String) -> some View {

        VStack(spacing: 6) {
            Label("Couldn't reach the shelf", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(text)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color(red: 0.55, green: 0.16, blue: 0.16))
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.8))
        )
    }
}

// MARK: - One tier

private struct ShelfTier: View {

    let books: [ScrapbookBook]
    let showsAddSlot: Bool
    let editing: Bool
    let selection: ShelfSelection?
    let draggingBook: String?
    let bookDrag: CGFloat

    let onOpenBook: (ScrapbookBook) -> Void
    let onSelectBook: (ScrapbookBook) -> Void
    let onDragBook: (ScrapbookBook, CGFloat) -> Void
    let onDropBook: () -> Void
    let onAdd: () -> Void

    var body: some View {

        VStack(spacing: 0) {

            HStack(alignment: .bottom, spacing: 7) {

                ForEach(books) { book in

                    let isDragging = draggingBook == book.id

                    BookSpine(
                        book: book,
                        isSelected: selection == .book(book.id),
                        isDragging: isDragging
                    )
                    .offset(x: isDragging ? bookDrag : 0)
                    .zIndex(isDragging ? 10 : 0)
                    .contentShape(Rectangle())
                    // One gesture set, at one level. An inner press-animation
                    // gesture used to recognise on touch-down and swallow both
                    // the tap and the long press, so a book could not be
                    // opened or picked up at all.
                    .onTapGesture { editing ? onSelectBook(book) : onOpenBook(book) }
                    .onLongPressGesture(minimumDuration: 0.3) { onSelectBook(book) }
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { onDragBook(book, $0.translation.width) }
                            .onEnded { _ in onDropBook() },
                        isEnabled: editing
                    )
                }

                if showsAddSlot {
                    AddBookSlot(width: 50, action: onAdd)
                }

                Spacer(minLength: 0)
            }
            // Clears the uprights. A book leaning at the edge swings wider
            // than its own frame, so the inset has to be more than the post.
            .padding(.horizontal, ShelfMetrics.inset)
            .frame(height: ShelfMetrics.tierHeight, alignment: .bottom)

            Outlined(radius: 3, fill: ScrapbookStyle.wood)
                .frame(height: ShelfMetrics.plankHeight)
        }
    }
}

// MARK: - A book standing up

private struct BookSpine: View {

    let book: ScrapbookBook
    let isSelected: Bool
    let isDragging: Bool

    private var cover: ScrapbookStyle.Cover { ScrapbookStyle.cover(book.coverIndex) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 3, style: .continuous) }

    var body: some View {

        ZStack {

            shape.fill(cover.front)

            VStack {
                bandLine
                Spacer()
                bandLine
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 5)

            // Vertical spine text. `rotationEffect` is a render-time
            // transform and does not change the size the view reports to its
            // parent, so the title is sized before it turns and given a narrow
            // footprint again afterwards. Without the second frame every spine
            // claims the width of its own title and the shelf bursts open.
            Text(book.title)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundStyle(cover.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: book.displayHeight - 44)
                .rotationEffect(.degrees(-90))
                .frame(width: 14, height: book.displayHeight - 44)
        }
        .frame(width: book.displayThickness, height: book.displayHeight)
        .clipShape(shape)
        .overlay(shape.stroke(ScrapbookStyle.outline, lineWidth: 2))
        .overlay {
            if isSelected {
                shape.stroke(ScrapbookStyle.blossom, lineWidth: 3).padding(-4)
            }
        }
        // A lifted book stands straight and rides above its neighbours.
        .rotationEffect(.degrees(isDragging ? 0 : book.tilt), anchor: .bottom)
        .scaleEffect(isDragging ? 1.06 : 1, anchor: .bottom)
        .shadow(
            color: ScrapbookStyle.outline.opacity(isDragging ? 0.4 : 0.22),
            radius: isDragging ? 12 : 4,
            x: isDragging ? 0 : 2,
            y: isDragging ? 8 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: book.tilt)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: book.sizeScale)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isDragging)
    }

    private var bandLine: some View {
        Rectangle()
            .fill(cover.title.opacity(0.5))
            .frame(height: 1.5)
    }
}

// MARK: - Empty slot

private struct AddBookSlot: View {

    let width: CGFloat
    let action: () -> Void

    var body: some View {

        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                Text("New")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(ScrapbookStyle.outline.opacity(0.55))
            .frame(width: width, height: 138)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        ScrapbookStyle.outline.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 5])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared panel chrome

private struct PanelShell<Content: View>: View {

    let title: String
    let hint: String
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {

        VStack(spacing: 14) {

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .lineLimit(1)
                    Text(hint)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ScrapbookStyle.outline.opacity(0.55))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(ScrapbookStyle.cream))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(ScrapbookStyle.outline)

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ScrapbookStyle.paperWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(ScrapbookStyle.outline, lineWidth: 2)
                )
                .shadow(color: ScrapbookStyle.outline.opacity(0.25), radius: 14, y: 6)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}

private struct PanelSlider: View {

    let label: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {

        HStack(spacing: 10) {

            Label(label, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(ScrapbookStyle.outline.opacity(0.75))
                .frame(width: 62, alignment: .leading)

            // The commit lands on release, so a drag doesn't fire a write per
            // frame at both ends of the relationship.
            Slider(value: $value, in: range) { editing in
                if !editing { onCommit() }
            }
            .tint(ScrapbookStyle.terracotta)
        }
    }
}

// MARK: - Book panel

private struct BookEditPanel: View {

    let book: ScrapbookBook
    @Binding var tilt: Double
    @Binding var size: Double

    let onCover: (Int) -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    let onCommit: () -> Void

    var body: some View {

        PanelShell(title: book.title, hint: "Drag the book to move it", onClose: onClose) {

            PanelSlider(label: "Size", systemImage: "arrow.up.left.and.arrow.down.right",
                        value: $size, range: 0.78...1.22, onCommit: onCommit)

            PanelSlider(label: "Tilt", systemImage: "angle",
                        value: $tilt, range: -14...14, onCommit: onCommit)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(ScrapbookStyle.covers.enumerated()), id: \.offset) { index, cover in
                        Circle()
                            .fill(cover.front)
                            .overlay(Circle().stroke(ScrapbookStyle.outline,
                                                     lineWidth: book.coverIndex == index ? 3 : 1.5))
                            .frame(width: 30, height: 30)
                            .onTapGesture { onCover(index) }
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 10) {

                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ScrapbookStyle.outline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(ScrapbookStyle.cream)
                        )
                }

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.72, green: 0.20, blue: 0.20))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(red: 0.98, green: 0.90, blue: 0.89))
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Ornament panel

private struct OrnamentEditPanel: View {

    let placement: ScrapbookOrnamentPlacement
    @Binding var scale: Double

    let onKind: (Int) -> Void
    let onRemove: () -> Void
    let onClose: () -> Void
    let onCommit: () -> Void

    var body: some View {

        PanelShell(title: placement.ornament.label,
                   hint: "Drag it anywhere on the shelves",
                   onClose: onClose) {

            PanelSlider(label: "Size", systemImage: "arrow.up.left.and.arrow.down.right",
                        value: $scale, range: 0.7...1.35, onCommit: onCommit)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ScrapbookOrnament.allCases) { option in
                        option.view
                            .scaleEffect(0.42, anchor: .center)
                            .frame(width: 46, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(ScrapbookStyle.cream)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(ScrapbookStyle.outline,
                                                    lineWidth: placement.kind == option.rawValue ? 2.5 : 0)
                                    )
                            )
                            .onTapGesture { onKind(option.rawValue) }
                    }
                }
                .padding(.horizontal, 2)
            }

            Button(action: onRemove) {
                Label("Take off the shelf", systemImage: "trash")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.72, green: 0.20, blue: 0.20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(red: 0.98, green: 0.90, blue: 0.89))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - New book sheet

private struct NewBookSheet: View {

    let onCreate: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var coverIndex = 0
    @FocusState private var titleFocused: Bool

    var body: some View {

        VStack(spacing: 20) {

            Capsule()
                .fill(.secondary.opacity(0.3))
                .frame(width: 38, height: 5)
                .padding(.top, 10)

            Text("New book")
                .font(.system(size: 22, weight: .bold, design: .serif))

            preview

            TextField("Name it — Japan 2024, Us, Sundays…", text: $title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .focused($titleFocused)
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.secondary.opacity(0.10))
                )
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(ScrapbookStyle.covers.enumerated()), id: \.offset) { index, cover in
                        Circle()
                            .fill(cover.front)
                            .overlay(Circle().stroke(ScrapbookStyle.outline,
                                                     lineWidth: coverIndex == index ? 3 : 1.5))
                            .frame(width: 34, height: 34)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    coverIndex = index
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }

            Button {
                onCreate(title, coverIndex)
                dismiss()
            } label: {
                Text("Put it on the shelf")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ScrapbookStyle.paperWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ScrapbookStyle.cover(coverIndex).spine)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ScrapbookStyle.outline, lineWidth: 2)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .onAppear { titleFocused = true }
    }

    private var preview: some View {

        let cover = ScrapbookStyle.cover(coverIndex)

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(cover.front)
            .frame(width: 106, height: 138)
            .overlay(
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(cover.title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(cover.spine)
                    .frame(width: 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ScrapbookStyle.outline, lineWidth: 2)
            )
            .shadow(color: ScrapbookStyle.outline.opacity(0.25), radius: 10, y: 6)
            .animation(.easeInOut(duration: 0.2), value: coverIndex)
    }
}
