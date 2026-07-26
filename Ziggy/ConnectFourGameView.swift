import SwiftUI

private enum C4Side: String {

    case red = "R"
    case yellow = "Y"
}

private struct FallingPiece: Equatable {
    let col: Int
    let row: Int
    let mark: String
    var settled: Bool
}

struct ConnectFourGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: C4Side?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var rewardClaimed = false
    @State private var didAwardLove = false
    @State private var gameStatus = "lobby"

    @State private var remoteBoard: [String] =
        Array(repeating: "", count: FirestoreManager.connectFourCellCount)
    @State private var displayBoard: [String] =
        Array(repeating: "", count: FirestoreManager.connectFourCellCount)
    @State private var fallingPiece: FallingPiece?
    @State private var fallingToken = 0

    @State private var currentTurn = "R"
    @State private var winner = ""

    private let redColor = Color(red: 0.90, green: 0.11, blue: 0.14)
    private let yellowColor = Color(red: 1.0, green: 0.83, blue: 0.0)
    private let boardColor = Color(red: 0.10, green: 0.32, blue: 0.85)

    private let rows = FirestoreManager.connectFourRows
    private let cols = FirestoreManager.connectFourCols
    private let cellSize: CGFloat = 44

    private var username: String {
        UserManager.shared.username
    }

    private var bothComplete: Bool {
        gameStatus == "complete"
    }

    private var myTurn: Bool {
        gameStatus == "playing" && assignedSide != nil && currentTurn == assignedSide?.rawValue
    }

    private var canInteract: Bool {
        myTurn && gameStatus == "playing" && fallingPiece == nil
    }

    private var partnerReady: Bool {
        assignedSide == .red ? rightReady : leftReady
    }

    private var isReady: Bool {
        assignedSide == .red ? leftReady : rightReady
    }

    private var inviteMessage: String {
        "Come play Connect 4 with me in Ziggy. Open the app, use relationship code \(RelationshipManager.shared.relationshipCode), tap Play, then press Ready."
    }

    private var resultText: String {
        if winner == "draw" { return "It's a draw!" }
        if winner.isEmpty { return "" }
        if winner == assignedSide?.rawValue { return "You won!" }
        return "Partner won!"
    }

    private var mySideColor: Color {
        assignedSide == .red ? redColor : yellowColor
    }

    private func sideName(_ side: String) -> String {
        side == "R" ? "Red" : "Yellow"
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.95, blue: 1.0),
                    Color(red: 0.97, green: 0.97, blue: 0.90)
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

            Text("Connect 4")
                .font(.title2)
                .fontWeight(.black)
                .foregroundStyle(
                    LinearGradient(
                        colors: [redColor, yellowColor],
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

                markBadge(color: redColor, size: 56)

                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.pink.opacity(0.5))

                markBadge(color: yellowColor, size: 56)
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
                    side: "R",
                    isReady: leftReady,
                    isMe: assignedSide == .red
                )

                playerRow(
                    name: rightPlayer.isEmpty ? "Waiting for partner" : rightPlayer,
                    side: "Y",
                    isReady: rightReady,
                    isMe: assignedSide == .yellow
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
                            colors: [boardColor, boardColor.opacity(0.75)],
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
                            colors: [redColor, redColor.opacity(0.75)],
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

    private func markBadge(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    private func playerRow(
        name: String,
        side: String,
        isReady: Bool,
        isMe: Bool
    ) -> some View {

        let sideColor = side == "R" ? redColor : yellowColor

        return HStack(spacing: 12) {

            markBadge(color: sideColor, size: 36)

            VStack(alignment: .leading, spacing: 2) {

                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(isMe ? "You · plays \(sideName(side))" : "Plays \(sideName(side))")
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
                        markBadge(color: mySideColor, size: 14)
                        Text("You're \(sideName(assignedSide.rawValue))")
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
                        colors: isMyWin ? [redColor, yellowColor] : [.gray, .gray.opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )
        )
    }

    // MARK: - Board

    private var boardWidth: CGFloat {
        cellSize * CGFloat(cols)
    }

    private var boardHeight: CGFloat {
        cellSize * CGFloat(rows)
    }

    private func cellPosition(row: Int, col: Int) -> CGPoint {

        let visualRow = rows - 1 - row

        return CGPoint(
            x: (CGFloat(col) + 0.5) * cellSize,
            y: (CGFloat(visualRow) + 0.5) * cellSize
        )
    }

    private var boardView: some View {

        ZStack {

            RoundedRectangle(cornerRadius: 20)
                .fill(boardColor)
                .frame(width: boardWidth + 20, height: boardHeight + 20)
                .shadow(color: .black.opacity(0.28), radius: 12, y: 8)

            ZStack {

                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        holeView(row: r, col: c)
                            .position(cellPosition(row: r, col: c))
                    }
                }

                if let fallingPiece {

                    let target = cellPosition(row: fallingPiece.row, col: fallingPiece.col)

                    Circle()
                        .fill(fallingPiece.mark == "R" ? redColor : yellowColor)
                        .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                        .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .position(
                            x: target.x,
                            y: fallingPiece.settled ? target.y : -cellSize * 0.5
                        )
                }
            }
            .frame(width: boardWidth, height: boardHeight)
            .clipped()

            HStack(spacing: 0) {
                ForEach(0..<cols, id: \.self) { c in
                    Button {
                        dropPiece(col: c)
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .frame(width: cellSize, height: boardHeight)
                    .disabled(!canDropInColumn(c))
                }
            }
            .frame(width: boardWidth, height: boardHeight)
        }
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    myTurn ? mySideColor.opacity(0.55) : Color.clear,
                    lineWidth: 3
                )
        )
        .animation(.easeInOut(duration: 0.25), value: myTurn)
    }

    private func holeView(row: Int, col: Int) -> some View {

        let index = row * cols + col
        let owner = index < displayBoard.count ? displayBoard[index] : ""

        return ZStack {

            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: cellSize * 0.8, height: cellSize * 0.8)

            if !owner.isEmpty {
                Circle()
                    .fill(owner == "R" ? redColor : yellowColor)
                    .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func canDropInColumn(_ col: Int) -> Bool {

        guard canInteract else { return false }

        let topIndex = (rows - 1) * cols + col

        guard topIndex < displayBoard.count else { return false }

        return displayBoard[topIndex].isEmpty
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
                                    .background(boardColor)
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
                                        colors: [redColor, yellowColor],
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

        FirestoreManager.shared.joinConnectFourGame(username: username) { side in

            DispatchQueue.main.async {

                if let side, let c4Side = C4Side(rawValue: side) {
                    assignedSide = c4Side
                } else if retriesLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        joinGame(retriesLeft: retriesLeft - 1)
                    }
                }
            }
        }
    }

    private func listenForGame() {

        FirestoreManager.shared.listenForConnectFourGame { data in

            DispatchQueue.main.async {

                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                rewardClaimed = data["rewardClaimed"] as? Bool ?? false
                gameStatus = data["status"] as? String ?? "lobby"
                currentTurn = data["currentTurn"] as? String ?? "R"
                winner = data["winner"] as? String ?? ""

                let newBoard = data["board"] as? [String]
                    ?? Array(repeating: "", count: FirestoreManager.connectFourCellCount)

                applyIncomingBoard(newBoard)

                // Recover our side from the snapshot if the join callback was
                // slow or failed — prevents "both in lobby but can't Ready".
                if assignedSide == nil {
                    if leftPlayer == username {
                        assignedSide = .red
                    } else if rightPlayer == username {
                        assignedSide = .yellow
                    }
                }
            }
        }
    }

    /// Diffs the incoming board against what we last knew. Exactly one newly
    /// filled cell means a single live move — animate it falling into place.
    /// Anything else (fresh join, reset, bulk resync) snaps instantly.
    private func applyIncomingBoard(_ newBoard: [String]) {

        guard newBoard.count == remoteBoard.count else {
            remoteBoard = newBoard
            displayBoard = newBoard
            fallingPiece = nil
            return
        }

        let diffs = (0..<newBoard.count).filter {
            remoteBoard[$0].isEmpty && !newBoard[$0].isEmpty
        }

        remoteBoard = newBoard

        if diffs.count == 1, let index = diffs.first {

            let row = index / cols
            let col = index % cols

            animateDrop(col: col, row: row, mark: newBoard[index], finalBoard: newBoard)

        } else {

            displayBoard = newBoard
            fallingPiece = nil
        }
    }

    private func animateDrop(col: Int, row: Int, mark: String, finalBoard: [String]) {

        fallingToken += 1
        let token = fallingToken

        fallingPiece = FallingPiece(col: col, row: row, mark: mark, settled: false)

        let cellsTravelled = rows - row
        let response = 0.22 + Double(cellsTravelled) * 0.045

        DispatchQueue.main.async {

            guard token == fallingToken else { return }

            withAnimation(.spring(response: response, dampingFraction: 0.72)) {
                fallingPiece?.settled = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + response * 1.4) {
                guard token == fallingToken else { return }
                displayBoard = finalBoard
                fallingPiece = nil
            }
        }
    }

    private func toggleReady() {

        guard let assignedSide else { return }

        FirestoreManager.shared.setConnectFourReady(
            side: assignedSide.rawValue,
            username: username,
            isReady: !isReady
        )
    }

    private func dropPiece(col: Int) {

        guard let assignedSide, canDropInColumn(col) else { return }

        FirestoreManager.shared.makeConnectFourMove(
            col: col,
            mark: assignedSide.rawValue
        )
    }

    private func claimReward() {

        FirestoreManager.shared.claimConnectFourReward { didClaim in

            guard didClaim else { return }

            DispatchQueue.main.async {
                petVM.play()
                didAwardLove = true
            }
        }
    }

    private func startNewRound() {

        remoteBoard = Array(repeating: "", count: FirestoreManager.connectFourCellCount)
        displayBoard = Array(repeating: "", count: FirestoreManager.connectFourCellCount)
        fallingPiece = nil
        winner = ""
        didAwardLove = false
        // Keep our assigned side and BOTH players — only the round state is
        // reset — so neither person is dropped from the lobby.
        FirestoreManager.shared.resetConnectFourGame()
    }
}

#Preview {
    ConnectFourGameView(petVM: PetViewModel())
}
