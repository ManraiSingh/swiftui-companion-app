import SwiftUI

struct MemoryMatchGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: String?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var rewardClaimed = false
    @State private var didAwardLove = false
    @State private var gameStatus = "lobby"

    @State private var cards: [String] =
        Array(repeating: "", count: FirestoreManager.memoryMatchCardCount)
    @State private var matchedIndices: [Int] = []
    @State private var revealedIndices: [Int] = []
    @State private var pendingClearFor: [Int] = []

    @State private var currentTurn = "left"
    @State private var leftScore = 0
    @State private var rightScore = 0
    @State private var winner = ""

    private let accent = Color(red: 0.45, green: 0.32, blue: 0.78)

    private var username: String {
        UserManager.shared.username
    }

    private var bothComplete: Bool {
        gameStatus == "complete"
    }

    private var myTurn: Bool {
        gameStatus == "playing" && assignedSide != nil && currentTurn == assignedSide
    }

    private var canInteract: Bool {
        myTurn && revealedIndices.count < 2 && pendingClearFor.isEmpty
    }

    private var partnerReady: Bool {
        assignedSide == "left" ? rightReady : leftReady
    }

    private var isReady: Bool {
        assignedSide == "left" ? leftReady : rightReady
    }

    private var myScore: Int {
        assignedSide == "left" ? leftScore : rightScore
    }

    private var partnerScore: Int {
        assignedSide == "left" ? rightScore : leftScore
    }

    private var inviteMessage: String {
        "Come play Memory Match with me in Ziggy. Open the app, use relationship code \(RelationshipManager.shared.relationshipCode), tap Play, then press Ready."
    }

    private var resultText: String {
        if winner == "draw" { return "It's a draw!" }
        if winner.isEmpty { return "" }
        if winner == username { return "You won!" }
        return "Partner won!"
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.90, blue: 1.0),
                    Color(red: 1.0, green: 0.92, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {

                header

                if gameStatus == "playing" || bothComplete {

                    liveStatusPanel

                    boardView

                    gameActionPanel

                } else {

                    lobbyView
                }
            }
            .padding()
        }
        .onAppear {
            joinGame()
            listenForGame()
        }
        .onDisappear {
            FirestoreManager.shared.stopMemoryMatchListener()
        }
    }

    // MARK: - Header

    private var header: some View {

        HStack {

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.82))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Memory Match")
                .font(.title2)
                .fontWeight(.black)
                .foregroundStyle(accent)

            Spacer()

            Button {
                startNewRound()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.82))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Lobby

    private var lobbyView: some View {

        VStack(spacing: 18) {

            Spacer(minLength: 6)

            HStack(spacing: 10) {
                ForEach(["ziggy_happie", "ziggy_loveeyes", "ziggy_sleep"], id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                }
            }

            VStack(spacing: 8) {

                Text("Waiting room")
                    .font(.title)
                    .fontWeight(.black)

                Text("Invite your partner, then both of you tap Ready to start.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 10) {

                playerRow(
                    name: leftPlayer.isEmpty ? "You" : leftPlayer,
                    isReady: leftReady,
                    isMe: assignedSide == "left"
                )

                playerRow(
                    name: rightPlayer.isEmpty ? "Waiting for partner" : rightPlayer,
                    isReady: rightReady,
                    isMe: assignedSide == "right"
                )
            }

            ShareLink(item: inviteMessage) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.75)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }

            Button {
                toggleReady()
            } label: {
                Label(
                    isReady ? "Ready" : "I'm Ready",
                    systemImage: isReady ? "checkmark.circle.fill" : "play.circle.fill"
                )
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isReady
                    ? AnyShapeStyle(Color.green)
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .clipShape(Capsule())
            }
            .disabled(assignedSide == nil)

            if isReady && !partnerReady {

                Text("You are ready. Waiting for your partner. 💕")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func playerRow(
        name: String,
        isReady: Bool,
        isMe: Bool
    ) -> some View {

        HStack(spacing: 12) {

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(accent)
                )

            VStack(alignment: .leading, spacing: 2) {

                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(isMe ? "You" : "Partner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(
                isReady ? "Ready" : "Not ready",
                systemImage: isReady ? "checkmark.circle.fill" : "circle"
            )
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(isReady ? .green : .secondary)
        }
        .padding(12)
        .background(isMe ? accent.opacity(0.08) : Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMe ? accent.opacity(0.35) : Color.clear, lineWidth: 1.4)
        )
    }

    // MARK: - Live Status

    private var liveStatusPanel: some View {

        VStack(spacing: 8) {

            if bothComplete {

                resultBanner

            } else {

                HStack(spacing: 8) {

                    Image(systemName: myTurn ? "hand.point.up.left.fill" : "hourglass")
                        .foregroundStyle(myTurn ? accent : .secondary)

                    Text(myTurn ? "Your turn!" : "Partner's turn…")
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }

            HStack(spacing: 18) {
                scorePill(label: "You", score: myScore, highlighted: myScore > partnerScore)
                scorePill(label: "Partner", score: partnerScore, highlighted: partnerScore > myScore)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func scorePill(label: String, score: Int, highlighted: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Text("\(score)")
                .font(.headline)
                .fontWeight(.black)
                .foregroundStyle(highlighted ? accent : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.7)))
    }

    private var resultBanner: some View {

        let isMyWin = winner == username
        let isDraw = winner == "draw"

        return HStack(spacing: 8) {
            Image(systemName: isDraw ? "hands.clap.fill" : (isMyWin ? "trophy.fill" : "heart.fill"))
            Text(resultText)
                .fontWeight(.black)
        }
        .font(.title3)
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(
                isDraw
                ? AnyShapeStyle(Color.orange.opacity(0.9))
                : AnyShapeStyle(
                    LinearGradient(
                        colors: isMyWin ? [.pink, accent] : [.gray, .gray.opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )
        )
    }

    // MARK: - Board

    private let columns = 4

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: columns)
    }

    private var boardView: some View {
        LazyVGrid(columns: gridItems, spacing: 10) {
            ForEach(cards.indices, id: \.self) { index in
                cardView(at: index)
                    .aspectRatio(0.75, contentMode: .fit)
            }
        }
        .padding(14)
        .background(.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func cardView(at index: Int) -> some View {

        let isMatched = matchedIndices.contains(index)
        let isRevealed = revealedIndices.contains(index)
        let isFaceUp = isMatched || isRevealed
        let emotion = cards[index]

        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [accent, Color.pink],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.8))
                )
                .opacity(isFaceUp ? 0 : 1)

            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .overlay(
                    Group {
                        if !emotion.isEmpty {
                            Image(emotion)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isMatched ? Color.green.opacity(0.7) : Color.clear, lineWidth: 3)
                )
                .opacity(isFaceUp ? 1 : 0)
        }
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .rotation3DEffect(
            .degrees(isFaceUp ? 0 : 180),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeInOut(duration: 0.3), value: isFaceUp)
        .opacity(isMatched ? 0.55 : 1)
        .onTapGesture {
            flipCard(index)
        }
        .allowsHitTesting(canInteract && !isFaceUp)
    }

    // MARK: - Action Panel

    private var gameActionPanel: some View {

        Group {

            if bothComplete {

                VStack(spacing: 10) {

                    if didAwardLove || rewardClaimed {

                        HStack {

                            Button {
                                startNewRound()
                            } label: {
                                Label("New Game", systemImage: "arrow.triangle.2.circlepath")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(accent)
                                    .clipShape(Capsule())
                            }

                            Button {
                                dismiss()
                            } label: {
                                Label("Back Home", systemImage: "house.fill")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.green)
                                    .clipShape(Capsule())
                            }
                        }

                    } else {

                        Button {
                            claimReward()
                        } label: {
                            Label("Claim Reward", systemImage: "heart.fill")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.pink, accent],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - Logic

    private func joinGame(retriesLeft: Int = 2) {

        FirestoreManager.shared.joinMemoryMatchGame(username: username) { side in

            DispatchQueue.main.async {

                if let side {
                    assignedSide = side
                } else if retriesLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        joinGame(retriesLeft: retriesLeft - 1)
                    }
                }
            }
        }
    }

    private func listenForGame() {

        FirestoreManager.shared.listenForMemoryMatchGame { data in

            DispatchQueue.main.async {

                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                rewardClaimed = data["rewardClaimed"] as? Bool ?? false
                gameStatus = data["status"] as? String ?? "lobby"
                currentTurn = data["currentTurn"] as? String ?? "left"
                leftScore = data["leftScore"] as? Int ?? 0
                rightScore = data["rightScore"] as? Int ?? 0
                winner = data["winner"] as? String ?? ""
                matchedIndices = data["matchedIndices"] as? [Int] ?? []
                revealedIndices = data["revealedIndices"] as? [Int] ?? []
                cards = data["cards"] as? [String]
                    ?? Array(repeating: "", count: FirestoreManager.memoryMatchCardCount)

                if assignedSide == nil {
                    if leftPlayer == username {
                        assignedSide = "left"
                    } else if rightPlayer == username {
                        assignedSide = "right"
                    }
                }

                scheduleMismatchClearIfNeeded()
            }
        }
    }

    /// Once two revealed cards turn out not to match, give both partners a
    /// beat to actually see them before hiding them again — guarded so it
    /// only schedules once per mismatch, not on every snapshot update while
    /// it's still pending.
    private func scheduleMismatchClearIfNeeded() {

        guard
            revealedIndices.count == 2,
            revealedIndices != pendingClearFor
        else { return }

        let a = revealedIndices[0]
        let b = revealedIndices[1]

        guard
            a < cards.count, b < cards.count,
            cards[a] != cards[b]
        else { return }

        pendingClearFor = revealedIndices

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            FirestoreManager.shared.clearMemoryMismatch()
            pendingClearFor = []
        }
    }

    private func toggleReady() {

        guard let assignedSide else { return }

        FirestoreManager.shared.setMemoryMatchReady(
            side: assignedSide,
            username: username,
            isReady: !isReady
        )
    }

    private func flipCard(_ index: Int) {

        guard
            let assignedSide,
            canInteract,
            !matchedIndices.contains(index),
            !revealedIndices.contains(index)
        else { return }

        FirestoreManager.shared.flipMemoryCard(index: index, side: assignedSide)
    }

    private func claimReward() {

        FirestoreManager.shared.claimMemoryMatchReward { didClaim in

            guard didClaim else { return }

            DispatchQueue.main.async {
                petVM.play()
                didAwardLove = true
            }
        }
    }

    private func startNewRound() {

        matchedIndices = []
        revealedIndices = []
        pendingClearFor = []
        winner = ""
        didAwardLove = false
        FirestoreManager.shared.resetMemoryMatchGame()
    }
}

#Preview {
    MemoryMatchGameView(petVM: PetViewModel())
}
