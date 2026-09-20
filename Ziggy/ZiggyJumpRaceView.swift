//
//  ZiggyJumpRaceView.swift
//  Ziggy
//
//  The waiting room, and the referee.
//
//  This screen owns the shared document and nothing else: it claims a side,
//  tracks who is ready, builds the course once the seed lands, hands that to
//  the playfield, and relays positions in both directions. The game itself
//  knows nothing about Firestore.
//

import SwiftUI

struct ZiggyJumpRaceView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: String?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var status = "lobby"
    @State private var winner = ""

    @State private var seed: Int64 = 0
    @State private var level: RaceLevel?

    @State private var theirDistance: CGFloat = 0

    @State private var racing = false

    private let sky = Sky.at(0.62)

    private var username: String { UserManager.shared.username }

    private var iAmLeft: Bool { assignedSide == "left" }
    private var isReady: Bool { iAmLeft ? leftReady : rightReady }
    private var partnerReady: Bool { iAmLeft ? rightReady : leftReady }
    private var partnerName: String {
        let name = iAmLeft ? rightPlayer : leftPlayer
        return name.isEmpty ? "Waiting for partner" : name
    }
    private var bothHere: Bool { !leftPlayer.isEmpty && !rightPlayer.isEmpty }

    private var inviteMessage: String {
        "Race me at Ziggy Jump. Open Ziggy, use relationship code \(RelationshipManager.shared.relationshipCode), tap Jump, then Race."
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [sky.top.color, sky.mid.color, sky.low.color],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                header

                if status == "complete" && !winner.isEmpty {
                    resultCard
                } else {
                    lobby
                }
            }
        }
        .onAppear(perform: connect)
        .onDisappear {
            FirestoreManager.shared.stopZiggyJumpRaceListener()
        }
        .fullScreenCover(isPresented: $racing) {
            if let level {
                ZiggyJumpGameView(
                    petVM: petVM,
                    race: RaceHooks(
                        level: level,
                        ghostDistance: theirDistance,
                        onProgress: { distance in
                            guard let side = assignedSide else { return }
                            FirestoreManager.shared.updateZiggyJumpRaceProgress(
                                side: side, distance: Double(distance)
                            )
                        },
                        onFinish: {
                            guard let side = assignedSide else { return }
                            FirestoreManager.shared.finishZiggyJumpRace(
                                side: side, username: username
                            )
                        }
                    )
                )
            }
        }
        .onChange(of: racing) { _, stillRacing in
            // Backing out mid-race puts the room back to the lobby rather
            // than leaving the other person racing a phantom to the flag.
            if !stillRacing, status == "racing" {
                FirestoreManager.shared.resetZiggyJumpRace()
            }
        }
    }

    // MARK: Plumbing

    private func connect() {

        FirestoreManager.shared.joinZiggyJumpRace(username: username) { side in
            DispatchQueue.main.async { assignedSide = side }
        }

        FirestoreManager.shared.listenForZiggyJumpRace { data in

            DispatchQueue.main.async {

                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                status = data["status"] as? String ?? "lobby"
                winner = data["winner"] as? String ?? ""

                let left = data["leftDistance"] as? Double ?? 0
                let right = data["rightDistance"] as? Double ?? 0
                theirDistance = CGFloat(iAmLeft ? right : left)

                // Built once per seed. Rebuilding mid-race would hand this
                // player a different course from the one they started on.
                let incoming = data["seed"] as? Int64 ?? 0
                if incoming != 0, incoming != seed {
                    seed = incoming
                    level = RaceLevel.build(seed: UInt64(bitPattern: incoming))
                }

                racing = (status == "racing") && level != nil
            }
        }
    }

    private func toggleReady() {
        guard let side = assignedSide else { return }
        FirestoreManager.shared.setZiggyJumpRaceReady(side: side, isReady: !isReady)
    }

    // MARK: Screens

    private var header: some View {

        HStack {

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.30), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            }

            Spacer()

            Text("Race")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Circle().fill(.clear).frame(width: 40, height: 40)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var lobby: some View {

        VStack(spacing: 16) {

            Spacer(minLength: 10)

            Image("z6")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.28), radius: 14, y: 8)

            VStack(spacing: 5) {

                Text("Waiting room")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Same course, two phones.\nFirst one to the flag wins.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 9) {
                seat(name: leftPlayer.isEmpty ? "You" : leftPlayer,
                     ready: leftReady, isMe: iAmLeft)
                seat(name: rightPlayer.isEmpty ? "Waiting for partner" : rightPlayer,
                     ready: rightReady, isMe: assignedSide == "right")
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)

            VStack(spacing: 10) {

                ShareLink(item: inviteMessage) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.22), lineWidth: 1.5)
                        )
                }

                Button(action: toggleReady) {
                    Text(isReady ? "Ready — waiting for them" : "I'm ready")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            isReady ? .white : Color(red: 0.16, green: 0.12, blue: 0.10)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isReady
                                      ? AnyShapeStyle(Color.white.opacity(0.18))
                                      : AnyShapeStyle(Color(red: 0.99, green: 0.74, blue: 0.40)))
                        )
                }
                .disabled(assignedSide == nil || !bothHere)
                .opacity(assignedSide == nil || !bothHere ? 0.45 : 1)

                if !bothHere {
                    Text("Your partner needs to open this screen too.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func seat(name: String, ready: Bool, isMe: Bool) -> some View {

        HStack(spacing: 11) {

            Image(systemName: ready ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ready
                                 ? Color(red: 0.55, green: 0.88, blue: 0.60)
                                 : .white.opacity(0.35))

            Text(name)
                .font(.system(size: 14, weight: isMe ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(name.hasPrefix("Waiting") ? 0.45 : 0.92))
                .lineLimit(1)

            if isMe {
                Text("YOU")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var resultCard: some View {

        let iWon = winner == username

        return VStack(spacing: 16) {

            Spacer()

            Image(iWon ? "z6" : "z7")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.28), radius: 14, y: 8)

            VStack(spacing: 4) {

                Text(iWon ? "You won" : "\(winner) won")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(iWon ? "Straight to the flag." : "Closer next time.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button {
                FirestoreManager.shared.resetZiggyJumpRace()
            } label: {
                Text("Race again")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.12, blue: 0.10))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(red: 0.99, green: 0.74, blue: 0.40))
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    ZiggyJumpRaceView(petVM: PetViewModel())
}
