//
//  OnboardingView.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import SwiftUI

struct OnboardingView: View {

    @State private var name = ""
    @State private var bounce = false

    @AppStorage("ziggy_username")
    private var username = ""

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            // soft floating hearts
            FloatingHearts()
                .opacity(0.5)

            VStack(spacing: 26) {

                Spacer()

                ZStack {

                    Circle()
                        .fill(Color.pink.opacity(0.14))
                        .frame(width: 230, height: 230)

                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 190, height: 190)

                    Image("ziggy_happie")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .offset(y: bounce ? -8 : 4)
                        .animation(
                            .easeInOut(duration: 1.4)
                                .repeatForever(autoreverses: true),
                            value: bounce
                        )
                }

                VStack(spacing: 8) {

                    Text("Hi, I'm Ziggy 💕")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(accent)

                    Text("Your little love companion 🐾\nWhat should I call you?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {

                    HStack(spacing: 10) {

                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink.opacity(0.7))

                        TextField("Enter your name", text: $name)
                            .submitLabel(.done)
                    }
                    .padding(16)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.pink.opacity(0.18), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 7, y: 3)

                    Button {
                        username = name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    } label: {

                        Text("Let's go 💫")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canContinue ? accent : accent.opacity(0.35))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(
                                color: .black.opacity(canContinue ? 0.15 : 0),
                                radius: 8,
                                y: 4
                            )
                    }
                    .disabled(!canContinue)
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
        .onAppear { bounce = true }
    }
}

// MARK: - Floating Hearts decoration

struct FloatingHearts: View {

    @State private var animate = false

    private let hearts: [(x: CGFloat, size: CGFloat, delay: Double)] = [
        (0.12, 18, 0.0),
        (0.85, 24, 0.6),
        (0.22, 14, 1.1),
        (0.78, 16, 1.6),
        (0.5, 20, 0.3),
        (0.92, 12, 2.0),
        (0.06, 16, 1.4)
    ]

    var body: some View {

        GeometryReader { geo in

            ZStack {

                ForEach(0..<hearts.count, id: \.self) { i in

                    let h = hearts[i]

                    Image(systemName: "heart.fill")
                        .font(.system(size: h.size))
                        .foregroundColor(.pink.opacity(0.35))
                        .position(
                            x: geo.size.width * h.x,
                            y: animate ? -40 : geo.size.height + 40
                        )
                        .animation(
                            .easeInOut(duration: 7)
                                .repeatForever(autoreverses: false)
                                .delay(h.delay),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
    }
}

#Preview {
    OnboardingView()
}
