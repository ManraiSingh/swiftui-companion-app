import SwiftUI

private enum TTTSide: String {

    case x = "X"
    case o = "O"
}

struct TicTacToeGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: TTTSide?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var rewardClaimed = false
    @State private var didAwardLove = false
    @State private var gameStatus = "lobby"

    @State private var board: [String] = Array(repeating: "", count: 9)
    @State private var currentTurn = "X"
    @State private var winner = ""

    private var username: String {
        UserManager.shared.username
    }

    private var bothComplete: Bool {
        gameStatus == "complete"
    }

    private var myTurn: Bool {
        gameStatus == "playing" && assignedSide != nil && currentTurn == assignedSide?.rawValue
    }

    private var partnerReady: Bool {
        assignedSide == .x ? rightReady : leftReady
    }

    private var isReady: Bool {
        assignedSide == .x ? leftReady : rightReady
    }

    private var inviteMessage: String {
        "Come play Tic Tac Toe with me in Ziggy. Open the app, use relationship code \(RelationshipManager.shared.relationshipCode), tap Play, then press Ready."
    }

    private var resultText: String {
        if winner == "draw" { return "It's a draw! 🤝" }
        if winner.isEmpty { return "" }
        if winner == assignedSide?.rawValue { return "You won! 🎉" }
        return "Your partner won! 💔"
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    .pink.opacity(0.18),
                    .cyan.opacity(0.18),
                    .yellow.opacity(0.14)
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

            Text("Tic Tac Toe")
                .font(.title2)
                .fontWeight(.black)

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

            Spacer(minLength: 10)

            Image(systemName: "number")
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(.pink, .cyan.opacity(0.45))
                .frame(height: 92)

            VStack(spacing: 10) {

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
                    side: "X",
                    isReady: leftReady
                )

                playerRow(
                    name: rightPlayer.isEmpty ? "Waiting for partner" : rightPlayer,
                    side: "O",
                    isReady: rightReady
                )
            }

            ShareLink(item: inviteMessage) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
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
                .background(isReady ? .green : .pink)
                .clipShape(Capsule())
            }
            .disabled(assignedSide == nil)

            if isReady && !partnerReady {

                Text("You are ready. Waiting for your partner.")
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
        side: String,
        isReady: Bool
    ) -> some View {

        HStack {

            VStack(alignment: .leading, spacing: 2) {

                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Plays \(side)")
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
        .background(.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Live Status

    private var liveStatusPanel: some View {

        VStack(spacing: 6) {

            if bothComplete {

                Text(resultText)
                    .font(.title3)
                    .fontWeight(.black)

            } else {

                Text(myTurn ? "Your turn! ✏️" : "Partner's turn…")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("You are \(assignedSide?.rawValue ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Board

    private var boardView: some View {

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
        ) {
            ForEach(0..<9, id: \.self) { index in
                cellButton(index)
            }
        }
        .padding(16)
        .background(.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellButton(_ index: Int) -> some View {

        Button {
            makeMove(index)
        } label: {
            ZStack {

                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isWinningCell(index)
                        ? Color.green.opacity(0.28)
                        : Color.white.opacity(0.88)
                    )

                Text(board[index])
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(board[index] == "X" ? .pink : .blue)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(!myTurn || !board[index].isEmpty || gameStatus != "playing")
    }

    private func isWinningCell(_ index: Int) -> Bool {

        guard bothComplete, winner == "X" || winner == "O" else {
            return false
        }

        for line in FirestoreManager.ticTacToeWinningLines {
            if line.contains(index),
               board[line[0]] == winner,
               board[line[1]] == winner,
               board[line[2]] == winner {
                return true
            }
        }

        return false
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
                                Text("New Game")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.blue)
                                    .clipShape(Capsule())
                            }

                            Button {
                                dismiss()
                            } label: {
                                Text("Back Home")
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
                            Text("Claim Reward")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.pink)
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

        FirestoreManager.shared.joinTicTacToeGame(username: username) { side in

            DispatchQueue.main.async {

                if let side, let ttSide = TTTSide(rawValue: side) {
                    assignedSide = ttSide
                } else if retriesLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        joinGame(retriesLeft: retriesLeft - 1)
                    }
                }
            }
        }
    }

    private func listenForGame() {

        FirestoreManager.shared.listenForTicTacToeGame { data in

            DispatchQueue.main.async {

                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                rewardClaimed = data["rewardClaimed"] as? Bool ?? false
                gameStatus = data["status"] as? String ?? "lobby"
                board = data["board"] as? [String] ?? Array(repeating: "", count: 9)
                currentTurn = data["currentTurn"] as? String ?? "X"
                winner = data["winner"] as? String ?? ""

                // Recover our side from the snapshot if the join callback was
                // slow or failed — prevents "both in lobby but can't Ready".
                if assignedSide == nil {
                    if leftPlayer == username {
                        assignedSide = .x
                    } else if rightPlayer == username {
                        assignedSide = .o
                    }
                }
            }
        }
    }

    private func toggleReady() {

        guard let assignedSide else { return }

        FirestoreManager.shared.setTicTacToeReady(
            side: assignedSide.rawValue,
            username: username,
            isReady: !isReady
        )
    }

    private func makeMove(_ index: Int) {

        guard let assignedSide, myTurn, board[index].isEmpty else { return }

        FirestoreManager.shared.makeTicTacToeMove(
            index: index,
            mark: assignedSide.rawValue
        )
    }

    private func claimReward() {

        FirestoreManager.shared.claimTicTacToeReward { didClaim in

            guard didClaim else { return }

            DispatchQueue.main.async {
                petVM.play()
                didAwardLove = true
            }
        }
    }

    private func startNewRound() {

        board = Array(repeating: "", count: 9)
        winner = ""
        didAwardLove = false
        // Keep our assigned side and BOTH players — only the round state is
        // reset — so neither person is dropped from the lobby.
        FirestoreManager.shared.resetTicTacToeGame()
    }
}

#Preview {
    TicTacToeGameView(petVM: PetViewModel())
}
