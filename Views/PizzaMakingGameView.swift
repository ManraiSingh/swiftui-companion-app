import SwiftUI

private enum PizzaSide: String {

    case left
    case right
}

private struct PizzaRecipe {

    let id: Int
    let name: String
    let mood: String
    let base: String
    let sauce: String
    let cheese: String
    let toppings: [String]

    static let all: [PizzaRecipe] = [
        PizzaRecipe(
            id: 0,
            name: "Garden Cuddle Pizza",
            mood: "I want something cozy and green today.",
            base: "Classic",
            sauce: "Tomato",
            cheese: "Mozzarella",
            toppings: ["Mushroom", "Olive", "Pepper"]
        ),
        PizzaRecipe(
            id: 1,
            name: "Sunny Picnic Pizza",
            mood: "Make it bright, crunchy, and happy.",
            base: "Thin",
            sauce: "Pesto",
            cheese: "Mozzarella",
            toppings: ["Corn", "Pepper", "Tomato"]
        ),
        PizzaRecipe(
            id: 2,
            name: "Sleepy Cheese Cloud",
            mood: "I want a soft cheesy pizza before my nap.",
            base: "Cheesy Crust",
            sauce: "Tomato",
            cheese: "Cheddar",
            toppings: ["Mushroom", "Tomato"]
        ),
        PizzaRecipe(
            id: 3,
            name: "Spicy Love Slice",
            mood: "Make me a tiny dramatic pizza.",
            base: "Classic",
            sauce: "Spicy",
            cheese: "Cheddar",
            toppings: ["Jalapeno", "Olive", "Corn"]
        )
    ]
}

private struct PizzaChoice: Identifiable {

    let id: String
    let emoji: String
}

struct PizzaMakingGameView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var assignedSide: PizzaSide?
    @State private var leftPlayer = ""
    @State private var rightPlayer = ""
    @State private var leftReady = false
    @State private var rightReady = false
    @State private var status = "lobby"
    @State private var recipeID = 0
    @State private var base = ""
    @State private var sauce = ""
    @State private var cheese = ""
    @State private var toppings: [String] = []
    @State private var isBaked = false
    @State private var isFed = false
    @State private var rewardClaimed = false
    @State private var lastChef = ""
    @State private var pizzaOffset = CGSize.zero
    @State private var isEating = false
    @State private var didAward = false

    private let bases: [PizzaChoice] = [
        PizzaChoice(id: "Classic", emoji: "🥖"),
        PizzaChoice(id: "Thin", emoji: "🫓"),
        PizzaChoice(id: "Cheesy Crust", emoji: "🧀")
    ]
    private let sauces: [PizzaChoice] = [
        PizzaChoice(id: "Tomato", emoji: "🍅"),
        PizzaChoice(id: "Pesto", emoji: "🌿"),
        PizzaChoice(id: "Spicy", emoji: "🌶️")
    ]
    private let cheeses: [PizzaChoice] = [
        PizzaChoice(id: "Mozzarella", emoji: "🤍"),
        PizzaChoice(id: "Cheddar", emoji: "🧡")
    ]
    private let allToppings: [PizzaChoice] = [
        PizzaChoice(id: "Mushroom", emoji: "🍄"),
        PizzaChoice(id: "Olive", emoji: "🫒"),
        PizzaChoice(id: "Pepper", emoji: "🫑"),
        PizzaChoice(id: "Corn", emoji: "🌽"),
        PizzaChoice(id: "Tomato", emoji: "🍅"),
        PizzaChoice(id: "Jalapeno", emoji: "🌶️")
    ]

    private var username: String {

        UserManager.shared.username
    }

    private var recipe: PizzaRecipe {

        PizzaRecipe.all[
            min(
                max(recipeID, 0),
                PizzaRecipe.all.count - 1
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

    private var recipeMatches: Bool {

        base == recipe.base
            && sauce == recipe.sauce
            && cheese == recipe.cheese
            && Set(toppings) == Set(recipe.toppings)
    }

    private var matchScore: Int {

        var score = 0

        if base == recipe.base { score += 1 }
        if sauce == recipe.sauce { score += 1 }
        if cheese == recipe.cheese { score += 1 }

        let selected = Set(toppings)
        let needed = Set(recipe.toppings)
        score += selected.intersection(needed).count
        score -= selected.subtracting(needed).count

        return max(
            0,
            score
        )
    }

    private var maxScore: Int {

        3 + recipe.toppings.count
    }

    private var ziggyMessage: String {

        if isEating {
            return "nom nom nom... this is perfect 🍕"
        }

        if isFed || rewardClaimed {
            return "My heart and tummy are full."
        }

        if isBaked {
            return recipeMatches
                ? "Drag it to me. I can smell the love."
                : "It smells nice, but something is not my order."
        }

        if matchScore == 0 {
            return recipe.mood
        }

        if recipeMatches {
            return "That is exactly what I asked for."
        }

        return "Almost. I am watching the toppings very closely."
    }

    private var ziggyImage: String {

        if isEating || isFed || recipeMatches {
            return "ziggy_loveeyes"
        }

        if isBaked && !recipeMatches {
            return "ziggu_cry"
        }

        if matchScore >= maxScore - 1 {
            return "ziggy_happie"
        }

        return "ziggy_sleep"
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.93, blue: 0.86),
                    Color(red: 0.94, green: 0.98, blue: 0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {

                header

                if status == "lobby" {

                    lobby

                } else {

                    kitchen
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
                    .background(.white.opacity(0.86))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {

                Text("Pizza for Ziggy")
                    .font(.headline)
                    .fontWeight(.black)

                Text(recipe.name)
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
                    .background(.white.opacity(0.86))
                    .clipShape(Circle())
            }
        }
    }

    private var lobby: some View {

        VStack(spacing: 18) {

            Spacer(minLength: 8)

            Image("ziggy_happie")
                .resizable()
                .scaledToFit()
                .frame(height: 140)

            Text("Ziggy's Pizza Date")
                .font(.title2)
                .fontWeight(.black)

            Text("Both chefs need to be ready. Then you will make Ziggy's secret pizza order together.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {

                playerRow(
                    name: leftPlayer.isEmpty ? "You" : leftPlayer,
                    title: "Chef one",
                    isReady: leftReady
                )

                playerRow(
                    name: rightPlayer.isEmpty ? "Waiting for partner" : rightPlayer,
                    title: "Chef two",
                    isReady: rightReady
                )
            }

            Button {
                toggleReady()
            } label: {
                Label(
                    isReady ? "Ready" : "I'm Ready",
                    systemImage: isReady ? "checkmark.circle.fill" : "fork.knife.circle.fill"
                )
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isReady ? .green : .orange)
                .clipShape(Capsule())
            }
            .disabled(assignedSide == nil)

            if isReady && !partnerReady {
                Text("You are ready. Waiting for your partner chef.")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func playerRow(
        name: String,
        title: String,
        isReady: Bool
    ) -> some View {

        HStack {

            VStack(alignment: .leading, spacing: 2) {

                Text(name)
                    .font(.headline)
                    .lineLimit(1)

                Text(title)
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

    private var kitchen: some View {

        ScrollView(showsIndicators: false) {

            VStack(spacing: 14) {

                ziggyPanel

                recipeCard

                pizzaStage

                ingredientSection(
                    title: "Base",
                    choices: bases,
                    selected: [base]
                ) { choice in
                    choose(
                        key: "base",
                        value: choice.id
                    )
                }

                ingredientSection(
                    title: "Sauce",
                    choices: sauces,
                    selected: [sauce]
                ) { choice in
                    choose(
                        key: "sauce",
                        value: choice.id
                    )
                }

                ingredientSection(
                    title: "Cheese",
                    choices: cheeses,
                    selected: [cheese]
                ) { choice in
                    choose(
                        key: "cheese",
                        value: choice.id
                    )
                }

                ingredientSection(
                    title: "Toppings",
                    choices: allToppings,
                    selected: toppings
                ) { choice in
                    toggleTopping(choice.id)
                }

                actionArea
            }
            .padding(.bottom, 20)
        }
    }

    private var ziggyPanel: some View {

        HStack(spacing: 14) {

            Image(ziggyImage)
                .resizable()
                .scaledToFit()
                .frame(width: 94, height: 94)
                .scaleEffect(isEating ? 1.08 : 1)
                .animation(
                    .spring(response: 0.22, dampingFraction: 0.45),
                    value: isEating
                )

            VStack(alignment: .leading, spacing: 8) {

                Text(ziggyMessage)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Recipe match: \(matchScore)/\(maxScore)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var recipeCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Ziggy asked for")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text(recipe.name)
                .font(.title3)
                .fontWeight(.black)

            HStack {
                recipeChip(recipe.base)
                recipeChip(recipe.sauce)
                recipeChip(recipe.cheese)
            }

            FlowLayout(spacing: 8) {
                ForEach(recipe.toppings, id: \.self) { topping in
                    recipeChip(topping)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func recipeChip(
        _ text: String
    ) -> some View {

        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.orange.opacity(0.14))
            .clipShape(Capsule())
    }

    private var pizzaStage: some View {

        ZStack {

            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.76))

            VStack(spacing: 10) {

                pizzaVisual
                    .offset(pizzaOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard isBaked,
                                      recipeMatches,
                                      !isFed
                                else { return }
                                pizzaOffset = value.translation
                            }
                            .onEnded { value in
                                guard isBaked,
                                      recipeMatches,
                                      !isFed
                                else {
                                    pizzaOffset = .zero
                                    return
                                }

                                if value.translation.height < -100 {
                                    feedPizza()
                                } else {
                                    withAnimation(.spring()) {
                                        pizzaOffset = .zero
                                    }
                                }
                            }
                    )

                Text(isBaked ? "Fresh from the oven" : "Build together on the counter")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
        }
        .frame(height: 220)
    }

    private var pizzaVisual: some View {

        ZStack {

            Circle()
                .fill(base.isEmpty ? .brown.opacity(0.20) : .orange.opacity(0.42))
                .frame(width: 158, height: 158)
                .overlay(
                    Circle()
                        .stroke(.brown.opacity(0.28), lineWidth: base == "Cheesy Crust" ? 12 : 6)
                )

            if !sauce.isEmpty {
                Circle()
                    .fill(sauceColor.opacity(0.72))
                    .frame(width: 128, height: 128)
            }

            if !cheese.isEmpty {
                Circle()
                    .fill(cheese == "Cheddar" ? .orange.opacity(0.34) : .white.opacity(0.62))
                    .frame(width: 108, height: 108)
            }

            ForEach(Array(toppings.enumerated()), id: \.offset) { index, topping in

                Text(toppingEmoji(topping))
                    .font(.title3)
                    .offset(toppingOffset(index))
            }

            if isBaked {
                Circle()
                    .stroke(.orange.opacity(0.55), lineWidth: 5)
                    .frame(width: 164, height: 164)
            }
        }
        .scaleEffect(isEating ? 0.15 : 1)
        .opacity(isFed ? 0 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isEating)
        .animation(.easeOut(duration: 0.3), value: isFed)
    }

    private var sauceColor: Color {

        switch sauce {

        case "Pesto":
            return .green

        case "Spicy":
            return .red

        default:
            return .red.opacity(0.82)
        }
    }

    private func toppingEmoji(
        _ topping: String
    ) -> String {

        allToppings.first {
            $0.id == topping
        }?.emoji ?? "•"
    }

    private func toppingOffset(
        _ index: Int
    ) -> CGSize {

        let points = [
            CGSize(width: -30, height: -34),
            CGSize(width: 28, height: -28),
            CGSize(width: -42, height: 18),
            CGSize(width: 36, height: 22),
            CGSize(width: 0, height: 0),
            CGSize(width: 2, height: 44)
        ]

        return points[index % points.count]
    }

    private func ingredientSection(
        title: String,
        choices: [PizzaChoice],
        selected: [String],
        action: @escaping (PizzaChoice) -> Void
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.headline)
                .fontWeight(.black)

            FlowLayout(spacing: 9) {
                ForEach(choices) { choice in
                    ingredientButton(
                        choice: choice,
                        isSelected: selected.contains(choice.id)
                    ) {
                        action(choice)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func ingredientButton(
        choice: PizzaChoice,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 7) {
                Text(choice.emoji)
                Text(choice.id)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? .orange.opacity(0.25) : .white.opacity(0.88))
            .overlay(
                Capsule()
                    .stroke(isSelected ? .orange : .clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isBaked || isFed)
    }

    private var actionArea: some View {

        VStack(spacing: 10) {

            if isFed || rewardClaimed {

                Text("Ziggy ate every bite.")
                    .font(.headline)
                    .fontWeight(.black)

                Button {
                    claimReward()
                } label: {
                    Text(didAward || rewardClaimed ? "Love Maxed" : "Finish Pizza Date")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(didAward || rewardClaimed ? .green : .pink)
                        .clipShape(Capsule())
                }
                .disabled(didAward || rewardClaimed)

            } else if isBaked {

                Text(recipeMatches ? "Drag the pizza to Ziggy's face." : "This pizza is baked, but not the order.")
                    .font(.headline)
                    .multilineTextAlignment(.center)

            } else {

                Button {
                    bakePizza()
                } label: {
                    Label(
                        recipeMatches ? "Bake Pizza" : "Match Ziggy's Order",
                        systemImage: "flame.fill"
                    )
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(recipeMatches ? .orange : .gray)
                    .clipShape(Capsule())
                }
                .disabled(!recipeMatches)
            }
        }
        .padding(14)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func joinGame() {

        FirestoreManager.shared.joinPizzaGame(
            username: username
        ) { side in
            DispatchQueue.main.async {
                if let side,
                   let pizzaSide = PizzaSide(rawValue: side) {
                    assignedSide = pizzaSide
                }
            }
        }
    }

    private func listenForGame() {

        FirestoreManager.shared.listenForPizzaGame { data in

            DispatchQueue.main.async {
                leftPlayer = data["leftPlayer"] as? String ?? ""
                rightPlayer = data["rightPlayer"] as? String ?? ""
                leftReady = data["leftReady"] as? Bool ?? false
                rightReady = data["rightReady"] as? Bool ?? false
                status = data["status"] as? String ?? "lobby"
                recipeID = data["recipeID"] as? Int ?? 0
                base = data["base"] as? String ?? ""
                sauce = data["sauce"] as? String ?? ""
                cheese = data["cheese"] as? String ?? ""
                toppings = data["toppings"] as? [String] ?? []
                isBaked = data["isBaked"] as? Bool ?? false
                isFed = data["isFed"] as? Bool ?? false
                rewardClaimed = data["rewardClaimed"] as? Bool ?? false
                lastChef = data["lastChef"] as? String ?? ""

                if isFed {
                    pizzaOffset = .zero
                }
            }
        }
    }

    private func toggleReady() {

        guard let assignedSide else { return }

        FirestoreManager.shared.setPizzaGameReady(
            side: assignedSide.rawValue,
            username: username,
            isReady: !isReady
        )
    }

    private func choose(
        key: String,
        value: String
    ) {

        UIImpactFeedbackGenerator(style: .soft)
            .impactOccurred()

        FirestoreManager.shared.updatePizzaIngredient(
            key: key,
            value: value,
            by: username
        )
    }

    private func toggleTopping(
        _ topping: String
    ) {

        var updated = toppings

        if updated.contains(topping) {
            updated.removeAll {
                $0 == topping
            }
        } else {
            updated.append(topping)
        }

        UIImpactFeedbackGenerator(style: .soft)
            .impactOccurred()

        FirestoreManager.shared.updatePizzaIngredient(
            key: "toppings",
            value: updated,
            by: username
        )
    }

    private func bakePizza() {

        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred()

        FirestoreManager.shared.bakePizzaGame()
    }

    private func feedPizza() {

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            pizzaOffset = CGSize(width: 0, height: -112)
            isEating = true
        }

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            FirestoreManager.shared.feedPizzaGame()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isEating = false
            claimReward()
        }
    }

    private func claimReward() {

        FirestoreManager.shared.claimPizzaReward { didClaim in

            guard didClaim else { return }

            DispatchQueue.main.async {
                petVM.completePizzaParty()
                didAward = true
            }
        }
    }

    private func startNewRound() {

        isEating = false
        didAward = false
        pizzaOffset = .zero
        assignedSide = nil

        FirestoreManager.shared.resetPizzaGame(
            username: username
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            joinGame()
        }
    }
}

private struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {

        let width = proposal.width ?? 320
        let rows = rows(
            in: subviews,
            maxWidth: width
        )

        return CGSize(
            width: width,
            height: rows.reduce(0) { total, row in
                total + row.height
            } + CGFloat(max(rows.count - 1, 0)) * spacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {

        let rows = rows(
            in: subviews,
            maxWidth: bounds.width
        )

        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func rows(
        in subviews: Subviews,
        maxWidth: CGFloat
    ) -> [FlowRow] {

        var rows: [FlowRow] = []
        var current: [FlowElement] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth =
                current.isEmpty
                ? size.width
                : currentWidth + spacing + size.width

            if nextWidth > maxWidth,
               !current.isEmpty {
                rows.append(
                    FlowRow(
                        elements: current,
                        height: currentHeight
                    )
                )
                current = []
                currentWidth = 0
                currentHeight = 0
            }

            current.append(
                FlowElement(
                    subview: subview,
                    size: size
                )
            )
            currentWidth =
                current.isEmpty
                ? size.width
                : min(maxWidth, nextWidth)
            currentHeight = max(
                currentHeight,
                size.height
            )
        }

        if !current.isEmpty {
            rows.append(
                FlowRow(
                    elements: current,
                    height: currentHeight
                )
            )
        }

        return rows
    }

    private struct FlowElement {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct FlowRow {
        let elements: [FlowElement]
        let height: CGFloat
    }
}

#Preview {
    PizzaMakingGameView(
        petVM: PetViewModel()
    )
}
