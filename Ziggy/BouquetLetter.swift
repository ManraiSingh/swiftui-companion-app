//
//  BouquetLetter.swift
//  Ziggy
//
//  The note that goes in with the flowers, and the envelope it folds into.
//
//  Drawn rather than an emoji: an envelope is the one thing here that has to
//  open, and ✉️ cannot. The flap lifting and the card sliding out is the whole
//  moment — it is what makes reading it feel like being handed something
//  rather than being shown a text field.
//

import SwiftUI

// MARK: - The envelope, closed

struct BouquetEnvelope: View {

    let ribbon: Color

    /// 0 closed, 1 fully open. The showcase drives this while the card slides
    /// out; the builder leaves it shut.
    var open: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in

            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {

                // Body.
                RoundedRectangle(cornerRadius: h * 0.09, style: .continuous)
                    .fill(BouquetPalette.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: h * 0.09, style: .continuous)
                            .stroke(BouquetPalette.edge, lineWidth: max(w * 0.008, 0.7))
                    )

                // The two lower folds, drawn as a soft V so the front of the
                // envelope has some structure rather than being a blank card.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.52))
                    path.addLine(to: CGPoint(x: w, y: h))
                }
                .stroke(BouquetPalette.edge.opacity(0.8),
                        style: StrokeStyle(lineWidth: max(w * 0.007, 0.6), lineJoin: .round))

                // The flap, hinged along the top edge.
                FlapShape()
                    .fill(BouquetPalette.cream)
                    .overlay(
                        FlapShape().stroke(BouquetPalette.edge,
                                           lineWidth: max(w * 0.008, 0.7))
                    )
                    .rotation3DEffect(
                        .degrees(Double(open) * -168),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.5
                    )

                // A wax seal, which lifts away with the flap.
                Circle()
                    .fill(ribbon)
                    .frame(width: w * 0.17, height: w * 0.17)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: w * 0.075, weight: .black))
                            .foregroundStyle(.white.opacity(0.85))
                    )
                    .position(x: w * 0.5, y: h * 0.50)
                    .opacity(1 - Double(open) * 2.2)
            }
        }
    }
}

private struct FlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.height * 0.62),
                          control: CGPoint(x: rect.maxX, y: rect.height * 0.34))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.height * 0.34))
        path.closeSubpath()
        return path
    }
}

// MARK: - The card inside

/// The note itself, on a sheet with a ruled edge and a little heart.
struct BouquetCard: View {

    let text: String
    let fontIndex: Int
    let ribbon: Color

    var body: some View {
        VStack(spacing: 0) {

            // A band across the top, so the sheet reads as stationery rather
            // than a plain rectangle.
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ribbon.opacity(index == 1 ? 1 : 0.45))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 18)

            Text(text.isEmpty ? "…" : text)
                .font(ScrapbookStyle.font(fontIndex, size: 19))
                .foregroundStyle(BouquetPalette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Image(systemName: "heart.fill")
                .font(.system(size: 13))
                .foregroundStyle(ribbon.opacity(0.75))
                .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BouquetPalette.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BouquetPalette.edge, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
    }
}

// MARK: - Writing it

/// Where the note gets written: a sheet you type straight onto, with the
/// fonts underneath.
struct BouquetLetterEditor: View {

    @Binding var letter: BouquetLetter
    let ribbon: Color
    let onDone: () -> Void

    @FocusState private var focused: Bool

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    var body: some View {

        ZStack {

            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDone() }

            VStack(spacing: 14) {

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BouquetPalette.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(BouquetPalette.edge, lineWidth: 1)
                        )

                    VStack(spacing: 10) {

                        HStack(spacing: 5) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(ribbon.opacity(index == 1 ? 1 : 0.45))
                                    .frame(width: 6, height: 6)
                            }
                        }

                        TextField("Write something for her…",
                                  text: $letter.text, axis: .vertical)
                            .font(ScrapbookStyle.font(letter.fontIndex, size: 19))
                            .foregroundStyle(BouquetPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(3...7)
                            .focused($focused)
                            .padding(.horizontal, 22)

                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(ribbon.opacity(0.75))
                    }
                    .padding(.vertical, 18)
                }
                .frame(height: 240)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(ScrapbookStyle.fonts.enumerated()), id: \.offset) { index, choice in
                            Text(choice.label)
                                .font(ScrapbookStyle.font(index, size: 14))
                                .foregroundStyle(letter.fontIndex == index ? .white : accent)
                                .lineLimit(1)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(letter.fontIndex == index
                                                   ? accent
                                                   : Color.white.opacity(0.9))
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        letter.fontIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Button(action: onDone) {
                    Text(letter.isEmpty ? "Skip the note" : "Tuck it in 💌")
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
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.95, blue: 0.92))
            )
            .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
            .padding(.horizontal, 26)
        }
        .onAppear { focused = true }
    }
}
