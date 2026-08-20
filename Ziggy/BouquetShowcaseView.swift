//
//  BouquetShowcaseView.swift
//  Ziggy
//
//  Where a bouquet is looked at properly.
//
//  Reached from the popup when one arrives, and again from the activity page
//  whenever she wants to see it. The flowers rise in as it opens and the
//  envelope waits to be tapped, because a gift that is simply *displayed* is
//  a picture — one that unfolds is a gift.
//

import SwiftUI

struct BouquetShowcaseView: View {

    let bouquet: Bouquet

    @Environment(\.dismiss) private var dismiss

    @State private var risen = false
    @State private var openLetter = false
    @State private var flap: CGFloat = 0
    @State private var toast = ""

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.96, green: 0.93, blue: 0.90)
        ],
        startPoint: .top, endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var ribbon: Color { Color(scrapbookHex: bouquet.ribbonHex) }
    private var isMine: Bool { FirestoreManager.shared.isMine(bouquet) }

    private var from: String {
        bouquet.sender.isEmpty ? "your partner" : bouquet.sender
    }

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                Spacer(minLength: 0)

                BouquetView(bouquet: bouquet)
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .scaleEffect(risen ? 1 : 0.82)
                    .opacity(risen ? 1 : 0)
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                caption

                if !bouquet.letter.isEmpty {
                    tapHint
                }

                Spacer(minLength: 0)

                actions
            }

            if openLetter {
                letterOverlay.zIndex(10)
            }

            if !toast.isEmpty {
                Text(toast)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.black.opacity(0.75)))
                    .padding(.bottom, 120)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .zIndex(20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.72).delay(0.08)) {
                risen = true
            }
        }
    }

    private var header: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.9)))
            }
            .buttonStyle(BubblePress())

            Spacer()

            Text(bouquet.sentAt, format: .dateTime.day().month(.wide).year())
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var caption: some View {

        VStack(spacing: 4) {

            Text(isMine ? "You sent these" : "From \(from)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(accent)

            Text("\(bouquet.stems.count) stems, wrapped in \(bouquet.wrap.name.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var tapHint: some View {

        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { openLetter = true }
            withAnimation(.easeInOut(duration: 0.55).delay(0.12)) { flap = 1 }
        } label: {
            HStack(spacing: 8) {
                BouquetEnvelope(ribbon: ribbon)
                    .frame(width: 34, height: 25)
                Text("There's a note — open it")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Capsule().fill(.white.opacity(0.9)))
        }
        .buttonStyle(BubblePress())
        .padding(.top, 14)
    }

    private var actions: some View {

        HStack(spacing: 10) {

            Button { save() } label: {
                actionLabel("Save", "square.and.arrow.down")
            }
            .buttonStyle(BubblePress())

            Button { dismiss() } label: {
                Text("Close")
                    .font(.subheadline).fontWeight(.black)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(BubblePress())
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .padding(.top, 10)
    }

    private func actionLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).fontWeight(.bold)
        }
        .font(.subheadline)
        .foregroundStyle(accent)
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Capsule().fill(.white.opacity(0.9)))
    }

    // MARK: The note

    private var letterOverlay: some View {

        ZStack {

            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { closeLetter() }

            VStack(spacing: 18) {

                // The envelope opens, then the card rises out of it.
                ZStack {
                    BouquetEnvelope(ribbon: ribbon, open: flap)
                        .frame(width: 150, height: 108)
                        .opacity(flap > 0.85 ? 0 : 1)
                }
                .frame(height: flap > 0.85 ? 0 : 108)

                BouquetCard(
                    text: bouquet.letter.text,
                    fontIndex: bouquet.letter.fontIndex,
                    ribbon: ribbon
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 210)
                .scaleEffect(flap > 0.85 ? 1 : 0.4)
                .opacity(flap > 0.85 ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.74), value: flap)

                Button { closeLetter() } label: {
                    Text("Close")
                        .font(.subheadline).fontWeight(.black)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white.opacity(0.92)))
                }
                .buttonStyle(BubblePress())
                .opacity(flap > 0.85 ? 1 : 0)
            }
            .padding(.horizontal, 34)
            .transition(.opacity)
        }
    }

    private func closeLetter() {
        withAnimation(.easeInOut(duration: 0.25)) { flap = 0 }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.85).delay(0.1)) {
            openLetter = false
        }
    }

    // MARK: Keeping it

    private func save() {

        let renderer = ImageRenderer(
            content: BouquetView(bouquet: bouquet)
                .frame(width: 900, height: 1100)
                .background(BouquetPalette.paper)
        )
        renderer.scale = 2

        guard let image = renderer.uiImage else {
            flash("Could not save, try again")
            return
        }

        ZiggyPhotoSaver.save(image) { outcome in
            switch outcome {
            case .saved:  flash("Saved to Photos 💐")
            case .denied: flash("Allow photo access in Settings")
            case .failed: flash("Could not save, try again")
            }
        }
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = "" }
        }
    }
}

// MARK: - Arrival

/// The popup that appears when one lands.
struct BouquetArrivalPopup: View {

    let bouquet: Bouquet
    let onOpen: () -> Void
    let onClose: () -> Void

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var from: String {
        bouquet.sender.isEmpty ? "Your partner" : bouquet.sender
    }

    var body: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 14) {

                BouquetView(bouquet: bouquet)
                    .frame(width: 168, height: 206)

                VStack(spacing: 3) {
                    Text("\(from) left you flowers")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)

                    if !bouquet.letter.isEmpty {
                        Text("with a note tucked in 💌")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: onOpen) {
                    Text("Open them")
                        .font(.subheadline).fontWeight(.black)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(BubblePress())

                Button(action: onClose) {
                    Text("Later")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.96, blue: 0.93))
            )
            .shadow(color: .black.opacity(0.22), radius: 26, y: 12)
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}
