//
//  PaywallView.swift
//  Ziggy
//
//  Ziggy Forever.
//
//  Opens on the thing the person was just trying to do rather than a generic
//  pitch — "you've filled both of your free books" is an answer to a question
//  they actually asked, where "Upgrade to Pro" is an advert.
//
//  It also says plainly that one subscription covers both of you, because that
//  halves the price in the only way that matters: it becomes about three pounds
//  each rather than six.
//

import SwiftUI

struct PaywallView: View {

    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscription = ZiggySubscription.shared

    @State private var choice: Plan = .yearly
    @State private var appeared = false

    enum Plan: String {
        case monthly, yearly

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly:  return "Yearly"
            }
        }

        var price: String {
            switch self {
            case .monthly: return "$5.99"
            case .yearly:  return "$29.99"
            }
        }

        var per: String {
            switch self {
            case .monthly: return "per month"
            case .yearly:  return "per year"
            }
        }

        /// The yearly plan carries the trial, which is what makes it the one
        /// people take.
        var note: String? {
            switch self {
            case .monthly: return nil
            case .yearly:  return "7 days free, then $2.50 a month"
            }
        }
    }

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.96, blue: 0.94),
            Color(red: 0.96, green: 0.94, blue: 0.97)
        ],
        startPoint: .top, endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {

                VStack(spacing: 0) {

                    close

                    hero

                    perks
                        .padding(.top, 22)

                    plans
                        .padding(.top, 22)

                    buy
                        .padding(.top, 18)

                    smallPrint
                        .padding(.top, 14)
                        .padding(.bottom, 26)
                }
                .padding(.horizontal, 22)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var close: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.85)))
            }
            .buttonStyle(BubblePress())
            Spacer()
        }
        .padding(.top, 10)
    }

    // MARK: Hero

    private var hero: some View {

        VStack(spacing: 12) {

            Image("ziggy_loveeyes")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .scaleEffect(appeared ? 1 : 0.8)

            Text(reason.title)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .multilineTextAlignment(.center)

            Text(reason.line)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .padding(.top, 4)
    }

    // MARK: What you get

    private var perks: some View {

        VStack(spacing: 12) {

            perk("books.vertical.fill", "Unlimited books and pages",
                 "Scrapbook as much as you like")

            perk("photo.stack.fill", "Every instant, kept forever",
                 "Not just the last 30 days")

            perk("square.and.arrow.down.fill", "Save to your photos",
                 "Doodles, instants and bouquets")

            perk("gift.fill", "Unlimited bouquets",
                 "With notes, whenever you want")

            perk("doc.text.fill", "Print the whole book",
                 "A clean PDF of everything you made")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.75))
        )
    }

    private func perk(_ icon: String, _ title: String, _ line: String) -> some View {

        HStack(spacing: 13) {

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.55))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(red: 0.99, green: 0.92, blue: 0.94)))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Plans

    private var plans: some View {

        VStack(spacing: 10) {

            plan(.yearly)
            plan(.monthly)

            // The reason this is worth anything to a couple.
            HStack(spacing: 7) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.55))
                Text("One subscription unlocks it for both of you")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func plan(_ option: Plan) -> some View {

        let on = choice == option

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { choice = option }
        } label: {

            HStack(spacing: 12) {

                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(on ? Color(red: 0.95, green: 0.45, blue: 0.55) : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                    if let note = option.note {
                        Text(note)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.55))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(option.price)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                    Text(option.per)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(on ? 1 : 0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(on ? Color(red: 0.95, green: 0.45, blue: 0.55) : .clear,
                                    lineWidth: 2)
                    )
            )
        }
        .buttonStyle(BubblePress())
    }

    // MARK: Buying

    private var buy: some View {

        VStack(spacing: 10) {

            Button {
                // Wired to RevenueCat once the SDK is linked.
            } label: {
                HStack(spacing: 8) {
                    if subscription.isPurchasing {
                        ProgressView().tint(.white)
                    }
                    Text(choice == .yearly ? "Start 7 days free" : "Subscribe")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(BubblePress())
            .disabled(subscription.isPurchasing)

            if let error = subscription.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            Button {
                // Restore, wired with the SDK.
            } label: {
                Text("Restore purchases")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    /// Apple requires the terms and the privacy policy to be reachable from
    /// the paywall itself, and rejects submissions where they are not.
    private var smallPrint: some View {

        VStack(spacing: 8) {

            Text(choice == .yearly
                 ? "7 days free, then $29.99 a year. Renews until cancelled."
                 : "$5.99 a month. Renews until cancelled.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("Terms of Use",
                     destination: URL(string: "https://manraisingh.github.io/swiftui-companion-app/terms.html")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://manraisingh.github.io/swiftui-companion-app/")!)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Reaching the paywall

extension View {

    /// Shows the paywall when `reason` is set.
    func paywall(_ reason: Binding<PaywallReason?>) -> some View {
        sheet(item: reason) { PaywallView(reason: $0) }
    }
}

extension PaywallReason: Identifiable {
    var id: String { title }
}
