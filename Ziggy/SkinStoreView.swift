//
//  SkinStoreView.swift
//  Ziggy
//
//  The wardrobe.
//
//  Every card is the real thing — the same renderer the home card uses, with
//  the real accessory on the real Ziggy — rather than a separate icon of a
//  hat. Picking from pictures of hats and then finding out how they actually
//  sit is how you end up with a wardrobe nobody uses twice.
//

import SwiftUI

struct SkinStoreView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var skins = SkinManager.shared
    @ObservedObject private var themes = ThemeManager.shared

    /// The mood the previews wear. His happiest face, because a wardrobe full
    /// of crying Ziggys is a hard sell.
    private let previewMood = "ziggy_happie"

    let petName: String

    private var theme: ZiggyTheme { themes.theme }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {

        ZStack {

            theme.gradient.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                ScrollView(showsIndicators: false) {

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ZiggySkin.all) { skin in
                            card(skin)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 38, height: 38)
                    .background(theme.surface(0.8), in: Circle())
            }

            Spacer()

            VStack(spacing: 1) {
                Text("\(petName)'s look")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(theme.ink)
                Text("You both see it")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.inkSoft)
            }

            Spacer()

            // Balances the close button so the title sits centred.
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: Cards

    private func card(_ skin: ZiggySkin) -> some View {

        let isOn = skin.id == skins.skin.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                skins.choose(skin)
            }
        } label: {

            VStack(spacing: 6) {

                ZiggySprite(mood: previewMood, skin: skin)
                    .frame(height: 118)
                    .padding(.top, 8)

                Text(skin.name)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(skin.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.surface(isOn ? 0.95 : 0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isOn ? theme.accent : theme.ink.opacity(0.08),
                        lineWidth: isOn ? 2.5 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(theme.accent)
                        .padding(9)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SkinStoreView(petName: "Ziggy")
}
