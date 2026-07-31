//
//  WidgetOnboardingView.swift
//  Ziggy
//
//  iOS gives apps no API to add a widget to the Home Screen automatically —
//  only the user can do that. This walks them through it by hand, once,
//  right after pairing.
//

import SwiftUI

struct WidgetOnboardingView: View {

    let onDone: () -> Void

    @State private var step = 0

    private let steps: [WidgetOnboardingStep] = [
        WidgetOnboardingStep(
            symbol: "hand.tap.fill",
            title: "Long-press your Home Screen",
            detail: "Touch and hold any empty space until your apps start to jiggle."
        ),
        WidgetOnboardingStep(
            symbol: "plus.circle.fill",
            title: "Tap the + in the corner",
            detail: "It's near the top of the screen, usually top-left."
        ),
        WidgetOnboardingStep(
            symbol: "magnifyingglass",
            title: "Search for Ziggy",
            detail: "Pick a widget size, then tap \"Add Widget.\""
        ),
        WidgetOnboardingStep(
            symbol: "heart.fill",
            title: "That's it! 💞",
            detail: "Your partner's latest doodle, message, or mood now lives right on your Home Screen."
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.88),
                    Color(red: 0.91, green: 0.97, blue: 0.94),
                    Color(red: 0.94, green: 0.92, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button("Maybe later") { onDone() }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Text("Add Ziggy to your Home Screen")
                    .font(.title2)
                    .fontWeight(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // A fixed height here, rather than letting the page stretch
                // to fill the VStack, sidesteps a real TabView(.page) quirk
                // where a flexible-height page's content doesn't reliably
                // center. A single flexible spacer below (not one on each
                // side) keeps this top-anchored and predictable instead of
                // fighting that quirk for a perfect center.
                TabView(selection: $step) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                        stepCard(item, number: index + 1)
                            .tag(index)
                            .padding(.horizontal, 28)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 430)
                .padding(.top, 20)

                Spacer(minLength: 0)

                Button {
                    if step < steps.count - 1 {
                        withAnimation { step += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(step < steps.count - 1 ? "Next" : "Got it, thanks!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
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
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private func stepCard(_ item: WidgetOnboardingStep, number: Int) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.14))
                    .frame(width: 132, height: 132)

                Image(systemName: item.symbol)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 12)

            Text("Step \(number)")
                .font(.caption)
                .fontWeight(.black)
                .foregroundStyle(.pink)
                .textCase(.uppercase)

            Text(item.title)
                .font(.title3)
                .fontWeight(.black)
                .multilineTextAlignment(.center)

            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.top, 8)
    }
}

private struct WidgetOnboardingStep {
    let symbol: String
    let title: String
    let detail: String
}

#Preview {
    WidgetOnboardingView(onDone: {})
}
