//
//  ScrapbookBookView.swift
//  Ziggy
//
//  Opening a book. It lifts off the shelf rather than replacing the screen —
//  the bookcase stays visible and blurred behind it, so it reads as picking
//  a book up rather than navigating away.
//

import SwiftUI

private struct SpreadWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ScrapbookBookView: View {

    let book: ScrapbookBook
    let onClose: () -> Void

    @StateObject private var manager = ScrapbookManager.shared

    @State private var opened = false
    @State private var pageIndex = 0
    @State private var editingPage: ScrapbookPage?
    @State private var showingPaper = false

    /// How far through a page turn we are: 0 settled, +1 a leaf fully turned
    /// forward, -1 fully turned back. Driven by the finger, so the page hangs
    /// wherever you let it.
    @State private var turnAmount: CGFloat = 0
    @State private var spreadWidth: CGFloat = 1

    /// The finished PDF, waiting to be handed on.
    @State private var exportedPDF: ScrapbookExportFile?
    @State private var exporting = false
    @State private var askingExport = false
    @State private var paywall: PaywallReason?

    private var cover: ScrapbookStyle.Cover { ScrapbookStyle.cover(book.coverIndex) }

    private var currentPage: ScrapbookPage? {
        guard manager.pages.indices.contains(pageIndex) else { return manager.pages.first }
        return manager.pages[pageIndex]
    }

    var body: some View {

        ZStack {

            // The shelf stays visible underneath.
            ScrapbookStyle.outline.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { if opened { onClose() } }

            VStack(spacing: 0) {

                topBar
                    .opacity(opened ? 1 : 0)

                Spacer(minLength: 0)

                bookPlate

                Spacer(minLength: 0)

                bottomBar
                    .opacity(opened ? 1 : 0)
            }
        }
        .onAppear {
            manager.startPages(bookID: book.id)
            loadVisiblePages()

            // A beat before it opens, so the closed cover is actually seen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    opened = true
                }
            }
        }
        .onDisappear {
            manager.stopWatching()
            manager.stopPages()
        }
        .onChange(of: manager.pages.count) { _, _ in
            pageIndex = clampedIndex(pageIndex)
            loadVisiblePages()
        }
        .onChange(of: pageIndex) { _, _ in loadVisiblePages() }
        .fullScreenCover(item: $editingPage) { page in
            ScrapbookCanvasView(book: book, page: page)
        }
        .sheet(item: $exportedPDF) { file in
            ScrapbookShareSheet(url: file.url)
        }
        .paywall($paywall)
        // Said before the export rather than discovered inside the file, so
        // nobody sends one page to their mother thinking it was the book.
        .confirmationDialog(
            "Free exports are a single page",
            isPresented: $askingExport,
            titleVisibility: .visible
        ) {
            Button("Export this page") { runExport(whole: false) }
            // Same reason as the locked stickers: the dialog is still going
            // away, and a sheet asked for over one that is dismissing is
            // dropped.
            Button("See Ziggy Forever") {
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    paywall = .wholeBook
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll get the page you're looking at, with a small Ziggy line at the foot. Ziggy Forever prints the whole book, clean.")
        }
        .sheet(isPresented: $showingPaper) {
            PaperPicker(selected: currentPage?.paperIndex ?? 0) { index in
                if let page = currentPage {
                    manager.setPaper(bookID: book.id, pageID: page.id, paperIndex: index)
                }
            }
            .presentationDetents([.large])
        }
    }

    // MARK: The book

    /// The open book: a coloured cover with the page sitting on it, and the
    /// edges of the other pages showing underneath.
    private var bookPlate: some View {

        ZStack {

            pageStack
                .opacity(opened ? 1 : 0)
                .scaleEffect(opened ? 1 : 0.86)

            closedCover
                .opacity(opened ? 0 : 1)
        }
        // Enough margin that the bookcase still shows around it — the book
        // should read as lifted off the shelf, not as a new screen. A spread
        // is landscape, so it needs the width more than a single page did.
        .padding(.horizontal, 14)
    }

    private var pageStack: some View {

        ZStack(alignment: .bottom) {

            // Page edges peeking out below the top sheet.
            ForEach(1...3, id: \.self) { depth in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(depth == 1 ? ScrapbookStyle.paperWhite : ScrapbookStyle.cream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ScrapbookStyle.outline.opacity(0.35), lineWidth: 1.5)
                    )
                    .padding(.horizontal, CGFloat(4 - depth) * 3)
                    .offset(y: CGFloat(depth) * 5)
            }

            spread
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(cover.front)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(ScrapbookStyle.outline, lineWidth: 2)
                        )
                )
                .shadow(color: ScrapbookStyle.outline.opacity(0.4), radius: 20, y: 10)
        }
        // Two pages side by side, so the aspect is twice a single page's.
        .aspectRatio(0.74 * 2, contentMode: .fit)
        // The page follows the finger rather than waiting for the swipe to
        // finish, so a half-hearted drag shows a half-lifted page and falls
        // back — which is what makes it feel like paper.
        .gesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in

                    guard abs(value.translation.width) > abs(value.translation.height) else { return }

                    let pull = -value.translation.width / (spreadWidth / 2)

                    turnAmount = pull > 0
                        ? (canTurnOn ? min(pull, 1) : 0)
                        : (canTurnBack ? max(pull, -1) : 0)
                }
                .onEnded { value in

                    guard turnAmount != 0 else { return }

                    // Past a third of the way, or thrown hard enough, it goes
                    // over; otherwise it drops back.
                    let thrown = abs(value.predictedEndTranslation.width) > spreadWidth / 3

                    if turnProgress > 0.34 || thrown {
                        complete(forward: turnAmount > 0)
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            turnAmount = 0
                        }
                    }
                }
        )
    }

    /// The open spread, with a leaf that turns about the spine.
    ///
    /// A page turn is one sheet pivoting on the gutter: its front is the page
    /// you were reading, its back is the next one. So the turning leaf swaps
    /// which page it draws as it passes upright, and mirrors it — you are
    /// looking at the other side of the same sheet.
    ///
    /// The leaf is drawn *over* both halves rather than inside one of them.
    /// It used to live in the half it started from, which was fine going
    /// forward — the half it sweeps onto is drawn earlier, so the leaf
    /// covered it — but backwards it swept onto the half drawn *after* it and
    /// was painted straight over. The page simply disappeared halfway through
    /// the turn.
    private var spread: some View {

        GeometryReader { proxy in

            let half = (proxy.size.width - Self.gutter) / 2

            ZStack {

                // What sits under the turn: the page that stays put, and the
                // one being revealed.
                HStack(spacing: 0) {
                    leaf(at: baseLeftIndex)
                        .frame(width: half)
                        .allowsHitTesting(turnAmount == 0)

                    gutterView

                    leaf(at: baseRightIndex)
                        .frame(width: half)
                        .allowsHitTesting(turnAmount == 0)
                }

                if turnAmount != 0 {
                    turningLeaf(half: half, in: proxy.size)
                }
            }
            .preference(key: SpreadWidthKey.self, value: proxy.size.width)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onPreferenceChange(SpreadWidthKey.self) { spreadWidth = max($0, 1) }
    }

    /// Keeps the open spread loaded, plus the spread either side of it.
    ///
    /// A turn shows four pages at once — the two you are leaving and the two
    /// arriving — so loading only the current pair would mean the page you
    /// turn onto arrives blank and fills in a moment later.
    private func loadVisiblePages() {

        let window = (leftIndex - 2)...(rightIndex + 2)

        let ids = window
            .filter { manager.pages.indices.contains($0) }
            .map { manager.pages[$0].id }

        manager.watch(pages: ids, bookID: book.id)
    }

    private static let gutter: CGFloat = 10

    /// The gutter, so the two halves read as one bound book.
    private var gutterView: some View {
        LinearGradient(
            colors: [
                ScrapbookStyle.outline.opacity(0.28),
                ScrapbookStyle.outline.opacity(0.06),
                ScrapbookStyle.outline.opacity(0.28)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: Self.gutter)
    }

    /// How far round the turn is, 0 to 1.
    private var turnProgress: CGFloat { min(abs(turnAmount), 1) }

    private var goingOn: Bool { turnAmount > 0 }

    /// The page beneath the turn on each side.
    private var baseLeftIndex: Int { turnAmount < 0 ? leftIndex - 2 : leftIndex }
    private var baseRightIndex: Int { turnAmount > 0 ? rightIndex + 2 : rightIndex }

    /// The sheet in motion, laid over whichever half it started from.
    private func turningLeaf(half: CGFloat, in size: CGSize) -> some View {

        // Past halfway you are seeing the back of the sheet, so it draws the
        // page on the other side — mirrored, because a page seen from behind
        // is reversed.
        let showingBack = turnProgress > 0.5

        let face: Int = goingOn
            ? (showingBack ? leftIndex + 2 : rightIndex)
            : (showingBack ? rightIndex - 2 : leftIndex)

        return leaf(at: face)
            .frame(width: half, height: size.height)
            .scaleEffect(x: showingBack ? -1 : 1, y: 1)
            .overlay(
                // The sheet catches less light as it lifts, which is most of
                // what sells the fold.
                Color.black.opacity(Double(turnProgress) * 0.22)
            )
            .rotation3DEffect(
                .degrees((goingOn ? -180 : 180) * Double(turnProgress)),
                axis: (x: 0, y: 1, z: 0),
                anchor: goingOn ? .leading : .trailing,
                perspective: 0.42
            )
            .shadow(
                color: .black.opacity(Double(turnProgress) * 0.35),
                radius: 12,
                x: goingOn ? -8 : 8
            )
            // Sat over the half it lifts from, so it can sweep across the
            // spine and land on the other one.
            .position(
                x: goingOn ? size.width - half / 2 : half / 2,
                y: size.height / 2
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func leaf(at index: Int) -> some View {

        if manager.pages.indices.contains(index) {

            let page = manager.pages[index]

            ScrapbookPagePreview(
                page: page,
                elements: manager.pageElements[page.id] ?? []
            )
            .contentShape(Rectangle())
            .onTapGesture {
                // Editing works on one page at a time, so tapping a leaf
                // makes it the live one before opening the canvas.
                pageIndex = index
                editingPage = page
            }

        } else if index == manager.pages.count && !manager.pages.isEmpty {
            addLeaf
        } else {
            ScrapbookStyle.paperWhite
        }
    }

    private var addLeaf: some View {

        ZStack {

            // Opaque paper. A translucent fill here let the cover colour
            // through and the leaf stopped reading as a page.
            ScrapbookStyle.paperWhite
            ScrapbookStyle.cream.opacity(0.4)

            VStack(spacing: 10) {

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))

                Text("New page")
                    .font(.system(size: 15, weight: .bold, design: .serif))

                Text("Add to this book")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .opacity(0.75)
            }
            .foregroundStyle(ScrapbookStyle.outline.opacity(0.55))
            .padding(.horizontal, 12)
            .multilineTextAlignment(.center)
        }
        .contentShape(Rectangle())
        .onTapGesture {

            // The new page will land at the end, so its slot is the count as
            // it stands now. Claiming it up front means the turn happens
            // straight away and the page fills it when the listener catches
            // up — reading the count inside the completion instead gave the
            // old value, because the write finishing is not the same moment
            // the page arrives.
            let landing = manager.pages.count

            guard ZiggySubscription.shared.canAddPage(existing: landing) else {
                paywall = .pages
                return
            }

            manager.addPage(bookID: book.id) { _ in }
            ZiggyAnalytics.pageAdded(inBookWith: landing + 1)

            withAnimation(.easeInOut(duration: 0.3)) {
                pageIndex = landing
            }
        }
    }

    /// The spread always starts on an even leaf, so turning a page moves both
    /// sides together the way a real book does.
    private var leftIndex: Int { (pageIndex / 2) * 2 }
    private var rightIndex: Int { leftIndex + 1 }

    private var closedCover: some View {

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(cover.front)
            .overlay(
                VStack(spacing: 10) {
                    Rectangle()
                        .fill(cover.title.opacity(0.55))
                        .frame(width: 88, height: 1.5)

                    Text(book.title)
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundStyle(cover.title)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    Rectangle()
                        .fill(cover.title.opacity(0.55))
                        .frame(width: 88, height: 1.5)
                }
                .padding(.horizontal, 24)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(cover.spine)
                    .frame(width: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ScrapbookStyle.outline, lineWidth: 2)
            )
            .shadow(color: ScrapbookStyle.outline.opacity(0.45), radius: 18, y: 10)
            .frame(width: 208, height: 268)
            // Swings back on its hinge as the pages come forward.
            .rotation3DEffect(
                .degrees(opened ? -96 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.5
            )
    }

    // MARK: Chrome

    private var topBar: some View {

        HStack {

            circleButton("chevron.down", action: onClose)

            Spacer()

            Text(book.title)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundStyle(ScrapbookStyle.paperWhite)
                .lineLimit(1)

            Spacer()

            if exporting {
                ProgressView()
                    .tint(ScrapbookStyle.paperWhite)
                    .frame(width: 38, height: 38)
            } else {
                circleButton("square.and.arrow.up") { exportPDF() }
            }

            circleButton("doc.plaintext") { showingPaper = true }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {

        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ScrapbookStyle.outline)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(ScrapbookStyle.paperWhite)
                        .overlay(Circle().stroke(ScrapbookStyle.outline, lineWidth: 2))
                )
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {

        HStack(spacing: 12) {

            turnButton("chevron.left", enabled: canTurnBack) { turn(-1) }

            Text(spreadLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ScrapbookStyle.paperWhite.opacity(0.9))
                .frame(minWidth: 92)

            turnButton("chevron.right", enabled: canTurnOn) { turn(1) }

            Spacer()

            pillButton("Edit", icon: "pencil", filled: true) {
                if let page = currentPage { editingPage = page }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    /// Renders every page of the book to a PDF and offers it up.
    ///
    /// The elements are fetched afresh rather than taken from what's on screen:
    /// the book only keeps the spread you can see and its neighbours loaded, so
    /// printing from that would give a document with most of its pages blank.
    private func exportPDF() {

        guard !exporting, !manager.pages.isEmpty else { return }

        if ZiggySubscription.shared.canExportWholeBook {
            runExport(whole: true)
        } else {
            askingExport = true
        }
    }

    /// A free export is the open page alone, with a line at the foot. It is
    /// meant to be worth sending on — a page somebody forwards is an advert,
    /// where a page ruined by a stamp across the middle is just a lost reader.
    private func runExport(whole: Bool) {

        guard !exporting, !manager.pages.isEmpty else { return }

        exporting = true

        // `clampedIndex` allows one past the end — that slot is the "add a
        // page" leaf, not a page, so it must not be reached for here.
        let open = min(max(pageIndex, 0), manager.pages.count - 1)

        let pages: [ScrapbookPage] = whole ? manager.pages : [manager.pages[open]]

        manager.fetchEveryPage(bookID: book.id, pageIDs: pages.map(\.id)) { elements in

            // Blank pages are left out of a printed book.
            //
            // A book usually ends on one — you turn to the end, a fresh page
            // is waiting, and it gets added the moment you look at it. That is
            // right in the app and pointless on paper, where it prints as a
            // sheet with nothing on it.
            //
            // Only when printing the whole book. Asking for the one page you
            // are looking at and being handed nothing would be worse than
            // being handed a blank.
            let printable = whole
                ? pages.filter { !(elements[$0.id] ?? []).isEmpty }
                : pages

            let url = ScrapbookPDF.write(
                book: book,
                pages: printable.isEmpty ? pages : printable,
                elements: elements,
                watermark: !whole
            )

            exporting = false
            if let url { exportedPDF = ScrapbookExportFile(url: url) }
        }
    }

    private var spreadLabel: String {

        let total = max(manager.pages.count, 1)
        guard manager.pages.count > 1 else { return "Page 1 of \(total)" }

        return "Pages \(leftIndex + 1)–\(min(rightIndex + 1, total)) of \(total)"
    }

    private var canTurnOn: Bool { rightIndex < manager.pages.count }
    private var canTurnBack: Bool { leftIndex > 0 }

    /// Keeps a page index inside the book, counting the spread that holds the
    /// "new page" invitation as a real place to be.
    ///
    /// This used to clamp to `pages.count - 1`, one short of that spread. In a
    /// two-page book, turning on from the first spread aimed at index 2, got
    /// pulled back to 1, and `leftIndex` collapsed to 0 — so you landed on
    /// what looked like the new page but was really the first spread again,
    /// with nothing behind it to turn back to.
    private func clampedIndex(_ index: Int) -> Int {
        min(max(index, 0), manager.pages.count)
    }

    /// Turns a whole spread at a time, and lands on the left leaf so the
    /// "new page" invitation stays on the right where it belongs.
    private func turn(_ direction: Int) {
        guard direction > 0 ? canTurnOn : canTurnBack else { return }
        turnAmount = direction > 0 ? 0.001 : -0.001
        complete(forward: direction > 0)
    }

    /// Carries the leaf the rest of the way over, then swaps the spread
    /// underneath it.
    ///
    /// The swap is made in a transaction with animation off: the leaf has
    /// already landed showing the new page, so animating the change again
    /// would show it a second time.
    private func complete(forward: Bool) {

        withAnimation(.easeOut(duration: 0.34)) {
            turnAmount = forward ? 1 : -1
        }

        let target = leftIndex + (forward ? 2 : -2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                pageIndex = clampedIndex(target)
                turnAmount = 0
            }
        }
    }

    private func turnButton(
        _ icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ScrapbookStyle.paperWhite.opacity(enabled ? 0.95 : 0.3))
                .frame(width: 36, height: 34)
                .background(
                    Capsule()
                        .fill(.white.opacity(enabled ? 0.16 : 0.06))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func pillButton(
        _ label: String,
        icon: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(filled ? ScrapbookStyle.outline : ScrapbookStyle.paperWhite)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(filled ? ScrapbookStyle.paperWhite : .white.opacity(0.16))
                        .overlay(
                            Capsule().stroke(
                                filled ? ScrapbookStyle.outline : .white.opacity(0.5),
                                lineWidth: filled ? 2 : 1.5
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paper picker

private struct PaperPicker: View {

    let selected: Int
    let onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var choice: Int

    init(selected: Int, onPick: @escaping (Int) -> Void) {
        self.selected = selected
        self.onPick = onPick
        _choice = State(initialValue: selected)
    }

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
                                                  lineWidth: choice == index ? 3 : 0.5)
                            )
                        Text(paper.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .onTapGesture {
                        choice = index
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
