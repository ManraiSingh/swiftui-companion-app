//
//  ScrapbookBookView.swift
//  Ziggy
//
//  Opening a book. It lifts off the shelf rather than replacing the screen —
//  the bookcase stays visible and blurred behind it, so it reads as picking
//  a book up rather than navigating away.
//

import SwiftUI

struct ScrapbookBookView: View {

    let book: ScrapbookBook
    let onClose: () -> Void

    @StateObject private var manager = ScrapbookManager.shared

    @State private var opened = false
    @State private var pageIndex = 0
    @State private var editingPage: ScrapbookPage?
    @State private var showingPaper = false

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

            // A beat before it opens, so the closed cover is actually seen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    opened = true
                }
            }
        }
        .onDisappear {
            manager.stopElements()
            manager.stopPages()
        }
        .onChange(of: manager.pages.count) { _, count in
            if count > 0, manager.elements.isEmpty, let page = currentPage {
                manager.startElements(bookID: book.id, pageID: page.id)
            }
            pageIndex = min(pageIndex, max(count - 1, 0))
        }
        .onChange(of: pageIndex) { _, index in
            guard manager.pages.indices.contains(index) else { return }
            manager.startElements(bookID: book.id, pageID: manager.pages[index].id)
        }
        .fullScreenCover(item: $editingPage) { page in
            ScrapbookCanvasView(book: book, page: page)
        }
        .sheet(isPresented: $showingPaper) {
            PaperPicker(selected: currentPage?.paperIndex ?? 0) { index in
                if let page = currentPage {
                    manager.setPaper(bookID: book.id, pageID: page.id, paperIndex: index)
                }
            }
            .presentationDetents([.height(300)])
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
        // Swiping across the spread turns it, the way the paged TabView used
        // to before the book had two leaves to keep in step.
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    turn(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    /// The open spread: the left page is whatever exists there, the right is
    /// the next page or the invitation to start one.
    private var spread: some View {

        HStack(spacing: 0) {

            leaf(at: leftIndex)

            // The gutter, so the two halves read as one bound book.
            LinearGradient(
                colors: [
                    ScrapbookStyle.outline.opacity(0.28),
                    ScrapbookStyle.outline.opacity(0.06),
                    ScrapbookStyle.outline.opacity(0.28)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 10)

            leaf(at: rightIndex)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func leaf(at index: Int) -> some View {

        if manager.pages.indices.contains(index) {

            let page = manager.pages[index]

            ScrapbookPagePreview(
                page: page,
                elements: index == pageIndex ? manager.elements : []
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
            manager.addPage(bookID: book.id) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    pageIndex = max(manager.pages.count - 1, 0)
                }
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

            turnButton("chevron.left", enabled: leftIndex > 0) { turn(-1) }

            Text(spreadLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ScrapbookStyle.paperWhite.opacity(0.9))
                .frame(minWidth: 92)

            turnButton("chevron.right", enabled: rightIndex < manager.pages.count) { turn(1) }

            Spacer()

            pillButton("Edit", icon: "pencil", filled: true) {
                if let page = currentPage { editingPage = page }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    private var spreadLabel: String {

        let total = max(manager.pages.count, 1)
        guard manager.pages.count > 1 else { return "Page 1 of \(total)" }

        return "Pages \(leftIndex + 1)–\(min(rightIndex + 1, total)) of \(total)"
    }

    /// Turns a whole spread at a time, and lands on the left leaf so the
    /// "new page" invitation stays on the right where it belongs.
    private func turn(_ direction: Int) {

        let target = leftIndex + direction * 2
        guard target >= 0, target <= manager.pages.count else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            pageIndex = min(target, max(manager.pages.count - 1, 0))
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
