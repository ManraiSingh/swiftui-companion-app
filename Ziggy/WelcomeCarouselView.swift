//
//  WelcomeCarouselView.swift
//  Ziggy
//
//  A cute 3-slide intro shown once on first launch, before onboarding.
//  Sets expectations for the couple/pairing concept.
//

import SwiftUI

struct WelcomeCarouselView: View {

    let onDone: () -> Void

    @State private var index = 0
    @State private var bounce = false

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private struct Slide {
        let image: String
        let title: String
        let subtitle: String
        let glow: Color
    }

    private let slides: [Slide] = [
        Slide(
            image: "ziggy_happie",
            title: "Meet Ziggy 🐶",
            subtitle: "A little pet you and your partner raise together — one Ziggy, two hearts.",
            glow: .orange
        ),
        Slide(
            image: "ziggy_loveeyes",
            title: "Just the two of you 💞",
            subtitle: "One of you makes a love code, the other enters it. That's all it takes to connect.",
            glow: .pink
        ),
        Slide(
            image: "ziggy_happie",
            title: "Stay close, always ✨",
            subtitle: "Send photos, sweet notes and play games — everything syncs live between your phones.",
            glow: .mint
        )
    ]

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()
            FloatingHearts().opacity(0.5)

            VStack(spacing: 0) {

                // Skip
                HStack {
                    Spacer()
                    Button {
                        onDone()
                    } label: {
                        Text("Skip")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.white.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Slides
                TabView(selection: $index) {
                    ForEach(slides.indices, id: \.self) { i in
                        slideView(slides[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Dots
                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? accent : accent.opacity(0.25))
                            .frame(width: i == index ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: index)
                    }
                }
                .padding(.bottom, 18)

                // Button
                Button {
                    if index < slides.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            index += 1
                        }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(index < slides.count - 1 ? "Next" : "Let's go 💫")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .onAppear { bounce = true }
    }

    private func slideView(_ slide: Slide) -> some View {

        VStack(spacing: 26) {

            Spacer()

            ZStack {
                Circle()
                    .fill(slide.glow.opacity(0.16))
                    .frame(width: 240, height: 240)
                Circle()
                    .fill(slide.glow.opacity(0.10))
                    .frame(width: 195, height: 195)

                Image(slide.image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 190)
                    .offset(y: bounce ? -8 : 4)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: bounce
                    )
            }

            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(accent)
                    .multilineTextAlignment(.center)

                Text(slide.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
        }
    }
}

#Preview {
    WelcomeCarouselView(onDone: {})
}
