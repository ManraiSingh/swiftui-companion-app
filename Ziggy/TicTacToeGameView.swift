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

    private let xColor = Color(red: 1.0, green: 0.31, blue: 0.64)
    private let oColor = Color(red: 0.58, green: 0.42, blue: 0.93)

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
        if winner == "draw" { return "It's a draw!" }
        if winner.isEmpty { return "" }
        if winner == assignedSide?.rawValue { return "You won!" }
        return "Partner won!"
    }

    private var mySideColor: Color {
        assignedSide == .x ? xColor : oColor
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.90, blue: 0.95),
                    Color(red: 0.93, green: 0.90, blue: 1.0),
                    Color(red: 0.90, green: 0.96, blue: 1.0)
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [xColor, oColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

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

            HStack(spacing: 16) {

                markBadge(mark: "X", color: xColor, size: 68)

                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.pink.opacity(0.5))

                markBadge(mark: "O", color: oColor, size: 68)
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
                    side: "X",
                    isReady: leftReady,
                    isMe: assignedSide == .x
                )

                playerRow(
                    name: rightPlayer.isEmpty ? "Waiting for partner" : rightPlayer,
                    side: "O",
                    isReady: rightReady,
                    isMe: assignedSide == .o
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
                            colors: [oColor, oColor.opacity(0.75)],
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
                            colors: [xColor, xColor.opacity(0.75)],
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

    private func markBadge(mark: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: mark == "X" ? "xmark" : "circle")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(color)
        }
    }

    private func playerRow(
        name: String,
        side: String,
        isReady: Bool,
        isMe: Bool
    ) -> some View {

        let sideColor = side == "X" ? xColor : oColor

        return HStack(spacing: 12) {

            markBadge(mark: side, color: sideColor, size: 40)

            VStack(alignment: .leading, spacing: 2) {

                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(isMe ? "You · plays \(side)" : "Plays \(side)")
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
        .background(isMe ? sideColor.opacity(0.08) : Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMe ? sideColor.opacity(0.35) : Color.clear, lineWidth: 1.4)
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
                        .foregroundStyle(myTurn ? mySideColor : .secondary)

                    Text(myTurn ? "Your turn!" : "Partner's turn…")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                if let assignedSide {
                    HStack(spacing: 6) {
                        Image(systemName: assignedSide == .x ? "xmark" : "circle")
                            .font(.system(size: 11, weight: .black))
                        Text("You play \(assignedSide.rawValue)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(mySideColor))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var resultBanner: some View {

        let isMyWin = winner == assignedSide?.rawValue
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
                        colors: isMyWin ? [xColor, oColor] : [.gray, .gray.opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )
        )
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
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    myTurn ? mySideColor.opacity(0.45) : Color.clear,
                    lineWidth: 3
                )
        )
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.25), value: myTurn)
    }

    private func cellButton(_ index: Int) -> some View {

        Button {
            makeMove(index)
        } label: {
            ZStack {

                RoundedRectangle(cornerRadius: 16)
                    .fill(cellBackground(index))
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 2)

                if board[index] == "X" {
                    Image(systemName: "xmark")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(xColor)
                        .transition(.scale.combined(with: .opacity))
                } else if board[index] == "O" {
                    Image(systemName: "circle")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(oColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(!myTurn || !board[index].isEmpty || gameStatus != "playing")
        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: board[index])
    }

    private func cellBackground(_ index: Int) -> Color {

        if isWinningCell(index) {
            return Color.green.opacity(0.25)
        }

        if myTurn, board[index].isEmpty, gameStatus == "playing" {
            return mySideColor.opacity(0.09)
        }

        return Color.white.opacity(0.9)
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
                                Label("New Game", systemImage: "arrow.triangle.2.circlepath")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(oColor)
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
                                        colors: [xColor, oColor],
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
