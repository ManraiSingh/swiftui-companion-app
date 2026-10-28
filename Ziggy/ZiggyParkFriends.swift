//
//  ZiggyParkFriends.swift
//  Ziggy
//
//  Saying hello to the animals in Hanami Park: walk up to one and a button
//  pops up to pet it (or wave, or feed the koi).
//

import SwiftUI

private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// The animal's face in a soft coloured circle.
private struct FriendBadge: View {
    let friend: ParkFriend
    var size: CGFloat = 54

    var body: some View {
        Image(systemName: friend.symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(Color(red: 0.93, green: 0.36, blue: 0.53))
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: friend.tint)))
            .overlay(alignment: .topTrailing) {
                if friend == .spiritFox {
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundStyle(Color(hex: 0x8E7CF2))
                }
            }
    }
}

// MARK: - Saying hello

/// Pops up above the thumb pad when an animal is close enough to greet.
@available(iOS 18.0, *)
struct ParkPetButton: View {

    let friend: ParkFriend
    let action: () -> Void
    @State private var tapped = 0

    var body: some View {
        Button {
            tapped += 1
            action()
        } label: {
            HStack(spacing: 10) {
                FriendBadge(friend: friend, size: 40)
                    .symbolEffect(.bounce, value: tapped)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(friend.action) \(friend.name)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(pink)
                    Text(friend.species)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pink.opacity(0.8))
                    .phaseAnimator([0.0, -3.0]) { hand, y in hand.offset(y: y) } animation: { _ in .easeInOut(duration: 0.5) }
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.96)))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}
