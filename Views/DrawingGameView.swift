import SwiftUI

private enum TraceSide: String {

    case left
    case right

    var title: String {

        switch self {

        case .left:
            return "Your half"

        case .right:
            return "Your half"
        }
    }

    var partnerTitle: String {

        switch self {

        case .left:
            return "Partner half"

        case .right:
            return "Partner half"
        }
    }
}

private struct TraceStroke: Identifiable {

    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var hexColor: String
    var width: CGFloat
    var isNormalized: Bool

    func firestoreValue(
        in boardSize: CGSize
    ) -> [String: Any] {

        [
            "points": points.map {
                [
                    "x": Double($0.x / max(boardSize.width, 1)),
                    "y": Double($0.y / max(boardSize.height, 1))
                ]
            },
            "color": hexColor,
            "width": Double(width),
            "normalized": true
        ]
    }

    init(
        points: [CGPoint],
        color: Color,
        hexColor: String,
        width: CGFloat,
        isNormalized: Bool = false
    ) {

        self.points = points
        self.color = color
        self.hexColor = hexColor
        self.width = width
        self.isNormalized = isNormalized
    }

    init?(
        data: [String: Any]
    ) {

        guard
            let pointData = data["points"] as? [[String: Any]],
            let hexColor = data["color"] as? String
        else {
            return nil
        }

        self.points = pointData.compactMap { point in

            guard
                let x = point["x"] as? Double,
                let y = point["y"] as? Double
            else {
                return nil
            }

            return CGPoint(
                x: x,
                y: y
            )
        }
        self.hexColor = hexColor
        self.color = Color(hex: hexColor)
        self.width =
            CGFloat(data["width"] as? Double ?? 12)
        self.isNormalized =
            data["normalized"] as? Bool
            ?? false
    }
}

private struct TraceTemplate {

    let name: String
    let symbol: String
    let point: (Double) -> CGPoint

    static let all: [TraceTemplate] = [

        TraceTemplate(
            name: "Heart",
            symbol: "heart.fill"
        ) { t in

            let x = 16 * pow(sin(t), 3)
            let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))

            return CGPoint(
                x: x / 18,
                y: y / 18
            )
        },

        TraceTemplate(
            name: "Star",
            symbol: "star.fill"
        ) { t in

            let points = 5.0
            let radius = 0.72 + 0.28 * cos(points * t)

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        TraceTemplate(
            name: "Moon",
            symbol: "moon.fill"
        ) { t in

            let x = 0.58 * cos(t) + 0.22 * cos(2 * t)
            let y = 0.86 * sin(t)

            return CGPoint(
                x: x,
                y: y
            )
        },

        TraceTemplate(
            name: "Flower",
            symbol: "camera.macro"
        ) { t in

            let radius = 0.38 + 0.34 * abs(sin(3 * t))

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        TraceTemplate(
            name: "Infinity",
            symbol: "infinity"
        ) { t in

            return CGPoint(
                x: 0.82 * sin(t),
                y: 0.48 * sin(2 * t)
            )
        },

        TraceTemplate(
            name: "Circle",
            symbol: "circle"
        ) { t in

            return CGPoint(
                x: cos(t),
                y: sin(t)
            )
        },

        TraceTemplate(
            name: "Diamond",
            symbol: "diamond"
        ) { t in

            let denom = abs(cos(t)) + abs(sin(t))

            return CGPoint(
                x: cos(t) / max(denom, 0.0001),
                y: sin(t) / max(denom, 0.0001)
            )
        },

        TraceTemplate(
            name: "Egg",
            symbol: "oval"
        ) { t in

            return CGPoint(
                x: 0.72 * cos(t) * (1 - 0.14 * sin(t)),
                y: sin(t)
            )
        },

        TraceTemplate(
            name: "Cloud",
            symbol: "cloud"
        ) { t in

            let radius = 0.55 + 0.2 * cos(4 * t)

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        // MARK: Harder shapes — more direction changes, tighter curves.

        TraceTemplate(
            name: "Starburst",
            symbol: "wand.and.stars"
        ) { t in

            let radius = 0.55 + 0.35 * cos(8 * t)

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        TraceTemplate(
            name: "Gear",
            symbol: "gearshape.fill"
        ) { t in

            let radius = 0.58 + 0.10 * cos(12 * t)

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        TraceTemplate(
            name: "Blossom",
            symbol: "leaf.fill"
        ) { t in

            let radius = 0.35 + 0.35 * abs(sin(5 * t))

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        TraceTemplate(
            name: "Pinwheel",
            symbol: "tornado"
        ) { t in

            let radius = 0.5 + 0.3 * cos(6 * t) + 0.15 * sin(3 * t)

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        },

        TraceTemplate(
            name: "Squiggle",
            symbol: "scribble"
        ) { t in

            return CGPoint(
                x: 0.85 * cos(t),
                y: 0.35 * sin(2 * t) + 0.35 * sin(3 * t)
            )
        },

        TraceTemplate(
            name: "Clover",
            symbol: "suit.club.fill"
        ) { t in

            let radius = 0.5 + 0.3 * pow(cos(4 * t), 3)

            return CGPoint(
                x: radius * cos(t),
                y: radius * sin(t)
            )
        }
    ]
}

private struct TraceColor: Identifiable {

    let id: String
    let color: Color
}

struct DrawingGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: TraceSide?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var leftComplete = false
    @State private var rightComplete = false
    @State private var rewardClaimed = false
    @State private var didAwardLove = false
    @State private var gameStatus = "lobby"
    @State private var traceID = 0

    @State private var myStrokes: [TraceStroke] = []
    @State private var partnerStrokes: [TraceStroke] = []
    @State private var partnerActiveStroke: TraceStroke?
    @State private var activePoints: [CGPoint] = []
    @State private var coveredSampleIndexes = Set<Int>()
    @State private var progress: CGFloat = 0

    @State private var selectedHexColor = "#FF4FA3"
    @State private var brushWidth: CGFloat = 12

    private let colors: [TraceColor] = [
        TraceColor(id: "#FF4FA3", color: .pink),
        TraceColor(id: "#9B5DE5", color: .purple),
        TraceColor(id: "#00A6FB", color: .blue),
        TraceColor(id: "#2DD4BF", color: .mint),
        TraceColor(id: "#FFD166", color: .yellow),
        TraceColor(id: "#F97316", color: .orange),
        TraceColor(id: "#EF4444", color: .red),
        TraceColor(id: "#111827", color: .black)
    ]

    private var username: String {

        UserManager.shared.username
    }

    private var template: TraceTemplate {

        TraceTemplate.all[
            min(
                max(traceID, 0),
                TraceTemplate.all.count - 1
            )
        ]
    }

    private var isReady: Bool {

        assignedSide == .left
            ? leftReady
            : rightReady
    }

    private var partnerReady: Bool {

        assignedSide == .left
            ? rightReady
            : leftReady
    }

    private var bothComplete: Bool {

        leftComplete && rightComplete
    }

    private var selectedColor: Color {

        Color(hex: selectedHexColor)
    }

    private var inviteMessage: String {

        "Come play Trace Together with me in Ziggy. Open the app, use relationship code \(RelationshipManager.shared.relationshipCode), tap Play, then press Ready."
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

                    traceBoard

                    toolBar

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

            VStack(spacing: 2) {

                Text("Trace Together")
                    .font(.title2)
                    .fontWeight(.black)

                Label(
                    template.name,
                    systemImage: template.symbol
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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

    private var lobbyView: some View {

        VStack(spacing: 18) {

            Spacer(minLength: 10)

            Image(systemName: template.symbol)
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(
                    .pink,
                    .purple.opacity(0.45)
                )
                .frame(height: 92)

            VStack(spacing: 10) {

                Text("Waiting room")
                    .font(.title)
                    .fontWeight(.black)

                Text("Invite your partner, then both of you tap Ready to start the live trace.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 10) {

                playerRow(
                    name: displayName(for: leftPlayer, isMe: assignedSide == .left),
                    side: assignedSide == .left ? "Your side" : "Left side",
                    isReady: leftReady,
                    isMe: assignedSide == .left
                )

                playerRow(
                    name: displayName(for: rightPlayer, isMe: assignedSide == .right),
                    side: assignedSide == .right ? "Your side" : "Right side",
                    isReady: rightReady,
                    isMe: assignedSide == .right
                )
            }

            templatePicker

            ShareLink(
                item: inviteMessage
            ) {
                Label(
                    "Share Invite",
                    systemImage: "square.and.arrow.up"
                )
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

    // MARK: - Shape Picker

    /// Lets either player pick a specific shape for this round — visible to
    /// both instantly. Leave it untouched and the round stays whatever random
    /// shape was already assigned; tapping 🎲 re-rolls a new random one.
    private var templatePicker: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Pick a shape (optional)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: 8) {

                    Button {
                        var newIndex = Int.random(in: 0..<TraceTemplate.all.count)
                        if TraceTemplate.all.count > 1 {
                            while newIndex == traceID {
                                newIndex = Int.random(in: 0..<TraceTemplate.all.count)
                            }
                        }
                        FirestoreManager.shared.setTraceTemplateChoice(index: newIndex)
                    } label: {
                        templateChip(symbol: "shuffle", name: "Random", isSelected: false)
                    }
                    .buttonStyle(.plain)

                    ForEach(Array(TraceTemplate.all.enumerated()), id: \.offset) { index, item in
                        Button {
                            FirestoreManager.shared.setTraceTemplateChoice(index: index)
                        } label: {
                            templateChip(
                                symbol: item.symbol,
                                name: item.name,
                                isSelected: index == traceID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func templateChip(symbol: String, name: String, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
            Text(name)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(isSelected ? .white : .primary)
        .frame(width: 64)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.pink : Color.white.opacity(0.85))
        )
    }

    private func displayName(for player: String, isMe: Bool) -> String {
        if !player.isEmpty {
            return isMe ? "\(player) (You)" : player
        }
        return isMe ? "You" : "Waiting for partner…"
    }

    private func playerRow(
        name: String,
        side: String,
        isReady: Bool,
        isMe: Bool
    ) -> some View {

        HStack {

            VStack(alignment: .leading, spacing: 2) {

                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(side)
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
        .background(isMe ? Color.pink.opacity(0.12) : Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMe ? Color.pink.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
    }

    private var liveStatusPanel: some View {

        VStack(spacing: 10) {

            HStack {

                statusPill(
                    title: "\(Int(progress * 100))% yours",
                    systemImage: "pencil.and.outline",
                    isComplete: mySideComplete
                )

                statusPill(
                    title: partnerCompleteText,
                    systemImage: "person.2.fill",
                    isComplete: partnerSideComplete
                )
            }

            ProgressView(value: progress)
                .tint(selectedColor)
        }
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var mySideComplete: Bool {

        assignedSide == .left
            ? leftComplete
            : rightComplete
    }

    private var partnerSideComplete: Bool {

        assignedSide == .left
            ? rightComplete
            : leftComplete
    }

    private var partnerCompleteText: String {

        partnerSideComplete
            ? "Partner done"
            : "Partner drawing"
    }

    private func statusPill(
        title: String,
        systemImage: String,
        isComplete: Bool
    ) -> some View {

        HStack(spacing: 6) {

            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.caption)
        .fontWeight(.bold)
        .foregroundColor(isComplete ? .green : .primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.75))
        .clipShape(Capsule())
    }

    private func sideBadge(text: String, mine: Bool) -> some View {

        Text(text)
            .font(.caption2)
            .fontWeight(.black)
            .foregroundColor(mine ? .white : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(mine ? selectedColor : Color.white.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    private var traceBoard: some View {

        GeometryReader { geometry in

            let size = geometry.size

            Canvas { context, canvasSize in

                guard let assignedSide else {
                    return
                }

                if !bothComplete {

                    // Tint the half you should trace so it's obvious which
                    // side is yours.
                    let myRect: CGRect = assignedSide == .left
                        ? CGRect(x: 0, y: 0,
                                 width: canvasSize.width / 2,
                                 height: canvasSize.height)
                        : CGRect(x: canvasSize.width / 2, y: 0,
                                 width: canvasSize.width / 2,
                                 height: canvasSize.height)

                    context.fill(
                        Path(myRect),
                        with: .color(selectedColor.opacity(0.09))
                    )

                    drawGuide(
                        side: .left,
                        isMine: assignedSide == .left,
                        in: &context,
                        canvasSize: canvasSize
                    )

                    drawGuide(
                        side: .right,
                        isMine: assignedSide == .right,
                        in: &context,
                        canvasSize: canvasSize
                    )
                }

                drawStrokes(
                    partnerStrokes,
                    opacity: 0.82,
                    canvasSize: canvasSize,
                    in: &context
                )

                if let partnerActiveStroke {
                    drawStrokes(
                        [partnerActiveStroke],
                        opacity: 0.82,
                        canvasSize: canvasSize,
                        in: &context
                    )
                }

                drawStrokes(
                    myStrokes,
                    opacity: 1,
                    canvasSize: canvasSize,
                    in: &context
                )

                if !activePoints.isEmpty {

                    drawStrokes(
                        [
                            TraceStroke(
                                points: activePoints,
                                color: selectedColor,
                                hexColor: selectedHexColor,
                                width: brushWidth
                            )
                        ],
                        opacity: 1,
                        canvasSize: canvasSize,
                        in: &context
                    )
                }

                if !bothComplete {

                    drawDivider(
                        in: &context,
                        size: canvasSize
                    )
                }

                if bothComplete {
                    drawCompleteGlow(
                        in: &context,
                        canvasSize: canvasSize
                    )
                }

                _ = assignedSide
            }
            .frame(
                width: size.width,
                height: size.height
            )
            .background(.white.opacity(0.38))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(alignment: .top) {

                if bothComplete {

                    Text("Complete Drawing")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.35))
                        .clipShape(Capsule())
                        .padding(.top, 14)
                }
            }
            .overlay(alignment: .topLeading) {

                if let assignedSide, !bothComplete {
                    sideBadge(
                        text: assignedSide == .left ? "You ✏️" : "Partner",
                        mine: assignedSide == .left
                    )
                    .padding(12)
                }
            }
            .overlay(alignment: .topTrailing) {

                if let assignedSide, !bothComplete {
                    sideBadge(
                        text: assignedSide == .right ? "You ✏️" : "Partner",
                        mine: assignedSide == .right
                    )
                    .padding(12)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        addPoint(
                            value.location,
                            boardSize: size
                        )
                    }
                    .onEnded { _ in
                        finishStroke(
                            boardSize: size
                        )
                    }
            )
        }
        .frame(minHeight: 320)
    }

    private var toolBar: some View {

        VStack(spacing: 12) {

            HStack {

                ForEach(colors) { traceColor in

                    Button {
                        selectedHexColor = traceColor.id
                    } label: {
                        Circle()
                            .fill(traceColor.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if selectedHexColor == traceColor.id {
                                    Circle()
                                        .stroke(.white, lineWidth: 4)
                                }
                            }
                            .shadow(radius: selectedHexColor == traceColor.id ? 5 : 0)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {

                Image(systemName: "pencil.tip")

                Slider(
                    value: $brushWidth,
                    in: 6...22
                )

                Image(systemName: "paintbrush.pointed.fill")
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var gameActionPanel: some View {

        VStack(spacing: 10) {

            if bothComplete {

                Text("Both halves are finished.")
                    .font(.headline)

                if didAwardLove || rewardClaimed {

                    HStack {

                        Button {
                            startNewRound()
                        } label: {
                            Text("New Trace")
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
                        Text("Complete Game")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.pink)
                            .clipShape(Capsule())
                    }
                }

            } else if mySideComplete {

                Text("Your half is done. You can watch your partner finish live.")
                    .font(.headline)
                    .multilineTextAlignment(.center)

            } else {

                Button {
                    submitMyHalf()
                } label: {
                    Text("Finish My Half")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(progress >= 0.72 ? selectedColor : .gray)
                        .clipShape(Capsule())
                }
                .disabled(progress < 0.72 || assignedSide == nil)
            }
        }
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func joinGame(retriesLeft: Int = 2) {

        FirestoreManager.shared.joinTraceGame(
            username: username
        ) { side in

            DispatchQueue.main.async {

                if let side,
                   let traceSide = TraceSide(rawValue: side) {
                    assignedSide = traceSide
                } else if retriesLeft > 0 {
                    // Transient failure (network/transaction) — retry so we
                    // don't get stuck with a disabled Ready button.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        joinGame(retriesLeft: retriesLeft - 1)
                    }
                }
            }
        }
    }

    private func listenForGame() {

        FirestoreManager.shared.listenForTraceGame { data in

            DispatchQueue.main.async {

                leftPlayer =
                    data["leftPlayer"] as? String
                    ?? ""
                rightPlayer =
                    data["rightPlayer"] as? String
                    ?? ""
                leftReady =
                    data["leftReady"] as? Bool
                    ?? false
                rightReady =
                    data["rightReady"] as? Bool
                    ?? false
                leftComplete =
                    data["leftComplete"] as? Bool
                    ?? false
                rightComplete =
                    data["rightComplete"] as? Bool
                    ?? false
                rewardClaimed =
                    data["rewardClaimed"] as? Bool
                    ?? false
                gameStatus =
                    data["status"] as? String
                    ?? "lobby"
                traceID =
                    data["traceID"] as? Int
                    ?? 0

                // Recover our side from the snapshot if the join callback was
                // slow or failed — prevents "both in lobby but can't Ready".
                if assignedSide == nil {
                    if leftPlayer == username {
                        assignedSide = .left
                    } else if rightPlayer == username {
                        assignedSide = .right
                    }
                }

                updateStrokes(from: data)
            }
        }
    }

    private func toggleReady() {

        guard let assignedSide else {
            return
        }

        FirestoreManager.shared.setTraceGameReady(
            side: assignedSide.rawValue,
            username: username,
            isReady: !isReady
        )
    }

    private func addPoint(
        _ point: CGPoint,
        boardSize: CGSize
    ) {

        guard let assignedSide,
              gameStatus == "playing",
              !mySideComplete,
              !bothComplete,
              pointIsInMyHalf(point, size: boardSize)
        else {
            return
        }

        activePoints.append(point)

        let samples = guideSamples(
            for: assignedSide,
            in: boardSize,
            count: 120
        )

        for (index, sample) in samples.enumerated() {

            if distance(
                from: point,
                to: sample
            ) < 30 {
                coveredSampleIndexes.insert(index)
            }
        }

        progress = min(
            CGFloat(coveredSampleIndexes.count)
            / CGFloat(samples.count),
            1
        )

        if activePoints.count % 4 == 0 {
            publishActiveStroke(
                boardSize: boardSize
            )
        }
    }

    private func finishStroke(
        boardSize: CGSize
    ) {

        guard let assignedSide,
              activePoints.count > 1
        else {
            activePoints = []
            return
        }

        let stroke = TraceStroke(
            points: activePoints,
            color: selectedColor,
            hexColor: selectedHexColor,
            width: brushWidth
        )

        myStrokes.append(stroke)
        activePoints = []

        FirestoreManager.shared.addTraceStroke(
            side: assignedSide.rawValue,
            stroke: stroke.firestoreValue(
                in: boardSize
            )
        )

        FirestoreManager.shared.updateActiveTraceStroke(
            side: assignedSide.rawValue,
            stroke: [
                "points": [],
                "color": selectedHexColor,
                "width": Double(brushWidth),
                "normalized": true
            ]
        )
    }

    private func submitMyHalf() {

        guard let assignedSide else {
            return
        }

        FirestoreManager.shared.markTraceGameComplete(
            side: assignedSide.rawValue,
            by: username
        )
    }

    private func claimReward() {

        FirestoreManager.shared.claimTraceGameReward { didClaim in

            guard didClaim else {
                return
            }

            DispatchQueue.main.async {
                petVM.play()
                didAwardLove = true
            }
        }
    }

    private func startNewRound() {

        resetMyDrawing()
        partnerActiveStroke = nil
        didAwardLove = false
        // Keep our assigned side and BOTH players — only the round state is
        // reset — so neither person is dropped from the lobby.
        FirestoreManager.shared.resetTraceGame()
    }

    private func resetMyDrawing() {

        myStrokes = []
        partnerStrokes = []
        activePoints = []
        coveredSampleIndexes = []
        progress = 0
    }

    private func updateStrokes(from data: [String: Any]) {

        guard let assignedSide else {
            return
        }

        let myKey =
            assignedSide == .left
            ? "leftStrokes"
            : "rightStrokes"
        let partnerKey =
            assignedSide == .left
            ? "rightStrokes"
            : "leftStrokes"

        myStrokes =
            (data[myKey] as? [[String: Any]] ?? [])
            .compactMap {
                TraceStroke(data: $0)
            }

        partnerStrokes =
            (data[partnerKey] as? [[String: Any]] ?? [])
            .compactMap {
                TraceStroke(data: $0)
            }

        let partnerActiveKey =
            assignedSide == .left
            ? "rightActiveStroke"
            : "leftActiveStroke"

        if let activeData = data[partnerActiveKey] as? [String: Any],
           let activeStroke = TraceStroke(data: activeData),
           !activeStroke.points.isEmpty {

            partnerActiveStroke = activeStroke

        } else {

            partnerActiveStroke = nil
        }
    }

    private func publishActiveStroke(
        boardSize: CGSize
    ) {

        guard let assignedSide,
              activePoints.count > 1
        else {
            return
        }

        let stroke = TraceStroke(
            points: activePoints,
            color: selectedColor,
            hexColor: selectedHexColor,
            width: brushWidth
        )

        FirestoreManager.shared.updateActiveTraceStroke(
            side: assignedSide.rawValue,
            stroke: stroke.firestoreValue(
                in: boardSize
            )
        )
    }

    private func pointIsInMyHalf(
        _ point: CGPoint,
        size: CGSize
    ) -> Bool {

        guard let assignedSide else {
            return false
        }

        switch assignedSide {

        case .left:
            return point.x <= size.width / 2

        case .right:
            return point.x >= size.width / 2
        }
    }

    private func drawGuide(
        side: TraceSide,
        isMine: Bool,
        in context: inout GraphicsContext,
        canvasSize: CGSize
    ) {

        let samples = guideSamples(
            for: side,
            in: canvasSize,
            count: 140
        )

        var guidePath = Path()

        if let first = samples.first {
            guidePath.move(to: first)
        }

        for point in samples.dropFirst() {
            guidePath.addLine(to: point)
        }

        if isMine {

            // Bright, inviting guide on the half YOU should trace.
            context.stroke(
                guidePath,
                with: .color(.white),
                style: StrokeStyle(
                    lineWidth: 18,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [6, 10]
                )
            )

            context.stroke(
                guidePath,
                with: .color(selectedColor.opacity(0.6)),
                style: StrokeStyle(
                    lineWidth: 5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [6, 10]
                )
            )

        } else {

            // Faint, greyed guide on your partner's half.
            context.stroke(
                guidePath,
                with: .color(.white.opacity(0.5)),
                style: StrokeStyle(
                    lineWidth: 12,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [6, 10]
                )
            )

            context.stroke(
                guidePath,
                with: .color(.gray.opacity(0.28)),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [6, 10]
                )
            )
        }
    }

    private func drawStrokes(
        _ strokes: [TraceStroke],
        opacity: Double,
        canvasSize: CGSize,
        in context: inout GraphicsContext
    ) {

        for stroke in strokes {

            var path = Path()
            let points = stroke.points.map {
                displayPoint(
                    $0,
                    isNormalized: stroke.isNormalized,
                    canvasSize: canvasSize
                )
            }

            if let first = points.first {
                path.move(to: first)
            }

            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .color(stroke.color.opacity(opacity)),
                style: StrokeStyle(
                    lineWidth: stroke.width,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func displayPoint(
        _ point: CGPoint,
        isNormalized: Bool,
        canvasSize: CGSize
    ) -> CGPoint {

        guard isNormalized else {
            return point
        }

        return CGPoint(
            x: point.x * canvasSize.width,
            y: point.y * canvasSize.height
        )
    }

    private func drawDivider(
        in context: inout GraphicsContext,
        size: CGSize
    ) {

        var divider = Path()

        divider.move(
            to: CGPoint(
                x: size.width / 2,
                y: 28
            )
        )
        divider.addLine(
            to: CGPoint(
                x: size.width / 2,
                y: size.height - 28
            )
        )

        context.stroke(
            divider,
            with: .color(.black.opacity(0.12)),
            style: StrokeStyle(
                lineWidth: 2,
                dash: [8, 8]
            )
        )
    }

    private func drawCompleteGlow(
        in context: inout GraphicsContext,
        canvasSize: CGSize
    ) {

        let rect = CGRect(
            origin: .zero,
            size: canvasSize
        ).insetBy(
            dx: 12,
            dy: 12
        )

        let path = Path(
            roundedRect: rect,
            cornerRadius: 24
        )

        context.stroke(
            path,
            with: .color(.green.opacity(0.45)),
            lineWidth: 8
        )
    }

    private func guideSamples(
        for side: TraceSide,
        in size: CGSize,
        count: Int
    ) -> [CGPoint] {

        let rawPoints = (0...360).compactMap { degree -> CGPoint? in

            let t = Double(degree) * .pi / 180
            let point = template.point(t)

            if side == .left && point.x > 0 {
                return nil
            }

            if side == .right && point.x < 0 {
                return nil
            }

            return point
        }

        let sortedPoints: [CGPoint] =
            side == .left
            ? rawPoints
            : Array(rawPoints.reversed())

        let center = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )
        let scale = min(
            size.width,
            size.height
        ) * 0.38

        let points = sortedPoints.map { point in

            CGPoint(
                x: center.x + point.x * scale,
                y: center.y + point.y * scale
            )
        }

        guard points.count > count else {
            return points
        }

        let step = max(
            points.count / count,
            1
        )

        return stride(
            from: 0,
            to: points.count,
            by: step
        ).map {
            points[$0]
        }
    }

    private func distance(
        from first: CGPoint,
        to second: CGPoint
    ) -> CGFloat {

        sqrt(
            pow(first.x - second.x, 2)
            + pow(first.y - second.y, 2)
        )
    }
}

private extension Color {

    init(hex: String) {

        let cleanedHex =
            hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var value: UInt64 = 0
        Scanner(string: cleanedHex)
            .scanHexInt64(&value)

        let red =
            Double((value >> 16) & 0xFF) / 255
        let green =
            Double((value >> 8) & 0xFF) / 255
        let blue =
            Double(value & 0xFF) / 255

        self.init(
            red: red,
            green: green,
            blue: blue
        )
    }
}

#Preview {
    DrawingGameView(
        petVM: PetViewModel()
    )
}
