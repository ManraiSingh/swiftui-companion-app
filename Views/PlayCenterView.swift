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
    @State private var showZiggyJump = false

    @ObservedObject private var themes = ThemeManager.shared

    @State private var scores: [String: Any] = [:]
    @State private var showScoreboardPopup = false
    @State private var showResetConfirm = false

    private let competitiveGames: [(id: String, title: String)] = [
        ("ticTacToe", "Tic Tac Toe"),
        ("connectFour", "Connect 4"),
        ("dotsAndBoxes", "Dots and Boxes"),
        ("memoryMatch", "Memory Match")
    ]

    var body: some View {

        ZStack {

            themes.theme.gradient
                .ignoresSafeArea()

            // Six cards plus the hero and scoreboard overflow a phone
            // screen, and without a scroll the last game was simply cut off
            // at the bottom with no way to reach it.
            ScrollView(showsIndicators: false) {

                VStack(spacing: 18) {

                    // Clears the header floating above.
                    Color.clear.frame(height: 48)

                HStack(spacing: 12) {

                    Image("ziggy_happie")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)

                    VStack(alignment: .leading, spacing: 6) {

                        Text("\(petVM.pet.name) Play Center")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(themes.theme.ink)

                        Text("Pick a tiny date-night game and make \(petVM.pet.name) very, very spoiled.")
                            .font(.subheadline)
                            .foregroundStyle(themes.theme.inkSoft)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(themes.theme.surface(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 24))

                scoreboardSummaryCard

                ziggyJumpHero

                VStack(spacing: 14) {

                    gameCard(
                        title: "Trace Together",
                        subtitle: "Draw two halves live and reveal the finished art.",
                        tint: .purple,
                        action: { showTraceGame = true }
                    ) {
                        traceTogetherIcon
                    }

                    gameCard(
                        title: "Tic Tac Toe",
                        subtitle: "A quick live match — first to line up three wins.",
                        tint: .blue,
                        action: { showTicTacToe = true }
                    ) {
                        ticTacToeIcon
                    }

                    gameCard(
                        title: "Dots and Boxes",
                        subtitle: "Draw lines, claim boxes — most boxes wins.",
                        tint: .orange,
                        action: { showDotsAndBoxes = true }
                    ) {
                        dotsAndBoxesIcon
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
                        title: "Memory Match",
                        subtitle: "Flip cards, find Ziggy's matching pairs — most pairs wins.",
                        tint: .purple,
                        action: { showMemoryMatch = true }
                    ) {
                        memoryMatchIcon
                    }
                }

                }
                .padding()
            }
            // Only scrolls when it needs to, so a short screen doesn't bounce.
            .scrollBounceBehavior(.basedOnSize)

            if showScoreboardPopup {
                scoreboardPopup
                    .zIndex(1)
            }

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
            }
        }
        .fullScreenCover(isPresented: $showZiggyJump) {
            ZiggyJumpHomeView(petVM: petVM)
                .swipeToDismiss()
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
            // The games draw a lot of their text with `.primary` and
            // `.secondary`. The app pins itself to the light scheme so the
            // worlds keep black ink, which means those resolve to black —
            // invisible once a game's own background goes dark. Handing the
            // cover the theme's scheme flips all of them at once, rather
            // than colouring some eighty labels by hand.

            DrawingGameView(
                petVM: petVM
            )
            .environment(\.colorScheme, themes.theme.colorScheme)
            .swipeToDismiss()
        }
        .fullScreenCover(
            isPresented: $showTicTacToe
        ) {

            TicTacToeGameView(
                petVM: petVM
            )
            .environment(\.colorScheme, themes.theme.colorScheme)
            .swipeToDismiss()
        }
        .fullScreenCover(
            isPresented: $showDotsAndBoxes
        ) {

            DotsAndBoxesGameView(
                petVM: petVM
            )
            .environment(\.colorScheme, themes.theme.colorScheme)
            .swipeToDismiss()
        }
        .fullScreenCover(
            isPresented: $showConnectFour
        ) {

            ConnectFourGameView(
                petVM: petVM
            )
            .environment(\.colorScheme, themes.theme.colorScheme)
            .swipeToDismiss()
        }
        .fullScreenCover(
            isPresented: $showMemoryMatch
        ) {

            MemoryMatchGameView(
                petVM: petVM
            )
            .environment(\.colorScheme, themes.theme.colorScheme)
            .swipeToDismiss()
        }
    }

    /// Deliberately unlike everything else on this screen.
    ///
    /// The five game tiles are pale pastel rows, which is right for a list you
    /// scan. Ziggy Jump is a whole game with a world of its own, and as a
    /// sixth pastel row it simply disappeared into them. So this card *is*
    /// that world — the same night sky, the same stars, Ziggy caught mid-leap
    /// over a crate. It reads as a door rather than a list item.
    private var ziggyJumpHero: some View {

        Button { showZiggyJump = true } label: {

            ZStack {

                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.24),
                        Color(red: 0.24, green: 0.17, blue: 0.40),
                        Color(red: 0.46, green: 0.26, blue: 0.44)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Scattered on the golden angle, the same way the game does
                // it, so the two skies feel like the same sky.
                Canvas { context, size in
                    for index in 0..<30 {
                        let angle = Double(index) * 2.399963
                        let x = (0.5 + 0.47 * sin(angle)) * size.width
                        let y = (Double(index) / 30.0) * size.height * 0.78
                        let r: CGFloat = index % 4 == 0 ? 1.9 : 1.1
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                                   width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(index % 4 == 0 ? 0.9 : 0.42))
                        )
                    }
                }

                HStack(spacing: 12) {

                    VStack(alignment: .leading, spacing: 6) {

                        Text("NEW")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(Color(red: 0.16, green: 0.12, blue: 0.10))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(red: 0.99, green: 0.74, blue: 0.40))
                            )

                        Text("\(petVM.pet.name) Jump")
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("Solo, or race your partner to the flag.")
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    // The whole game in one glance: him in the air, a crate
                    // underneath him.
                    ZStack(alignment: .bottom) {

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.99, green: 0.74, blue: 0.40),
                                        Color(red: 0.86, green: 0.47, blue: 0.26)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color(red: 0.30, green: 0.16, blue: 0.14),
                                            lineWidth: 1.5)
                            )
                            .frame(width: 26, height: 30)

                        // Sized so the lift still clears the crate while
                        // keeping him inside the container — the card is
                        // clipped to its corner radius, and at 78pt with a
                        // 36pt lift his ears were being cut off by the top.
                        Image("z6")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 66, height: 66)
                            .shadow(color: .white.opacity(0.22), radius: 10)
                            .offset(y: -28)
                    }
                    .frame(width: 84, height: 96)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .frame(height: 126)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(
                color: Color(red: 0.24, green: 0.14, blue: 0.44).opacity(0.5),
                radius: 16, y: 8
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {

        HStack {

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(themes.theme.ink)
                    .frame(width: 42, height: 42)
                    .background(themes.theme.surface(0.84))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Play")
                .font(.headline)
                .fontWeight(.black)
                // Nothing behind it, so it takes the theme's ink rather
                // than `.primary` — which went black-on-navy under Midnight.
                .foregroundStyle(themes.theme.ink)

            Spacer()

            Circle()
                .fill(.clear)
                .frame(width: 42, height: 42)
        }
        // Matches the inset the cards get from the scroll view's padding —
        // the header used to live in there and inherit it, and floating it
        // above left the close button pressed against the bezel.
        .padding(.horizontal, 16)
        // Enough to clear the Dynamic Island without leaving the title
        // stranded in the middle of the gap below it.
        .padding(.top, 10)
    }

    // MARK: - Game icons
    //
    // Drawn rather than set in emoji, like Connect 4 already was.
    //
    // An emoji is whatever the system font decides it is, and none of these
    // were saying which game they were: ✏️ meant "drawing" and 🧠 meant
    // "thinking", 🔲 meant almost nothing at all, and "X O" was not an emoji
    // but literal text that had to be shrunk to fit the tile. Each of these
    // shows the board you are about to play on, in the tint its row already
    // carries.

    /// Half the picture drawn, half still waiting for the other person —
    /// which is the whole game.
    private var traceTogetherIcon: some View {

        let ink = Color(red: 0.58, green: 0.36, blue: 0.88)

        return ZStack {

            Image(systemName: "heart.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ink)
                .mask(HStack(spacing: 0) { Rectangle(); Color.clear })

            Image(systemName: "heart")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ink.opacity(0.5))
                .mask(HStack(spacing: 0) { Color.clear; Rectangle() })

            // The seam the two of you meet at.
            Path { path in
                path.move(to: CGPoint(x: 1, y: 0))
                path.addLine(to: CGPoint(x: 1, y: 38))
            }
            .stroke(ink.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [3.5, 3.5]))
            .frame(width: 2, height: 38)
        }
    }

    /// A board mid-game, rather than the letters X and O.
    private var ticTacToeIcon: some View {

        let ink = Color(red: 0.29, green: 0.60, blue: 0.96)
        let cell = 14.0

        return ZStack {

            Path { path in
                for i in 1...2 {
                    let d = Double(i) * cell
                    path.move(to: CGPoint(x: d, y: 2))
                    path.addLine(to: CGPoint(x: d, y: 40))
                    path.move(to: CGPoint(x: 2, y: d))
                    path.addLine(to: CGPoint(x: 40, y: d))
                }
            }
            .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

            // One move each, so it reads as a game in progress rather than
            // an empty grid.
            Path { path in
                path.move(to: CGPoint(x: 3.5, y: 3.5))
                path.addLine(to: CGPoint(x: 10.5, y: 10.5))
                path.move(to: CGPoint(x: 10.5, y: 3.5))
                path.addLine(to: CGPoint(x: 3.5, y: 10.5))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

            Circle()
                .stroke(ink, lineWidth: 3.2)
                .frame(width: 9.5, height: 9.5)
                .position(x: 21, y: 21)

            // A third mark, low right. With only two the board read as
            // weighted into one corner.
            Circle()
                .fill(ink.opacity(0.45))
                .frame(width: 7, height: 7)
                .position(x: 35, y: 35)
        }
        .frame(width: 42, height: 42)
    }

    /// A lattice of dots with one box closed off and claimed.
    private var dotsAndBoxesIcon: some View {

        let ink = Color(red: 0.98, green: 0.60, blue: 0.16)
        let step = 15.0
        let origin = 5.0

        return ZStack {

            // The box that's been won.
            RoundedRectangle(cornerRadius: 2)
                .fill(ink.opacity(0.38))
                .frame(width: step, height: step)
                .position(x: origin + step / 2, y: origin + step / 2)

            // Its four edges, drawn — plus one lone edge in play on the far
            // side, so the whole icon isn't weighted into the top corner.
            Path { path in
                path.addRect(
                    CGRect(x: origin, y: origin, width: step, height: step)
                )
            }
            .stroke(ink, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: origin + step, y: origin + step * 2))
                path.addLine(to: CGPoint(x: origin + step * 2, y: origin + step * 2))
            }
            .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<3, id: \.self) { column in
                    Circle()
                        .fill(ink)
                        .frame(width: 5, height: 5)
                        .position(
                            x: origin + Double(column) * step,
                            y: origin + Double(row) * step
                        )
                }
            }
        }
        .frame(width: 40, height: 40)
    }

    /// A pair: one card still face down, its match turned over.
    private var memoryMatchIcon: some View {

        let ink = Color(red: 0.62, green: 0.35, blue: 0.86)

        return ZStack {

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(ink.opacity(0.32))
                .frame(width: 21, height: 29)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(ink, lineWidth: 2)
                )
                .rotationEffect(.degrees(-10))
                .offset(x: -10)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.white)
                .frame(width: 21, height: 29)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(ink, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(ink)
                )
                .rotationEffect(.degrees(10))
                .offset(x: 10)
        }
    }

    private var connectFourIcon: some View {

        HStack(spacing: -10) {

            Circle()
                .fill(Color(red: 0.90, green: 0.11, blue: 0.14))
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white, lineWidth: 2))

            Circle()
                .fill(Color(red: 1.0, green: 0.45, blue: 0.0))
                .frame(width: 28, height: 28)
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
                        .foregroundStyle(themes.theme.ink)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(themes.theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(tint)
            }
            .padding(16)
            .background(themes.theme.surface(0.86))
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
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.74, blue: 0.22))
                    .frame(width: 52, height: 52)
                    .background(Color.yellow.opacity(themes.theme.isDark ? 0.20 : 0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Scoreboard")
                        .font(.subheadline).fontWeight(.black)
                        .foregroundStyle(themes.theme.ink)

                    HStack(spacing: 6) {
                        summaryScoreChip(
                            label: "You",
                            score: myTotalWins,
                            isLeading: myTotalWins > partnerTotalWins,
                            tint: myTint
                        )
                        summaryScoreChip(
                            label: partnerDisplayName,
                            score: partnerTotalWins,
                            isLeading: partnerTotalWins > myTotalWins,
                            tint: partnerTint
                        )
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            .padding(14)
            .background(themes.theme.surface(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryScoreChip(
        label: String,
        score: Int,
        isLeading: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 4) {
            if isLeading {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.28))
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(score)")
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(isLeading ? .white : themes.theme.ink.opacity(0.6))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(isLeading ? tint : Color.black.opacity(0.06))
        )
    }

    private let myTint = Color(red: 0.95, green: 0.35, blue: 0.55)
    private let partnerTint = Color(red: 0.55, green: 0.42, blue: 0.90)

    /// The two of you side by side, with a crown on whoever's ahead.
    private var headToHeadPanel: some View {
        HStack(spacing: 8) {

            playerColumn(
                name: "You",
                score: myTotalWins,
                isLeading: myTotalWins > partnerTotalWins,
                image: myTotalWins >= partnerTotalWins ? "ziggy_loveeyes" : "ziggy_tears",
                tint: myTint
            )

            Text("VS")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(themes.theme.inkSoft)

            playerColumn(
                name: partnerDisplayName,
                score: partnerTotalWins,
                isLeading: partnerTotalWins > myTotalWins,
                image: partnerTotalWins >= myTotalWins ? "ziggy_loveeyes" : "ziggy_tears",
                tint: partnerTint
            )
        }
    }

    private func playerColumn(
        name: String,
        score: Int,
        isLeading: Bool,
        image: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 4) {

            ZStack(alignment: .topTrailing) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                if isLeading {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.28))
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .offset(x: 8, y: -6)
                }
            }

            Text(name)
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(themes.theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(score)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(tint.opacity(isLeading ? 0.16 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(tint.opacity(isLeading ? 0.5 : 0.16), lineWidth: 1.5)
        )
    }

    /// The same drawings the game cards carry, shrunk into the scoreboard's
    /// 30pt disc.
    ///
    /// Scaled rather than redrawn at a second size, so the row and the card
    /// can never drift apart. The rows were the last place still showing the
    /// old emoji — 🔲 for Dots and Boxes, 🧠 for Memory Match, and "X O",
    /// which was never an emoji at all but two letters being squeezed to fit.
    @ViewBuilder
    private func scoreIcon(_ id: String) -> some View {
        switch id {
        case "ticTacToe":    ticTacToeIcon.scaleEffect(0.52)
        case "connectFour":  connectFourIcon.scaleEffect(0.46)
        case "dotsAndBoxes": dotsAndBoxesIcon.scaleEffect(0.55)
        default:             memoryMatchIcon.scaleEffect(0.50)
        }
    }

    private func scoreRow(_ game: (id: String, title: String)) -> some View {
        let mine = wins(game.id, myUsername)
        let theirs = partnerWins(game.id)

        return HStack(spacing: 10) {

            scoreIcon(game.id)
                .frame(width: 30, height: 30)
                .background(Circle().fill(themes.theme.surface(0.8)))

            Text(game.title)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(themes.theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            scorePill(mine, isLeading: mine > theirs, tint: myTint)

            Text("–")
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(themes.theme.inkSoft)

            scorePill(theirs, isLeading: theirs > mine, tint: partnerTint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themes.theme.surface(0.55))
        )
    }

    private func scorePill(_ value: Int, isLeading: Bool, tint: Color) -> some View {
        Text("\(value)")
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(isLeading ? .white : themes.theme.ink.opacity(0.55))
            .frame(width: 30, height: 25)
            .background(
                Capsule().fill(isLeading ? tint : Color.black.opacity(0.06))
            )
    }

    private var scoreboardPopup: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showScoreboardPopup = false }
                }

            // Everything is sized to fit as one piece — four games, the
            // head-to-head panel and the buttons all land well inside even
            // the shortest iPhone, so there's nothing to scroll.
            VStack(spacing: 14) {

                Text("Scoreboard")
                    .font(.title3).fontWeight(.black)
                    .foregroundStyle(themes.theme.ink)

                headToHeadPanel

                VStack(spacing: 7) {
                    ForEach(competitiveGames, id: \.id) { game in
                        scoreRow(game)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Text("Reset")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themes.theme.surface(0.9))
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
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [myTint, partnerTint],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
            .background(themes.theme.popupSurface)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.6), lineWidth: 1)
            )
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
    }
}

#Preview {
    PlayCenterView(
        petVM: PetViewModel()
    )
}
