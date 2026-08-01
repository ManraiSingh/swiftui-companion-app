import SwiftUI

struct PlayCenterView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var showTraceGame = false
    @State private var showTicTacToe = false
    @State private var showDotsAndBoxes = false
    @State private var showConnectFour = false
    @State private var showMemoryMatch = false

    @State private var scores: [String: Any] = [:]
    @State private var showScoreboardPopup = false
    @State private var showResetConfirm = false

    private let competitiveGames: [(id: String, title: String, emoji: String)] = [
        ("ticTacToe", "Tic Tac Toe", "X O"),
        ("connectFour", "Connect 4", "🔴🟡"),
        ("dotsAndBoxes", "Dots and Boxes", "🔲"),
        ("memoryMatch", "Memory Match", "🧠")
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

            VStack(spacing: 18) {

                header

                HStack(spacing: 12) {

                    Image("ziggy_happie")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)

                    VStack(alignment: .leading, spacing: 6) {

                        Text("\(petVM.pet.name) Play Center")
                            .font(.title2)
                            .fontWeight(.black)

                        Text("Pick a tiny date-night game and make \(petVM.pet.name) very, very spoiled.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 24))

                scoreboardSummaryCard

                VStack(spacing: 14) {

                    gameCard(
                        emoji: "✏️",
                        title: "Trace Together",
                        subtitle: "Draw two halves live and reveal the finished art.",
                        tint: .purple
                    ) {
                        showTraceGame = true
                    }

                    gameCard(
                        emoji: "X O",
                        title: "Tic Tac Toe",
                        subtitle: "A quick live match — first to line up three wins.",
                        tint: .blue
                    ) {
                        showTicTacToe = true
                    }

                    gameCard(
                        emoji: "🔲",
                        title: "Dots and Boxes",
                        subtitle: "Draw lines, claim boxes — most boxes wins.",
                        tint: .orange
                    ) {
                        showDotsAndBoxes = true
                    }

                    gameCard(
                        title: "Connect 4",
                        subtitle: "Drop pieces and line up four in a row to win.",
                        tint: .red,
                        action: { showConnectFour = true }
                    ) {
                        connectFourIcon
                    }

                    gameCard(
                        emoji: "🧠",
                        title: "Memory Match",
                        subtitle: "Flip cards, find Ziggy's matching pairs — most pairs wins.",
                        tint: .purple
                    ) {
                        showMemoryMatch = true
                    }
                }

                Spacer()
            }
            .padding()

            if showScoreboardPopup {
                scoreboardPopup
                    .zIndex(1)
            }
        }
        .onAppear {
            FirestoreManager.shared.listenForScores { data in
                DispatchQueue.main.async {
                    scores = data ?? [:]
                }
            }
        }
        .onDisappear {
            FirestoreManager.shared.stopScoresListener()
        }
        .alert("Reset scores?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                FirestoreManager.shared.resetAllScores()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears every game's win count for both of you. It can't be undone.")
        }
        .fullScreenCover(
            isPresented: $showTraceGame
        ) {

            DrawingGameView(
                petVM: petVM
            )
        }
        .fullScreenCover(
            isPresented: $showTicTacToe
        ) {

            TicTacToeGameView(
                petVM: petVM
            )
        }
        .fullScreenCover(
            isPresented: $showDotsAndBoxes
        ) {

            DotsAndBoxesGameView(
                petVM: petVM
            )
        }
        .fullScreenCover(
            isPresented: $showConnectFour
        ) {

            ConnectFourGameView(
                petVM: petVM
            )
        }
        .fullScreenCover(
            isPresented: $showMemoryMatch
        ) {

            MemoryMatchGameView(
                petVM: petVM
            )
        }
    }

    private var header: some View {

        HStack {

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.84))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Play")
                .font(.headline)
                .fontWeight(.black)

            Spacer()

            Circle()
                .fill(.clear)
                .frame(width: 42, height: 42)
        }
        .padding(.top, 24)
    }

    private func gameCard(
        emoji: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {

        gameCard(title: title, subtitle: subtitle, tint: tint, action: action) {

            Text(emoji)
                .font(.system(size: 38, weight: .black))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
    }

    private var connectFourIcon: some View {

        HStack(spacing: -10) {

            Circle()
                .fill(Color(red: 0.90, green: 0.11, blue: 0.14))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white, lineWidth: 2))

            Circle()
                .fill(Color(red: 1.0, green: 0.45, blue: 0.0))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
    }

    private func gameCard<Icon: View>(
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 14) {

                icon()
                    .frame(width: 64, height: 64)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 5) {

                    Text(title)
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(tint)
            }
            .padding(16)
            .background(.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(tint.opacity(0.18), lineWidth: 1.5)
            )
            .shadow(
                color: tint.opacity(0.14),
                radius: 12,
                y: 6
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scoreboard

    private var myUsername: String { UserManager.shared.username }

    private func wins(_ gameID: String, _ username: String) -> Int {
        (scores[gameID] as? [String: Any])?[username] as? Int ?? 0
    }

    private func partnerWins(_ gameID: String) -> Int {
        guard let map = scores[gameID] as? [String: Any] else { return 0 }
        return map.reduce(0) { total, entry in
            entry.key == myUsername ? total : total + ((entry.value as? Int) ?? 0)
        }
    }

    // The other name that shows up in any game's score map, if one exists
    // yet — falls back to a generic label before anyone's won a round.
    private var partnerDisplayName: String {
        for game in competitiveGames {
            if let map = scores[game.id] as? [String: Any],
               let name = map.keys.first(where: { $0 != myUsername }) {
                return name
            }
        }
        return "Partner"
    }

    private var myTotalWins: Int {
        competitiveGames.reduce(0) { $0 + wins($1.id, myUsername) }
    }

    private var partnerTotalWins: Int {
        competitiveGames.reduce(0) { $0 + partnerWins($1.id) }
    }

    private var scoreboardSummaryCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showScoreboardPopup = true
            }
        } label: {
            HStack(spacing: 14) {
                Text("🏆")
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(Color.yellow.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Scoreboard")
                        .font(.subheadline).fontWeight(.black)
                        .foregroundStyle(.primary)
                    Text("You \(myTotalWins) — \(partnerTotalWins) \(partnerDisplayName)")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            .padding(14)
            .background(.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func scoreRow(_ game: (id: String, title: String, emoji: String)) -> some View {
        let mine = wins(game.id, myUsername)
        let theirs = partnerWins(game.id)

        return HStack(spacing: 12) {
            Text(game.emoji)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(game.title)
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(mine)")
                .font(.headline).fontWeight(.black)
                .foregroundStyle(mine > theirs ? .pink : .secondary)

            Text("–")
                .foregroundStyle(.secondary)

            Text("\(theirs)")
                .font(.headline).fontWeight(.black)
                .foregroundStyle(theirs > mine ? .pink : .secondary)
        }
        .padding(.vertical, 6)
    }

    private var scoreboardPopup: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showScoreboardPopup = false }
                }

            VStack(spacing: 18) {
                Text("Scoreboard 🏆")
                    .font(.title3).fontWeight(.black)

                VStack(spacing: 4) {
                    ForEach(competitiveGames, id: \.id) { game in
                        scoreRow(game)
                        if game.id != competitiveGames.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 12) {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Text("Reset Scores")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.9))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 1))
                    }

                    Button {
                        withAnimation { showScoreboardPopup = false }
                    } label: {
                        Text("Close")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}

#Preview {
    PlayCenterView(
        petVM: PetViewModel()
    )
}
