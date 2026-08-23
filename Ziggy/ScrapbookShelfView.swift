//
//  ScrapbookShelfView.swift
//  Ziggy
//
//  The bookcase. Books and ornaments share one running order and flow across
//  the shelves together, so anything can be dragged in beside anything else
//  and the rest of the row makes room for it.
//
//  Rearranging only happens under the Edit button. Outside it a tap opens a
//  book and nothing moves.
//

import SwiftUI
import Observation

/// The finger's position during a drag.
///
/// Held in an observable box rather than in `@State` on the shelf. As plain
/// view state, every frame of movement invalidated the whole bookcase and
/// redrew every ornament's vector art — a plant is eight circles and eight
/// curves, and there are several on screen. Now only the carried copy, which
/// is the one view that reads this, redraws as the finger moves.
@Observable
final class ShelfDragPoint {
    var value: CGPoint = .zero
}

/// The item in hand, drawn under the finger.
private struct CarriedItem<Content: View>: View {

    let store: ShelfDragPoint
    @ViewBuilder var content: Content

    var body: some View {
        content
            .position(store.value)
            // Never animated: it should sit exactly under the finger, and any
            // inherited animation shows up as drag lag.
            .transaction { $0.animation = nil }
            .allowsHitTesting(false)
    }
}

enum ShelfSelection: Equatable {
    case book(String)
    case ornament(String)
}

/// Every measurement the bookcase is built from.
///
/// Held against a reference width and scaled to whatever the phone gives, so
/// the shelf is one illustration at different sizes rather than a different
/// composition on each device. In fixed points a book took 12.7% of the shelf
/// on an SE and 10.7% on a Pro Max — same book, noticeably different picture.
private struct ShelfMetrics {

    /// Raised from 360 to bring the whole bookcase down about 15% — at the
    /// old figure the shelves ate the screen and only two fitted at a time.
    static let referenceWidth: CGFloat = 430

    let unit: CGFloat

    init(width: CGFloat) {
        unit = max(width, 1) / Self.referenceWidth
    }

    /// A base measurement, taken at this shelf's size.
    func scaled(_ value: CGFloat) -> CGFloat { value * unit }

    var topCap: CGFloat { scaled(13) }
    var tierHeight: CGFloat { scaled(200) }
    var plankHeight: CGFloat { scaled(13) }
    var inset: CGFloat { scaled(26) }
    var spacing: CGFloat { scaled(7) }
    var addSlot: CGFloat { scaled(50) }
    var ornamentBox: CGFloat { scaled(134) }
    var bookSlotHeight: CGFloat { scaled(138) }
    var postWidth: CGFloat { scaled(15) }
    var gutterInset: CGFloat { scaled(14) }

    var pitch: CGFloat { tierHeight + plankHeight }

    /// The y of the shelf surface that the items on `tier` stand on.
    func floorY(_ tier: Int) -> CGFloat {
        topCap + CGFloat(tier) * pitch + tierHeight
    }

    /// Which shelf a point falls on, for a drop.
    func tier(forY y: CGFloat, count: Int) -> Int {
        let raw = Int(((y - topCap) / pitch).rounded(.down))
        return min(max(raw, 0), max(count - 1, 0))
    }
}

private struct ShelfWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ScrapbookShelfView: View {

    @StateObject private var manager = ScrapbookManager.shared

    @State private var openBook: ScrapbookBook?
    @State private var showingNewBook = false
    @State private var paywall: PaywallReason?
    @State private var renaming: ScrapbookBook?
    @State private var draftTitle = ""
    @State private var pendingDelete: ScrapbookBook?

    @State private var editing = false
    @State private var selection: ShelfSelection?
    @State private var draftTilt: Double = 0
    @State private var draftSize: Double = 1
    @State private var draftOrnamentScale: Double = 1

    @State private var dragging: String?
    @State private var shelfWidth: CGFloat = 0

    /// Where the finger is, in the bookcase's own coordinate space. Read only
    /// by the carried copy, so moving it doesn't redraw the shelf.
    @State private var dragPoint = ShelfDragPoint()

    /// The slot the row is currently opened at, so a drag that stays within
    /// one slot doesn't rewrite the order on every frame.
    @State private var lastIndex: Int?

    /// The order being worked on during a drag, kept entirely locally until
    /// the finger comes up.
    @State private var dragOrder: [ShelfItem]?

    /// The other items' arrangement, frozen for the duration of a drag so the
    /// drop target can't move around underneath the finger.
    @State private var dragLayout: [[ShelfItem]]?

    /// Everything the bookcase is measured with, at this phone's width.
    private var metrics: ShelfMetrics { ShelfMetrics(width: shelfWidth) }

    private var selectedBook: ScrapbookBook? {
        guard case .book(let id) = selection else { return nil }
        return manager.books.first { $0.id == id }
    }

    private var selectedOrnament: ScrapbookOrnamentPlacement? {
        guard case .ornament(let id) = selection else { return nil }
        return manager.resolvedOrnaments.first { $0.id == id }
    }

    /// The saved order, as it stands in Firestore — with the panel's drafts
    /// painted over whichever item is selected.
    ///
    /// The sliders only write on release, so without this the shelf went on
    /// showing the saved size and tilt until the finger came up. Previewing
    /// the draft here is what makes the spine grow and lean as the slider
    /// moves, and the row reflow around it comes along for free.
    private var baseItems: [ShelfItem] {

        let books = manager.books.map { book -> ScrapbookBook in
            guard case .book(let id) = selection, id == book.id else { return book }
            var preview = book
            preview.sizeScale = draftSize
            preview.tilt = draftTilt
            return preview
        }

        let ornaments = manager.resolvedOrnaments.map { placement -> ScrapbookOrnamentPlacement in
            guard case .ornament(let id) = selection, id == placement.id else { return placement }
            var preview = placement
            preview.scale = draftOrnamentScale
            return preview
        }

        let scale = metrics.unit

        return (books.map { ShelfItem(book: $0, unit: scale) }
                + ornaments.map {
                    ShelfItem(ornament: $0, boxHeight: metrics.ornamentBox, unit: scale)
                })
            .sorted { $0.position < $1.position }
    }

    /// What's actually laid out. While a drag is running this is the local
    /// working copy, so shuffling the row costs nothing but an array move —
    /// no writes, no listener echo, and no republishing the whole shelf on
    /// every frame of the drag.
    private var items: [ShelfItem] { dragOrder ?? baseItems }

    /// The order broken into shelves by width, with the "New" slot last.
    ///
    /// Everything flows: when a row fills up, the next item starts the shelf
    /// below. That's what makes dropping something into a full shelf push the
    /// last item down rather than overlap it, and it means there is always
    /// somewhere for a dragged item to land.
    private var tiers: [[ShelfItem]] { flow(items) }

    private func flow(_ list: [ShelfItem]) -> [[ShelfItem]] {

        // The "add an object" slot only exists while arranging, so the shelf
        // stays uncluttered the rest of the time.

        let available = max(shelfWidth - metrics.inset * 2, 1)
        var rows: [[ShelfItem]] = []
        var row: [ShelfItem] = []
        var used: CGFloat = 0

        var trailing = [ShelfItem(addSlotWidth: metrics.addSlot,
                                  height: metrics.bookSlotHeight)]

        // Alongside Add Book rather than only while editing. Putting things on
        // the shelf is the same kind of act as starting a book, and hiding it
        // behind Edit meant the only way to find it was to go looking for
        // something else.
        trailing.append(ShelfItem(addOrnamentWidth: metrics.addSlot,
                                  height: metrics.bookSlotHeight))

        for item in list + trailing {

            let needed = item.width + (row.isEmpty ? 0 : metrics.spacing)

            if used + needed > available, !row.isEmpty {
                rows.append(row)
                row = []
                used = 0
            }

            used += item.width + (row.isEmpty ? 0 : metrics.spacing)
            row.append(item)
        }

        if !row.isEmpty { rows.append(row) }

        // Always looks like a piece of furniture, never one lonely plank.
        return rows + Array(repeating: [], count: max(3 - rows.count, 0))
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
            // Dragging and scrolling are both vertical, so the scroll view
            // stands down while something is being moved.
            .scrollDisabled(dragging != nil)
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
        .paywall($paywall)
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
        if editing { return "Drag anything anywhere. Tap to resize." }
        if manager.books.isEmpty { return "Start a book. Fill it together." }
        return "Tap a book to open it"
    }

    // MARK: The bookcase

    /// Where every item stands, in the bookcase's own coordinates.
    private func placements(_ rows: [[ShelfItem]]) -> [String: CGPoint] {

        var map: [String: CGPoint] = [:]

        for (tier, row) in rows.enumerated() {
            var x = metrics.inset
            for item in row {
                map[item.id] = CGPoint(x: x, y: metrics.floorY(tier) - item.height)
                x += item.width + metrics.spacing
            }
        }

        return map
    }

    private var etagere: some View {

        let rows = tiers
        let spots = placements(rows)
        let height = metrics.topCap + CGFloat(rows.count) * metrics.pitch

        return ZStack(alignment: .topLeading) {

            HStack {
                post
                Spacer(minLength: 0)
                post
            }

            // The furniture: the top and one plank under each row.
            VStack(spacing: 0) {

                Outlined(radius: 3, fill: ScrapbookStyle.woodLight)
                    .frame(height: metrics.topCap)

                ForEach(0..<rows.count, id: \.self) { _ in
                    Color.clear.frame(height: metrics.tierHeight)
                    Outlined(radius: 3, fill: ScrapbookStyle.wood)
                        .frame(height: metrics.plankHeight)
                }
            }

            // Every item in one flat list, placed by offset rather than nested
            // inside a stack per shelf.
            //
            // With a container per row, an item crossing onto another shelf
            // was destroyed by one ForEach and rebuilt by the next — and the
            // drag gesture died with the view it was attached to, which is
            // why dragging up or down stuck halfway. One list keeps each view
            // alive wherever it moves to.
            ForEach(rows.flatMap { $0 }) { item in
                itemView(item)
                    .offset(
                        x: spots[item.id]?.x ?? 0,
                        y: spots[item.id]?.y ?? 0
                    )
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: items.map(\.id))

            // The thing being carried, drawn on top and following the finger.
            if let id = dragging, let item = items.first(where: { $0.id == id }) {
                CarriedItem(store: dragPoint) {
                    itemBody(item)
                        .scaleEffect(1.08, anchor: .center)
                        .shadow(color: ScrapbookStyle.outline.opacity(0.4), radius: 14, y: 10)
                }
                .zIndex(50)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height)
        .coordinateSpace(name: "etagere")
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ShelfWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ShelfWidthKey.self) { shelfWidth = $0 }
    }

    @ViewBuilder
    private func itemBody(_ item: ShelfItem) -> some View {

        switch item.kind {

        case .book(let book):
            BookSpine(
                book: book,
                unit: metrics.unit,
                isSelected: selection == .book(book.id),
                isLifted: dragging == book.id
            )

        case .ornament(let placement):
            placement.ornament.view
                .frame(width: placement.ornament.width,
                       height: 134,
                       alignment: .bottom)
                // Drawn at its natural size then scaled — these are vector
                // shapes, so the transform costs nothing in sharpness.
                .scaleEffect(placement.clampedScale * metrics.unit, anchor: .bottom)
                .frame(width: placement.displayWidth * metrics.unit,
                       height: metrics.ornamentBox,
                       alignment: .bottom)
                .overlay {
                    if selection == .ornament(placement.id) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(ScrapbookStyle.blossom, lineWidth: 3)
                            .padding(-4)
                    }
                }

        case .addSlot:
            AddSlot(width: metrics.addSlot, unit: metrics.unit,
                    icon: "plus", label: "Book") {
                if ZiggySubscription.shared.canAddBook(existing: manager.books.count) {
                    showingNewBook = true
                } else {
                    paywall = .books
                }
            }

        case .addOrnament:
            AddSlot(width: metrics.addSlot, unit: metrics.unit,
                    icon: "leaf", label: "Object") { addOrnament() }
        }
    }

    /// Puts another object at the end of the shelf.
    ///
    /// Picks a kind that isn't already out, so tapping twice gives two
    /// different things rather than a matching pair.
    private func addOrnament() {

        var all = manager.resolvedOrnaments
        let used = Set(all.map(\.kind))

        let kind = ScrapbookOrnament.allCases.first { !used.contains($0.rawValue) }?.rawValue
            ?? ScrapbookOrnament.allCases[all.count % ScrapbookOrnament.allCases.count].rawValue

        all.append(
            ScrapbookOrnamentPlacement(
                id: UUID().uuidString,
                position: (items.map(\.position).max() ?? 0) + 1_000,
                kind: kind
            )
        )

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            manager.saveOrnaments(all)
        }
    }

    @ViewBuilder
    private func itemView(_ item: ShelfItem) -> some View {

        let isDragging = dragging == item.id

        itemBody(item)
            // While it's being carried, its place in the row is held open as
            // a faint outline so you can see where it will land.
            .opacity(isDragging ? 0.22 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                switch item.kind {
                case .book(let book):
                    // Under Edit a tap picks the book to change, not to read —
                    // opening it there would fight the thing you came to do.
                    if editing {
                        select(book)
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { openBook = book }
                    }
                case .ornament(let placement):
                    if editing { select(ornament: placement) }
                case .addSlot, .addOrnament:
                    break
                }
            }
            // High priority so the drag beats the surrounding ScrollView.
            // With a plain `.gesture` the scroll view claimed every vertical
            // pan before this recognised, which left dragging working
            // sideways only.
            .highPriorityGesture(dragGesture(for: item), isEnabled: editing && item.isMovable)
    }

    private var post: some View {
        Outlined(radius: 4, fill: ScrapbookStyle.woodDark)
            .frame(width: metrics.postWidth)
    }

    // MARK: Dragging

    /// Reordering happens live, while the finger is still down: the item moves
    /// to whatever slot the finger is over and the rest of the row reflows
    /// around it, which is what opens the gap ahead of it.
    private func dragGesture(for item: ShelfItem) -> some Gesture {

        DragGesture(minimumDistance: 6, coordinateSpace: .named("etagere"))
            .onChanged { value in

                if dragging != item.id {
                    dragging = item.id
                    dragOrder = baseItems
                    dragLayout = flow(baseItems.filter { $0.id != item.id })
                    lastIndex = nil
                    // The panel belongs to a tap. Picking something up should
                    // clear the way, not put a sheet over the shelf you're
                    // trying to drop onto.
                    selection = nil
                }

                // Tracked every frame — this is what makes it follow the
                // finger rather than hop between slots.
                dragPoint.value = value.location

                guard let target = insertionIndex(at: value.location),
                      target != lastIndex,
                      var order = dragOrder,
                      let from = order.firstIndex(where: { $0.id == item.id })
                else { return }

                lastIndex = target
                let moved = order.remove(at: from)
                order.insert(moved, at: min(max(target, 0), order.count))

                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    dragOrder = order
                }
            }
            .onEnded { value in

                // Dropped off the bookcase entirely — leave the saved order
                // alone, so it springs back to where it came from.
                if dropIsOnShelf(value.location),
                   let order = dragOrder,
                   let index = order.firstIndex(where: { $0.id == item.id }) {
                    commit(item.id, position: position(for: item.id, at: index, in: order))
                }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    dragging = nil
                    dragOrder = nil
                    dragLayout = nil
                    lastIndex = nil
                }
            }
    }

    /// A position between the item's new neighbours — one write, and nothing
    /// else on the shelf has to be renumbered.
    private func position(for id: String, at index: Int, in order: [ShelfItem]) -> Double {

        let others = order.filter { $0.id != id }
        let target = min(max(index, 0), others.count)

        let before = target > 0 ? others[target - 1].position : nil
        let after = target < others.count ? others[target].position : nil

        switch (before, after) {
        case let (before?, after?): return (before + after) / 2
        case let (before?, nil):    return before + 1_000
        case let (nil, after?):     return after - 1_000
        default:                    return 0
        }
    }

    private func dropIsOnShelf(_ point: CGPoint) -> Bool {

        let height = metrics.topCap + CGFloat(tiers.count) * metrics.pitch

        return point.x >= 0 && point.x <= shelfWidth
            && point.y >= 0 && point.y <= height
    }

    /// Which slot in the running order the finger is currently over.
    ///
    /// Measured against `dragLayout` — the arrangement of everything *except*
    /// the item in hand, worked out once when the drag began and held still
    /// for its duration.
    ///
    /// Reading the live layout here instead created a feedback loop: moving
    /// the item reflowed the rows, which moved the slot under the finger,
    /// which moved the item again. That oscillation is what made a drop jitter
    /// and made the bottom shelf almost impossible to hit.
    private func insertionIndex(at point: CGPoint) -> Int? {

        guard let rows = dragLayout, !rows.isEmpty else { return nil }

        let tier = metrics.tier(forY: point.y, count: rows.count)

        // Where this shelf starts in the overall order. The "New" slot isn't
        // part of it, so it's filtered out of the count.
        var index = rows[..<tier].reduce(0) { $0 + $1.filter(\.isMovable).count }
        var x = metrics.inset

        for entry in rows[tier] where entry.isMovable {
            if point.x < x + entry.width / 2 { break }
            x += entry.width + metrics.spacing
            index += 1
        }

        return index
    }

    private func commit(_ id: String, position: Double) {

        if manager.books.contains(where: { $0.id == id }) {
            manager.setBookPosition(id, to: position)
            return
        }

        var all = manager.resolvedOrnaments
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].position = position
        manager.saveOrnaments(all.sorted { $0.position < $1.position })
    }

    // MARK: Selection

    private func select(_ item: ShelfItem) {
        switch item.kind {
        case .book(let book):              select(book)
        case .ornament(let placement):     select(ornament: placement)
        case .addSlot, .addOrnament:       break
        }
    }

    private func select(_ book: ScrapbookBook) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            selection = .book(book.id)
            draftTilt = book.tilt
            draftSize = book.sizeScale
        }
    }

    private func select(ornament placement: ScrapbookOrnamentPlacement) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            selection = .ornament(placement.id)
            draftOrnamentScale = placement.scale
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

    // MARK: Ornament edits

    private func setKind(_ placement: ScrapbookOrnamentPlacement, to kind: Int) {
        var all = manager.resolvedOrnaments
        guard let index = all.firstIndex(where: { $0.id == placement.id }) else { return }
        all[index].kind = kind
        manager.saveOrnaments(all)
    }

    private func setScale(_ placement: ScrapbookOrnamentPlacement, to scale: Double) {
        var all = manager.resolvedOrnaments
        guard let index = all.firstIndex(where: { $0.id == placement.id }) else { return }
        all[index].scale = scale
        manager.saveOrnaments(all)
    }

    private func remove(_ placement: ScrapbookOrnamentPlacement) {
        let all = manager.resolvedOrnaments.filter { $0.id != placement.id }
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

// MARK: - A book standing up

private struct BookSpine: View {

    let book: ScrapbookBook

    /// The shelf's scale, so a spine is the same share of the bookcase on
    /// every phone rather than a fixed number of points.
    let unit: CGFloat

    let isSelected: Bool
    let isLifted: Bool

    private var width: CGFloat { book.displayThickness * unit }
    private var height: CGFloat { book.displayHeight * unit }

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
            .padding(.vertical, 12 * unit)
            .padding(.horizontal, 5 * unit)

            // Vertical spine text. `rotationEffect` is a render-time
            // transform and does not change the size the view reports to its
            // parent, so the title is sized before it turns and given a narrow
            // footprint again afterwards. Without the second frame every spine
            // claims the width of its own title and the shelf bursts open.
            Text(book.title)
                .font(.system(size: 11 * unit, weight: .bold, design: .serif))
                .foregroundStyle(cover.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.7)
                .frame(width: height - 44 * unit)
                .rotationEffect(.degrees(-90))
                .frame(width: 14 * unit, height: height - 44 * unit)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.stroke(ScrapbookStyle.outline, lineWidth: 2 * unit))
        .overlay {
            if isSelected {
                shape.stroke(ScrapbookStyle.blossom, lineWidth: 3 * unit).padding(-4 * unit)
            }
        }
        // A lifted book stands straight and rides above its neighbours.
        .rotationEffect(.degrees(isLifted ? 0 : book.tilt), anchor: .bottom)
        .scaleEffect(isLifted ? 1.06 : 1, anchor: .bottom)
        .shadow(
            color: ScrapbookStyle.outline.opacity(isLifted ? 0.4 : 0.22),
            radius: isLifted ? 12 : 4,
            x: isLifted ? 0 : 2,
            y: isLifted ? 8 : 2
        )
        // Size and tilt are deliberately unanimated: they now track a slider
        // under the finger, and a spring chasing a continuous value reads as
        // lag rather than polish. Only the lift is animated.
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isLifted)
    }

    private var bandLine: some View {
        Rectangle()
            .fill(cover.title.opacity(0.5))
            .frame(height: 1.5)
    }
}

// MARK: - Empty slot

private struct AddSlot: View {

    let width: CGFloat
    let unit: CGFloat
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {

        Button(action: action) {
            VStack(spacing: 7 * unit) {
                Image(systemName: icon)
                    .font(.system(size: 19 * unit, weight: .bold))
                Text(label)
                    .font(.system(size: 11 * unit, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(ScrapbookStyle.outline.opacity(0.55))
            .frame(width: width, height: 138 * unit)
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

        PanelShell(title: book.title, hint: "Drag it anywhere on the shelves", onClose: onClose) {

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
