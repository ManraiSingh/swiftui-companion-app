import SwiftUI

private enum DABSide: String {

    case x = "X"
    case o = "O"
}

struct DotsAndBoxesGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: DABSide?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var rewardClaimed = false
    @State private var didAwardLove = false
    @State private var gameStatus = "lobby"

    @State private var horizontalLines: [Bool] =
        Array(repeating: false, count: FirestoreManager.dotsAndBoxesHLineCount)
    @State private var verticalLines: [Bool] =
        Array(repeating: false, count: FirestoreManager.dotsAndBoxesVLineCount)
    @State private var boxOwners: [String] =
        Array(repeating: "", count: FirestoreManager.dotsAndBoxesBoxCount)
    @State private var currentTurn = "X"
    @State private var winner = ""

    private let xColor = Color(red: 1.0, green: 0.31, blue: 0.64)
    private let oColor = Color(red: 0.58, green: 0.42, blue: 0.93)

    private let rows = FirestoreManager.dotsAndBoxesRows
    private let cols = FirestoreManager.dotsAndBoxesCols
    private let boardSide: CGFloat = 300

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
        "Come play Dots and Boxes with me in Ziggy. Open the app, use relationship code \(RelationshipManager.shared.relationshipCode), tap Play, then press Ready."
    }

    private var xScore: Int {
        boxOwners.filter { $0 == "X" }.count
    }

    private var oScore: Int {
        boxOwners.filter { $0 == "O" }.count
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

            Text("Dots and Boxes")
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

        VStack(spacing: 10) {

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

            scoreRow
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var scoreRow: some View {

        HStack(spacing: 16) {
            scoreBadge(mark: "X", color: xColor, score: xScore)
            scoreBadge(mark: "O", color: oColor, score: oScore)
        }
    }

    private func scoreBadge(mark: String, color: Color, score: Int) -> some View {

        HStack(spacing: 6) {
            Image(systemName: mark == "X" ? "xmark" : "circle")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(color)
            Text("\(score) box\(score == 1 ? "" : "es")")
                .font(.subheadline)
                .fontWeight(.black)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
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

    private var cellSize: CGFloat {
        boardSide / CGFloat(cols)
    }

    private var boardView: some View {

        ZStack {

            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    boxFill(row: r, col: c)
                        .position(
                            x: (CGFloat(c) + 0.5) * cellSize,
                            y: (CGFloat(r) + 0.5) * cellSize
                        )
                }
            }

            ForEach(0...rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    edgeButton(isVertical: false, index: r * cols + c)
                        .position(
                            x: (CGFloat(c) + 0.5) * cellSize,
                            y: CGFloat(r) * cellSize
                        )
                }
            }

            ForEach(0..<rows, id: \.self) { r in
                ForEach(0...cols, id: \.self) { c in
                    edgeButton(isVertical: true, index: r * (cols + 1) + c)
                        .position(
                            x: CGFloat(c) * cellSize,
                            y: (CGFloat(r) + 0.5) * cellSize
                        )
                }
            }

            ForEach(0...rows, id: \.self) { r in
                ForEach(0...cols, id: \.self) { c in
                    Circle()
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: 8, height: 8)
                        .position(
                            x: CGFloat(c) * cellSize,
                            y: CGFloat(r) * cellSize
                        )
                }
            }
        }
        .frame(width: boardSide, height: boardSide)
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
        .animation(.easeInOut(duration: 0.25), value: myTurn)
    }

    private func boxFill(row: Int, col: Int) -> some View {

        let boxIndex = row * cols + col
        let owner = boxIndex < boxOwners.count ? boxOwners[boxIndex] : ""
        let color: Color = owner == "X" ? xColor : (owner == "O" ? oColor : .clear)

        return ZStack {

            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(owner.isEmpty ? 0 : 0.22))

            if owner == "X" {
                Image(systemName: "xmark")
                    .font(.system(size: cellSize * 0.32, weight: .black))
                    .foregroundStyle(xColor.opacity(0.6))
                    .transition(.scale.combined(with: .opacity))
            } else if owner == "O" {
                Image(systemName: "circle")
                    .font(.system(size: cellSize * 0.28, weight: .black))
                    .foregroundStyle(oColor.opacity(0.6))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: cellSize - 10, height: cellSize - 10)
        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: owner)
    }

    private func edgeButton(isVertical: Bool, index: Int) -> some View {

        let lines = isVertical ? verticalLines : horizontalLines
        let isDrawn = index < lines.count ? lines[index] : false
        let canPlay = myTurn && !isDrawn && gameStatus == "playing"

        let idleColor: Color = canPlay ? mySideColor.opacity(0.25) : Color.gray.opacity(0.12)
        let width: CGFloat = isVertical ? 22 : cellSize - 14
        let height: CGFloat = isVertical ? cellSize - 14 : 22

        return Button {
            makeMove(isVertical: isVertical, index: index)
        } label: {
            Capsule()
                .fill(isDrawn ? Color.primary.opacity(0.7) : idleColor)
                .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .disabled(isDrawn || !myTurn || gameStatus != "playing")
        .animation(.easeInOut(duration: 0.2), value: isDrawn)
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

        FirestoreManager.shared.joinDotsAndBoxesGame(username: username) { side in

            DispatchQueue.main.async {

                if let side, let dabSide = DABSide(rawValue: side) {
                    assignedSide = dabSide
                } else if retriesLeft > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        joinGame(retriesLeft: retriesLeft - 1)
                    }
                }
            }
        }
    }

    private func listenForGame() {

        FirestoreManager.shared.listenForDotsAndBoxesGame { data in

            DispatchQueue.main.async {

                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                rewardClaimed = data["rewardClaimed"] as? Bool ?? false
                gameStatus = data["status"] as? String ?? "lobby"
                horizontalLines = data["horizontalLines"] as? [Bool]
                    ?? Array(repeating: false, count: FirestoreManager.dotsAndBoxesHLineCount)
                verticalLines = data["verticalLines"] as? [Bool]
                    ?? Array(repeating: false, count: FirestoreManager.dotsAndBoxesVLineCount)
                boxOwners = data["boxOwners"] as? [String]
                    ?? Array(repeating: "", count: FirestoreManager.dotsAndBoxesBoxCount)
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

        FirestoreManager.shared.setDotsAndBoxesReady(
            side: assignedSide.rawValue,
            username: username,
            isReady: !isReady
        )
    }

    private func makeMove(isVertical: Bool, index: Int) {

        guard let assignedSide, myTurn else { return }

        let lines = isVertical ? verticalLines : horizontalLines

        guard index >= 0, index < lines.count, !lines[index] else { return }

        FirestoreManager.shared.makeDotsAndBoxesMove(
            isVertical: isVertical,
            index: index,
            mark: assignedSide.rawValue
        )
    }

    private func claimReward() {

        FirestoreManager.shared.claimDotsAndBoxesReward { didClaim in

            guard didClaim else { return }

            DispatchQueue.main.async {
                petVM.play()
                didAwardLove = true
            }
        }
    }

    private func startNewRound() {

        horizontalLines = Array(repeating: false, count: FirestoreManager.dotsAndBoxesHLineCount)
        verticalLines = Array(repeating: false, count: FirestoreManager.dotsAndBoxesVLineCount)
        boxOwners = Array(repeating: "", count: FirestoreManager.dotsAndBoxesBoxCount)
        winner = ""
        didAwardLove = false
        // Keep our assigned side and BOTH players — only the round state is
        // reset — so neither person is dropped from the lobby.
        FirestoreManager.shared.resetDotsAndBoxesGame()
    }
}

#Preview {
    DotsAndBoxesGameView(petVM: PetViewModel())
}
