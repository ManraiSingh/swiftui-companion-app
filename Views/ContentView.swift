//import SwiftUI
//
//struct ContentView: View {
//    @AppStorage("ziggy_username")
//    private var username = ""
//    @StateObject private var petVM = PetViewModel()
//    @StateObject private var dailyQ = DailyQuestionManager.shared
//
//    @State private var showFeedView        = false
//    @State private var showInstantView     = false
//    @State private var showDrawingGameView = false
//    @State private var showAnswerSheet     = false
//
//    @StateObject private var relationshipManager = RelationshipManager.shared
//
//    @State private var messageUsage: [String: Int] = [:]
//    @State private var customQuickMessage = ""
//    private let usageKey = "ziggy_quick_usage"
//
//    @FocusState private var noteFocused: Bool
//
//    private let allQuickMessages: [QuickMessage] = [
//        QuickMessage(id: "miss",    emoji: "🥺", label: "Miss You",   payload: "is missing you 🥺"),
//        QuickMessage(id: "night",   emoji: "🌙", label: "Good Night", payload: "says good night 🌙"),
//        QuickMessage(id: "morning", emoji: "☀️", label: "Morning",    payload: "says good morning ☀️"),
//        QuickMessage(id: "think",   emoji: "💭", label: "Thinking",   payload: "is thinking about you 💭"),
//        QuickMessage(id: "hug",     emoji: "🤗", label: "Hug",        payload: "wants to hug you 🤗"),
//        QuickMessage(id: "proud",   emoji: "⭐️", label: "Proud",      payload: "is proud of you ⭐️"),
//        QuickMessage(id: "home",    emoji: "🏡", label: "Safe Place", payload: "feels safe with you 🏡")
//    ]
//
//    private var sortedQuickMessages: [QuickMessage] {
//        allQuickMessages
//            .enumerated()
//            .sorted { a, b in
//                let ua = messageUsage[a.element.id] ?? 0
//                let ub = messageUsage[b.element.id] ?? 0
//                if ua != ub { return ua > ub }
//                return a.offset < b.offset
//            }
//            .map { $0.element }
//    }
//
//    // MARK: - Body
//
//    var body: some View {
//        if username.isEmpty {
//            OnboardingView()
//        } else if !relationshipManager.isConnected {
//            RelationshipSetupView()
//        } else {
//            TabView {
//                homeView
//                    .tabItem { Label("Home", systemImage: "house.fill") }
//                ActivityView(petVM: petVM)
//                    .tabItem { Label("Activity", systemImage: "clock.fill") }
//                SettingsView()
//                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
//            }
//            .onAppear {
//                loadUsage()
//                dailyQ.startListening()
//                UserDefaults(suiteName: "group.com.manrai.ziggy")?
//                    .set(Date(), forKey: "last_app_open_time")
//            }
//        }
//    }
//
//    // MARK: - Mood helpers
//
//    var currentEmotionImage: String {
//        if petVM.hasPendingInstant { return "31" }
//        switch petVM.pet.loveScore {
//        case 90...100: return "ziggy_loveeyes"
//        case 70..<90:  return "ziggy_happie"
//        case 50..<70:  return "ziggy_sleep"
//        case 30..<50:  return "ziggu_cry"
//        case 15..<30:  return "ziggy_angrywithmark"
//        default:       return "ziggy_fireangry"
//        }
//    }
//
//    var shortMoodMessage: String {
//        switch petVM.pet.loveScore {
//        case 90...100: return "Can't stop thinking about you ❤️"
//        case 70..<90:  return "Let's make more memories ✨"
//        case 50..<70:  return "Just vibing today 😴"
//        case 30..<50:  return "Missing you a little 🥺"
//        case 15..<30:  return "Come spend time with me 😤"
//        default:       return "I've been waiting for you 💔"
//        }
//    }
//
//    var cuteActivityText: String {
//        let person = petVM.pet.lastActionBy
//        switch petVM.pet.lastAction {
//        case "Fed Ziggy 🍖":            return "🍖 \(person) fed me!"
//        case "Played with Ziggy 🎾":    return "❤️ I love seeing you guys play together ❤️"
//        case "Made Pizza for Ziggy 🍕": return "🍕 Ziggy devoured your couple pizza!"
//        case "Sent a Hug ❤️":           return "\(person) hugged me!"
//        default:                         return "🐶 Waiting for someone..."
//        }
//    }
//
//    var speechBubbleText: String {
//        if petVM.hasPendingInstant { return "Psst… \(petVM.instantSender) sent you an Instant 😳" }
//        if !petVM.latestEmotion.isEmpty { return petVM.latestEmotion }
//        switch petVM.pet.loveScore {
//        case 90...100: return "I can't stop thinking about you ❤️"
//        case 70..<90:  return "Let's make memories together ✨"
//        case 50..<70:  return "Just relaxing today 😴"
//        case 30..<50:  return "I miss you 🥺"
//        case 15..<30:  return "Come spend time with me 😤"
//        default:       return "Where have you been? 💔"
//        }
//    }
//
//    // MARK: - Home View
//
//    private var homeView: some View {
//        ZStack {
//            LinearGradient(
//                colors: [
//                    Color(red: 0.98, green: 0.96, blue: 0.91),
//                    Color(red: 0.90, green: 0.97, blue: 0.94),
//                    Color(red: 0.92, green: 0.94, blue: 0.99)
//                ],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//            .ignoresSafeArea()
//
//            VStack(spacing: 13) {
//                compactHeader
//                ziggyHero
//                dailyQuestionCard
//                actionDock
//                messagePanel
//            }
//            .padding(.horizontal, 16)
//            .padding(.top, 8)
//            .padding(.bottom, 8)
//        }
//        .fullScreenCover(isPresented: $showFeedView)        { FeedView(petVM: petVM) }
//        .fullScreenCover(isPresented: $showInstantView)     { InstantView(petVM: petVM) }
//        .fullScreenCover(isPresented: $showDrawingGameView) { PlayCenterView(petVM: petVM) }
//        .sheet(isPresented: $showAnswerSheet)               { answerSheet }
//    }
//
//    // MARK: - Header
//
//    private var compactHeader: some View {
//        HStack(spacing: 12) {
//            VStack(alignment: .leading, spacing: 2) {
//                Text("You two & Ziggy 💞")
//                    .font(.system(size: 22, weight: .black))
//                    .foregroundStyle(.primary)
//                Text(shortMoodMessage)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//                    .lineLimit(1)
//            }
//            Spacer()
//            loveBadge
//        }
//        .padding(.horizontal, 4)
//    }
//
//    private var loveBadge: some View {
//        ZStack {
//            Circle().fill(.white.opacity(0.7)).frame(width: 62, height: 62)
//            Circle().stroke(Color.white.opacity(0.85), lineWidth: 7).frame(width: 62, height: 62)
//            Circle()
//                .trim(from: 0, to: CGFloat(petVM.pet.loveScore) / 100)
//                .stroke(
//                    LinearGradient(
//                        colors: [.orange, .pink, .mint],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    ),
//                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
//                )
//                .rotationEffect(.degrees(-90))
//                .frame(width: 62, height: 62)
//            VStack(spacing: -2) {
//                Text("\(petVM.pet.loveScore)").font(.system(size: 18, weight: .black))
//                Text("love").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
//            }
//        }
//        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
//    }
//
//    // MARK: - Ziggy Hero
//
//    private var ziggyHero: some View {
//        ZStack(alignment: .bottom) {
//            RoundedRectangle(cornerRadius: 40)
//                .fill(LinearGradient(
//                    colors: moodSurfaceColors,
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                ))
//                .overlay(alignment: .topLeading) { sparkleCluster.padding(20) }
//                .overlay(alignment: .topTrailing) {
//                    Image(systemName: "heart.fill")
//                        .font(.system(size: 13))
//                        .foregroundStyle(.white.opacity(0.7))
//                        .padding(22)
//                }
//
//            VStack(spacing: 2) {
//                speechBubble.padding(.horizontal, 18)
//                Image(currentEmotionImage)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(height: 130)
//                    .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
//            }
//            .padding(.top, 16)
//            .padding(.bottom, 40)
//
//            activityTag.padding(.bottom, 14)
//        }
//        .frame(height: 270)
//    }
//
//    private var moodSurfaceColors: [Color] {
//        switch petVM.pet.loveScore {
//        case 80...100: return [Color(red: 1.0, green: 0.86, blue: 0.72), Color(red: 0.82, green: 0.95, blue: 0.87)]
//        case 50..<80:  return [Color(red: 0.83, green: 0.93, blue: 1.0), Color(red: 0.93, green: 0.90, blue: 1.0)]
//        default:       return [Color(red: 1.0, green: 0.83, blue: 0.78), Color(red: 0.87, green: 0.90, blue: 0.95)]
//        }
//    }
//
//    private var sparkleCluster: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Image(systemName: "sparkle")
//            Image(systemName: "heart.fill").font(.caption)
//            Image(systemName: "sparkles")
//        }
//        .foregroundStyle(.white.opacity(0.8))
//    }
//
//    private var speechBubble: some View {
//        Text(speechBubbleText)
//            .font(.headline).fontWeight(.bold)
//            .multilineTextAlignment(.center)
//            .foregroundStyle(.primary)
//            .lineLimit(3).minimumScaleFactor(0.84)
//            .padding(.horizontal, 18).padding(.vertical, 13)
//            .background(.white.opacity(0.92))
//            .clipShape(RoundedRectangle(cornerRadius: 24))
//            .overlay(alignment: .bottom) {
//                Image(systemName: "triangle.fill")
//                    .font(.system(size: 13))
//                    .foregroundStyle(.white.opacity(0.92))
//                    .rotationEffect(.degrees(180))
//                    .offset(y: 9)
//            }
//            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
//    }
//
//    private var activityTag: some View {
//        HStack(spacing: 7) {
//            Image(systemName: "sparkles")
//                .font(.system(size: 11, weight: .bold))
//                .foregroundStyle(.orange)
//            Text(cuteActivityText)
//                .font(.system(size: 13, weight: .bold))
//                .foregroundStyle(.primary)
//                .lineLimit(1).minimumScaleFactor(0.7)
//        }
//        .padding(.horizontal, 15).padding(.vertical, 9)
//        .background(.white.opacity(0.97))
//        .clipShape(Capsule())
//        .overlay(Capsule().stroke(.orange.opacity(0.16), lineWidth: 1))
//        .shadow(color: .black.opacity(0.13), radius: 9, y: 4)
//    }
//
//    // MARK: - Daily Question Card
//    // Always tappable — sheet content changes based on state
//
//    private var dailyQuestionCard: some View {
//        let q          = dailyQ.question
//        let myAnswered = !(q?.myAnswer.isEmpty ?? true)
//        let bothDone   = q?.bothAnswered ?? false
//
//        return Button { showAnswerSheet = true } label: {
//            HStack(spacing: 12) {
//
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack(spacing: 5) {
//                        Text("🐾").font(.system(size: 13))
//                        Text("Ziggy asks today")
//                            .font(.caption2).fontWeight(.black)
//                            .foregroundStyle(.secondary)
//                    }
//                    Text(dailyQ.todayQuestion)
//                        .font(.caption).fontWeight(.semibold)
//                        .foregroundStyle(.primary)
//                        .lineLimit(2)
//                        .minimumScaleFactor(0.85)
//                        .fixedSize(horizontal: false, vertical: true)
//                }
//
//                Spacer(minLength: 8)
//
//                // Status badge — right side
//                VStack(spacing: 3) {
//                    if bothDone {
//                        Image(systemName: "heart.text.square.fill")
//                            .font(.system(size: 22))
//                            .foregroundStyle(.pink)
//                        Text("See answers")
//                            .font(.caption2).fontWeight(.black)
//                            .foregroundStyle(.pink)
//                    } else if myAnswered {
//                        Image(systemName: "hourglass")
//                            .font(.system(size: 20))
//                            .foregroundStyle(.purple)
//                        Text("Waiting")
//                            .font(.caption2).fontWeight(.black)
//                            .foregroundStyle(.purple)
//                    } else {
//                        Image(systemName: "pencil.circle.fill")
//                            .font(.system(size: 22))
//                            .foregroundStyle(.pink)
//                        Text("Answer")
//                            .font(.caption2).fontWeight(.black)
//                            .foregroundStyle(.pink)
//                    }
//                }
//                .frame(width: 70)
//            }
//            .padding(.horizontal, 14).padding(.vertical, 11)
//            .background(
//                LinearGradient(
//                    colors: [
//                        Color(red: 1.0, green: 0.93, blue: 0.97),
//                        Color(red: 0.94, green: 0.93, blue: 1.0)
//                    ],
//                    startPoint: .leading,
//                    endPoint: .trailing
//                )
//            )
//            .clipShape(RoundedRectangle(cornerRadius: 20))
//            .overlay(
//                RoundedRectangle(cornerRadius: 20)
//                    .stroke(Color.pink.opacity(0.20), lineWidth: 1.5)
//            )
//            .shadow(color: .pink.opacity(0.08), radius: 8, y: 4)
//        }
//        .buttonStyle(.plain)
//    }
//
//    // MARK: - Answer Sheet
//    // Three states: input / waiting / both answered
//
//    @ViewBuilder
//    private var answerSheet: some View {
//        let q          = dailyQ.question
//        let myAnswered = !(q?.myAnswer.isEmpty ?? true)
//        let bothDone   = q?.bothAnswered ?? false
//
//        ZStack {
//            LinearGradient(
//                colors: [
//                    Color(red: 1.0, green: 0.93, blue: 0.97),
//                    Color(red: 0.94, green: 0.93, blue: 1.0)
//                ],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//            .ignoresSafeArea()
//
//            VStack(spacing: 0) {
//
//                // Drag handle
//                RoundedRectangle(cornerRadius: 3)
//                    .fill(Color.secondary.opacity(0.3))
//                    .frame(width: 40, height: 5)
//                    .padding(.top, 14)
//                    .padding(.bottom, 20)
//
//                // Ziggy paw + label
//                HStack(spacing: 6) {
//                    Text("🐾")
//                    Text("Ziggy asks today")
//                        .font(.caption).fontWeight(.black)
//                        .foregroundStyle(.secondary)
//                }
//                .padding(.bottom, 10)
//
//                // Question
//                Text(dailyQ.todayQuestion)
//                    .font(.title3).fontWeight(.bold)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 28)
//                    .padding(.bottom, 24)
//
//                // — State-based content —
//                if bothDone, let q {
//                    bothAnsweredContent(q)
//                } else if myAnswered, let q {
//                    waitingContent(q)
//                } else {
//                    inputContent
//                }
//
//                Spacer()
//            }
//        }
//        .presentationDetents([.medium])
//        .presentationCornerRadius(32)
//    }
//
//    // State 1: input — only shown when user hasn't answered yet
//    private var inputContent: some View {
//        VStack(spacing: 12) {
//            TextField("Your answer…", text: $dailyQ.myAnswerDraft, axis: .vertical)
//                .font(.subheadline)
//                .lineLimit(1...4)
//                .textInputAutocapitalization(.sentences)
//                .padding(.horizontal, 16).padding(.vertical, 14)
//                .background(.white.opacity(0.92))
//                .clipShape(RoundedRectangle(cornerRadius: 18))
//                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
//
//            Button {
//                let trimmed = dailyQ.myAnswerDraft
//                    .trimmingCharacters(in: .whitespacesAndNewlines)
//                guard !trimmed.isEmpty else { return }
//                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
//                dailyQ.submitAnswer(trimmed)
//                showAnswerSheet = false
//            } label: {
//                Group {
//                    if dailyQ.isSubmitting {
//                        ProgressView().tint(.white)
//                    } else {
//                        Label("Send to Ziggy", systemImage: "paperplane.fill")
//                            .fontWeight(.bold)
//                    }
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 15)
//                .background(
//                    dailyQ.myAnswerDraft
//                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//                    ? Color.gray : Color.pink
//                )
//                .foregroundColor(.white)
//                .clipShape(RoundedRectangle(cornerRadius: 18))
//            }
//            .disabled(
//                dailyQ.myAnswerDraft
//                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//                || dailyQ.isSubmitting
//            )
//        }
//        .padding(.horizontal, 24)
//    }
//
//    // State 2: waiting — I answered, partner hasn't yet
//    private func waitingContent(_ q: DailyQuestion) -> some View {
//        VStack(spacing: 14) {
//            // My answer shown
//            answerBubble(
//                name: UserManager.shared.username,
//                text: q.myAnswer,
//                tint: .pink,
//                label: "Your answer"
//            )
//
//            // Waiting pill
//            HStack(spacing: 8) {
//                Image(systemName: "ellipsis.circle")
//                    .foregroundStyle(.purple.opacity(0.6))
//                Text("Waiting for \(q.partnerName) to answer…")
//                    .font(.caption).fontWeight(.semibold)
//                    .foregroundStyle(.secondary)
//            }
//            .padding(.horizontal, 14).padding(.vertical, 10)
//            .background(.white.opacity(0.7))
//            .clipShape(Capsule())
//        }
//        .padding(.horizontal, 24)
//    }
//
//    // State 3: both answered — show both in chat bubbles
//    private func bothAnsweredContent(_ q: DailyQuestion) -> some View {
//        VStack(spacing: 10) {
//            answerBubble(
//                name: UserManager.shared.username,
//                text: q.myAnswer,
//                tint: .pink,
//                label: "You"
//            )
//            answerBubble(
//                name: q.partnerName,
//                text: q.partnerAnswer,
//                tint: .purple,
//                label: q.partnerName
//            )
//
//            // Heart reaction
//            Text("💞 You both answered today")
//                .font(.caption).fontWeight(.bold)
//                .foregroundStyle(.secondary)
//                .padding(.top, 4)
//        }
//        .padding(.horizontal, 24)
//    }
//
//    // Reusable answer bubble
//    private func answerBubble(
//        name: String,
//        text: String,
//        tint: Color,
//        label: String
//    ) -> some View {
//        HStack(alignment: .top, spacing: 10) {
//            // Avatar circle
//            Circle()
//                .fill(tint.opacity(0.18))
//                .frame(width: 36, height: 36)
//                .overlay(
//                    Text(String(name.prefix(1)).uppercased())
//                        .font(.subheadline).fontWeight(.black)
//                        .foregroundStyle(tint)
//                )
//
//            VStack(alignment: .leading, spacing: 3) {
//                Text(label)
//                    .font(.caption2).fontWeight(.black)
//                    .foregroundStyle(tint)
//                Text(text)
//                    .font(.subheadline)
//                    .foregroundStyle(.primary)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//
//            Spacer(minLength: 0)
//        }
//        .padding(12)
//        .background(.white.opacity(0.78))
//        .clipShape(RoundedRectangle(cornerRadius: 16))
//    }
//
//    // MARK: - Action Dock
//
//    private var actionDock: some View {
//        HStack(spacing: 12) {
//            actionCard(
//                systemImage: "fork.knife",
//                title: "Feed",
//                subtitle: "Care",
//                color: .orange
//            ) { showFeedView = true }
//
//            actionCard(
//                systemImage: "gamecontroller.fill",
//                title: "Play",
//                subtitle: "Games",
//                color: .green
//            ) { showDrawingGameView = true }
//
//            actionCard(
//                systemImage: "camera.fill",
//                title: "Instant",
//                subtitle: petVM.hasPendingInstant ? "New" : "Snap",
//                color: .pink,
//                showDot: petVM.hasPendingInstant
//            ) {
//                petVM.markInstantSeen()
//                showInstantView = true
//            }
//        }
//    }
//
//    // MARK: - Message Panel
//
//    private var messagePanel: some View {
//        VStack(alignment: .leading, spacing: 9) {
//            HStack(spacing: 6) {
//                Text("Send a little love")
//                    .font(.subheadline).fontWeight(.black)
//                Text("💌").font(.caption)
//                Spacer()
//            }
//
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 10) {
//                    ForEach(sortedQuickMessages) { msg in
//                        quickPill(msg) { sendQuick(msg) }
//                    }
//                }
//                .padding(.vertical, 2)
//            }
//
//            customMessageComposer
//        }
//        .padding(14)
//        .background(.white.opacity(0.74))
//        .clipShape(RoundedRectangle(cornerRadius: 24))
//        .shadow(color: .black.opacity(0.05), radius: 10, y: 6)
//    }
//
//    private var customMessageComposer: some View {
//        HStack(spacing: 10) {
//            TextField("Write your own tiny note", text: $customQuickMessage)
//                .focused($noteFocused)
//                .textInputAutocapitalization(.sentences)
//                .submitLabel(.send)
//                .onSubmit { sendCustomQuickMessage() }
//                .font(.subheadline)
//                .padding(.horizontal, 14).padding(.vertical, 13)
//                .background(.white.opacity(0.9))
//                .clipShape(Capsule())
//
//            Button { sendCustomQuickMessage() } label: {
//                Image(systemName: "paperplane.fill")
//                    .font(.headline).foregroundColor(.white)
//                    .frame(width: 46, height: 46)
//                    .background(
//                        customQuickMessage
//                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//                        ? .gray : .blue
//                    )
//                    .clipShape(Circle())
//            }
//            .disabled(customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//        }
//    }
//
//    // MARK: - Helpers
//
//    private func sendQuick(_ msg: QuickMessage) {
//        FirestoreManager.shared.sendEmotion(title: msg.payload, from: UserManager.shared.username)
//        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
//        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
//            messageUsage[msg.id, default: 0] += 1
//        }
//        saveUsage()
//    }
//
//    private func sendCustomQuickMessage() {
//        let trimmed = customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else { return }
//        FirestoreManager.shared.sendEmotion(title: "custom:\(trimmed)", from: UserManager.shared.username)
//        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
//        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { customQuickMessage = "" }
//    }
//
//    private func loadUsage() {
//        if let data = UserDefaults.standard.data(forKey: usageKey),
//           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
//            messageUsage = dict
//        }
//    }
//
//    private func saveUsage() {
//        if let data = try? JSONEncoder().encode(messageUsage) {
//            UserDefaults.standard.set(data, forKey: usageKey)
//        }
//    }
//}
//
//// MARK: - Supporting Types
//
//struct QuickMessage: Identifiable {
//    let id: String
//    let emoji: String
//    let label: String
//    let payload: String
//}
//
//@ViewBuilder
//func quickPill(_ msg: QuickMessage, action: @escaping () -> Void) -> some View {
//    Button(action: action) {
//        HStack(spacing: 9) {
//            Text(msg.emoji).font(.headline)
//            Text(msg.label).font(.caption).fontWeight(.black).foregroundStyle(.primary)
//        }
//        .padding(.horizontal, 14).padding(.vertical, 11)
//        .background(Capsule().fill(.white.opacity(0.94)))
//        .overlay(Capsule().stroke(Color.orange.opacity(0.18), lineWidth: 1.5))
//        .shadow(color: .black.opacity(0.08), radius: 7, y: 3)
//    }
//    .buttonStyle(.plain)
//}
//
//func actionCard(
//    systemImage: String,
//    title: String,
//    subtitle: String,
//    color: Color,
//    showDot: Bool = false,
//    action: @escaping () -> Void
//) -> some View {
//    Button(action: action) {
//        VStack(spacing: 10) {
//            ZStack(alignment: .topTrailing) {
//                Image(systemName: systemImage)
//                    .font(.system(size: 23, weight: .semibold))
//                    .foregroundStyle(color)
//                    .frame(width: 54, height: 54)
//                    .background(Circle().fill(color.opacity(0.16)))
//                    .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1.5))
//                if showDot {
//                    Circle().fill(.red).frame(width: 13, height: 13)
//                        .overlay(Circle().stroke(.white, lineWidth: 2))
//                        .offset(x: 3, y: -3)
//                }
//            }
//            VStack(spacing: 2) {
//                Text(title).font(.subheadline).fontWeight(.black).foregroundStyle(.primary)
//                Text(subtitle).font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
//            }
//        }
//        .padding(.vertical, 15)
//        .frame(maxWidth: .infinity, minHeight: 112)
//        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.78)))
//        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.20), lineWidth: 1.5))
//        .shadow(color: color.opacity(0.12), radius: 10, y: 6)
//    }
//    .buttonStyle(.plain)
//}
//
//#Preview {
//    ContentView()
//}
import SwiftUI
import StoreKit

// Sums the reported heights of every view marked `.reportHeight()` — lets
// ziggyHero be sized as "exactly what's left over" from real measurements
// instead of a guessed formula, so it's correct on any device.
private struct CardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private extension View {
    func reportHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: CardHeightKey.self, value: proxy.size.height)
            }
        )
    }
}

struct ContentView: View {
    @AppStorage("ziggy_username")
    private var username = ""
    @StateObject private var petVM = PetViewModel()
    @StateObject private var dailyQ = DailyQuestionManager.shared

    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("ziggy_has_asked_for_review")
    private var hasAskedForReview = false

    @State private var showRatingPrompt = false

    @AppStorage("ziggy_connected_popup_shown_for_code")
    private var connectedPopupShownForCode = ""

    @State private var showConnectedPopup = false

    @AppStorage("ziggy_widget_walkthrough_shown")
    private var hasShownWidgetWalkthrough = false
    @State private var showWidgetOnboarding = false

    @State private var showFeedView        = false
    @State private var showInstantView     = false
    @State private var showDrawingGameView = false
    @State private var showDoodleView      = false
    @State private var showAnswerSheet     = false

    @StateObject private var relationshipManager = RelationshipManager.shared

    @State private var messageUsage: [String: Int] = [:]
    @State private var customQuickMessage = ""
    private let usageKey = "ziggy_quick_usage"

    // User-created one-tap pills, saved on this device.
    @State private var customQuickMessages: [QuickMessage] = []
    private let customQuickKey = "ziggy_custom_quick_messages"

    @State private var showNewQuickPopup = false
    // Second step of creating a pill: which face Ziggy wears when it's sent.
    @State private var showNewQuickEmotionPopup = false
    @State private var newQuickText = ""
    @State private var newQuickEmoji = "💌"
    @FocusState private var newQuickFocused: Bool

    // Short enough that the finished pill still fits the row comfortably.
    private let quickMessageCharLimit = 24

    private let newQuickEmojiChoices = [
        "💌", "❤️", "🥰", "😘", "🫶", "✨",
        "🥺", "😢", "😂", "🔥", "🌙", "☀️",
        "🍕", "☕️", "🎶", "🐶"
    ]

    @State private var showComposeBar = false
    @State private var otherCardsHeight: CGFloat = 0
    @State private var composeKeyboardHeight: CGFloat = 0
    @FocusState private var composeFocused: Bool

    private let allQuickMessages: [QuickMessage] = [
        QuickMessage(id: "miss",    emoji: "🥺", label: "Miss You",   payload: "is missing you 🥺",        emotion: "miss"),
        QuickMessage(id: "night",   emoji: "🌙", label: "Good Night", payload: "says good night 🌙",        emotion: "sleepy"),
        QuickMessage(id: "morning", emoji: "☀️", label: "Morning",    payload: "says good morning ☀️",      emotion: "happy"),
        QuickMessage(id: "think",   emoji: "💭", label: "Thinking",   payload: "is thinking about you 💭",  emotion: "love"),
        QuickMessage(id: "hug",     emoji: "🤗", label: "Hug",        payload: "wants to hug you 🤗",        emotion: "love"),
        QuickMessage(id: "proud",   emoji: "⭐️", label: "Proud",      payload: "is proud of you ⭐️",        emotion: "happy"),
        QuickMessage(id: "home",    emoji: "🏡", label: "Safe Place", payload: "feels safe with you 🏡",    emotion: "love")
    ]

    @State private var showEmotionPopup = false

    @AppStorage("ziggy_hasSeenWelcome")
    private var hasSeenWelcome = false

    @AppStorage("ziggy_pending_invite_code")
    private var pendingInviteCode = ""

    private var sortedQuickMessages: [QuickMessage] {
        // Your own pills always sit ahead of the built-ins, newest first.
        // Only the built-ins reshuffle by how often they're used, so a
        // custom message never gets pushed down the row.
        let builtIns = allQuickMessages
            .enumerated()
            .sorted { a, b in
                let ua = messageUsage[a.element.id] ?? 0
                let ub = messageUsage[b.element.id] ?? 0
                if ua != ub { return ua > ub }
                return a.offset < b.offset
            }
            .map { $0.element }

        return customQuickMessages + builtIns
    }

    // MARK: - Body

    var body: some View {
        Group {
            if !hasSeenWelcome {
                WelcomeCarouselView {
                    withAnimation { hasSeenWelcome = true }
                }
            } else if username.isEmpty {
                OnboardingView()
            } else if !pendingInviteCode.isEmpty && !relationshipManager.isConnected {
                InviteConnectionView(inviteCode: pendingInviteCode) {
                    pendingInviteCode = ""
                }
            } else if !relationshipManager.isConnected {
                RelationshipSetupView()
            } else {
                TabView {
                    homeView
                        .tabItem { Label("Home", systemImage: "house.fill") }
                    ActivityView(petVM: petVM)
                        .tabItem { Label("Activity", systemImage: "clock.fill") }
                    SettingsView(petVM: petVM)
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
                .onAppear {
                    loadUsage()
                    loadCustomQuickMessages()
                    dailyQ.startListening()
                    UserDefaults(suiteName: "group.com.manrai.ziggy")?
                        .set(Date(), forKey: "last_app_open_time")
                    checkForRatingPrompt()
                    watchForBothConnected()
                }
            }
        }
        .onOpenURL { url in
            handleInviteURL(url)
        }
        .onChange(of: username) { _, newValue in
            if !pendingInviteCode.isEmpty,
               !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hasSeenWelcome = true
            }
        }
        // Re-arms (or cancels) tonight's feed reminder every time the app
        // is reopened, not just on a cold launch — otherwise a reminder
        // scheduled this morning would outlive being fed later that day
        // unless the app happened to relaunch from scratch.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                petVM.refreshFeedReminder()
            }
        }
    }

    private func handleInviteURL(_ url: URL) {
        // Already paired — ignore invites so we don't stash a stale code
        // that would hijack the screen after a future disconnect.
        guard !relationshipManager.isConnected else { return }

        guard
            url.scheme?.lowercased() == "ziggy",
            url.host?.lowercased() == "invite",
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ),
            let code = components.queryItems?
                .first(where: { $0.name == "code" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
            !code.isEmpty
        else { return }

        pendingInviteCode = code
        hasSeenWelcome = true
    }

    // MARK: - Mood helpers

    var currentEmotionImage: String {
        // While a love message is on screen, Ziggy wears the sent emotion
        if let img = petVM.ephemeralMessage?.emotionImage, !img.isEmpty {
            return img
        }
        if petVM.hasPendingInstant { return "31" }
        switch petVM.pet.loveScore {
        case 90...100: return "ziggy_loveeyes"
        case 70..<90:  return "ziggy_happie"
        case 50..<70:  return "ziggy_sleep"
        case 30..<50:  return "ziggu_cry"
        case 15..<30:  return "ziggy_angrywithmark"
        default:       return "ziggy_fireangry"
        }
    }

    var shortMoodMessage: String {
        switch petVM.pet.loveScore {
        case 90...100: return "Can't stop thinking about you ❤️"
        case 70..<90:  return "Let's make more memories ✨"
        case 50..<70:  return "Just vibing today 😴"
        case 30..<50:  return "Missing you a little 🥺"
        case 15..<30:  return "Come spend time with me 😤"
        default:       return "I've been waiting for you 💔"
        }
    }

    var cuteActivityText: String {
        let person = petVM.pet.lastActionBy
        let action = petVM.pet.lastAction
        if action.contains("Fed") {
            return "🍖 \(person) fed me!"
        }
        if action.contains("Played") {
            return "❤️ I love seeing you guys play together ❤️"
        }
        if action.contains("Pizza") {
            return "🍕 \(petVM.pet.name) devoured your couple pizza!"
        }
        if action.contains("Hug") {
            return "\(person) hugged me!"
        }
        return "🐶 Waiting for someone..."
    }

    var speechBubbleText: String {

        // Ephemeral message takes priority
        if let msg = petVM.ephemeralMessage {
            return msg.text
        }

        if petVM.hasPendingInstant {
            return "Psst… \(petVM.instantSender) sent you an Instant 😳"
        }

        if !petVM.latestEmotion.isEmpty {
            return petVM.latestEmotion
        }

        switch petVM.pet.loveScore {
        case 90...100: return "I can't stop thinking about you ❤️"
        case 70..<90:  return "Let's make memories together ✨"
        case 50..<70:  return "Just relaxing today 😴"
        case 30..<50:  return "I miss you 🥺"
        case 15..<30:  return "Come spend time with me 😤"
        default:       return "Where have you been? 💔"
        }
    }

    // MARK: - Home View

    private var homeView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.91),
                    Color(red: 0.90, green: 0.97, blue: 0.94),
                    Color(red: 0.92, green: 0.94, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Reads the real available area on THIS device, and the real
            // measured height of every other card, so ziggyHero can be
            // given exactly the leftover space — not a guess, not a
            // percentage — which is correct on any iPhone by construction.
            GeometryReader { geo in

                // 5 gaps between the 6 VStack children (header, hero, daily,
                // dock, panel, spacer) plus the outer top/bottom padding.
                let fixedChrome: CGFloat = 13 * 5 + 16
                let heroHeight = min(
                    max(geo.size.height - otherCardsHeight - fixedChrome, 220),
                    340
                )

                VStack(spacing: 13) {
                    compactHeader
                        .reportHeight()
                    ziggyHero(width: geo.size.width, heroHeight: heroHeight)
                    dailyQuestionCard
                        .reportHeight()
                    actionDock(containerWidth: geo.size.width)
                        .reportHeight()
                    messagePanel
                        .reportHeight()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                // Pinned to the top instead of the default center — without
                // this, any device where the cards don't exactly fill the
                // screen (shorter-content or taller-screen phones) centers
                // the whole block vertically, opening up a big empty gap
                // above the header. The trailing Spacer soaks up whatever
                // tiny bit is left after the exact-fit math above, instead
                // of a guess-driven gap.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onPreferenceChange(CardHeightKey.self) { otherCardsHeight = $0 }
            }
            // Without this, focusing the compose field's TextField made the
            // keyboard shrink the safe area GeometryReader measures above —
            // every card would visibly resize/reflow while typing. The
            // floating bar below handles riding above the keyboard itself,
            // so the home screen underneath never needs to react to it.
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // While composing, tapping anywhere outside the floating bar
            // just resigns focus — `onChange(of: composeFocused)` on the
            // bar then closes it if there's nothing typed, instead of
            // leaving an empty bar sitting there looking like a second
            // input field.
            if showComposeBar {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        composeFocused = false
                    }
            }

            if showEmotionPopup {
                emotionPopup
                    .zIndex(10)
            }

            if showRatingPrompt {
                ratingPromptView
                    .zIndex(11)
            }

            if showConnectedPopup {
                connectedPopupView
                    .zIndex(12)
            }

            if petVM.hasPendingDoodlePopup {
                doodleReceivedPopup
                    .zIndex(13)
            }

            if petVM.hasPendingInstantPopup {
                instantReceivedPopup
                    .zIndex(14)
            }

            if showNewQuickPopup {
                newQuickPopup
                    .zIndex(16)
            }

            if showNewQuickEmotionPopup {
                newQuickEmotionPopup
                    .zIndex(17)
            }

            // A floating bar, not a sheet or a safeAreaInset — either of
            // those would still shrink the home screen's own measured
            // layout underneath. This just tracks the keyboard's real
            // height itself and pads up to sit right above it, so the
            // rest of the UI never has to resize to make room for it.
            if showComposeBar {
                VStack {
                    Spacer()
                    floatingComposeBar
                        .padding(.bottom, max(composeKeyboardHeight, 8))
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(15)
            }
        }
        .fullScreenCover(isPresented: $showFeedView)        { FeedView(petVM: petVM) }
        .fullScreenCover(isPresented: $showInstantView)     { InstantView(petVM: petVM) }
        .fullScreenCover(isPresented: $showDrawingGameView) { PlayCenterView(petVM: petVM) }
        .fullScreenCover(isPresented: $showDoodleView)       { DoodleView() }
        .fullScreenCover(isPresented: $showWidgetOnboarding) {
            WidgetOnboardingView { showWidgetOnboarding = false }
        }
        .sheet(isPresented: $showAnswerSheet) {
            AnswerSheetView(dailyQ: dailyQ, petName: petVM.pet.name) {
                showAnswerSheet = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    composeKeyboardHeight = frame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                composeKeyboardHeight = 0
            }
        }
    }

    // MARK: - Header

    private var compactHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You two & \(petVM.pet.name) 💞")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.primary)
                Text(shortMoodMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            loveBadge
        }
        .padding(.horizontal, 4)
    }

    private var loveBadge: some View {
        ZStack {
            Circle().fill(.white.opacity(0.7)).frame(width: 62, height: 62)
            Circle().stroke(Color.white.opacity(0.85), lineWidth: 7).frame(width: 62, height: 62)
            Circle()
                .trim(from: 0, to: CGFloat(petVM.pet.loveScore) / 100)
                .stroke(
                    LinearGradient(
                        colors: [.orange, .pink, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 62, height: 62)
            VStack(spacing: -2) {
                Text("\(petVM.pet.loveScore)").font(.system(size: 18, weight: .black))
                Text("love").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: - Ziggy Hero

    // `heroHeight` is computed by the caller from the ACTUAL measured
    // height of every other card on the page (see `otherCardsHeight` in
    // homeView), not a percentage guess — a percentage of screen height
    // looked right on one phone and left a gap on the next, because the
    // other cards' heights don't scale with screen size the same way.
    // This way Ziggy's card is always exactly "whatever's left over,"
    // which is correct on any device by construction.
    private func ziggyHero(width: CGFloat, heroHeight: CGFloat) -> some View {

        // The shelf scales WITH heroHeight instead of staying a fixed 94pt —
        // on a device where the real leftover space is generous, a fixed
        // shelf stayed a tiny strip at the top of a much taller card,
        // making the bottom-anchored title look stuck up high with a big
        // empty-feeling gap below it before Feed/Ziggy. Scaling it keeps
        // the title sitting proportionally low on every device.
        let shelfHeight: CGFloat = min(max(heroHeight * 0.34, 80), 130)
        let topPad: CGFloat = 1
        let vstackSpacing: CGFloat = 3
        let bottomPad: CGFloat = 2
        let fixedOverhead = shelfHeight + topPad + vstackSpacing + bottomPad

        let mascotSize = min(width * 0.43, heroHeight - fixedOverhead)

        return VStack(spacing: vstackSpacing) {

            // A fixed-height shelf: the title stays pinned to the top,
            // and the message bubble is anchored to the bottom of this
            // shelf — sitting a little lower — so a longer message
            // grows upward into the shelf instead of pushing down into
            // Ziggy's row.
            HStack(alignment: .bottom, spacing: 14) {

                // The title itself now floats independently at the card's
                // middle-left (see the .overlay below) instead of living in
                // this row — this spacer just holds the speech bubble's
                // horizontal position exactly where it already was.
                Color.clear.frame(width: 130)

                speechBubble
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: shelfHeight, alignment: .bottom)
            .padding(.top, topPad)
            .padding(.horizontal, 16)

            // Feed and Ziggy share one row, side by side — Ziggy fills
            // whatever this device's `heroCap` leaves after the shelf.
            HStack(alignment: .bottom, spacing: 34) {
                feedBar
                    .frame(width: 104)
                    .padding(.bottom, 14)

                Image(currentEmotionImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: mascotSize, alignment: .bottom)
                    .frame(maxHeight: mascotSize, alignment: .bottom)
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 10)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, bottomPad)
        }
        .background(heroBackground)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "heart.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .padding(22)
        }
        // Sits at the card's true middle-left, independent of the shelf's
        // own (much smaller) height — so "Waiting for someone…" lands
        // roughly level with Feed/Ziggy instead of stuck up near the top.
        .overlay(alignment: .leading) {
            moodTitleText
                .frame(maxWidth: 130, alignment: .leading)
                .padding(.leading, 16)
                .offset(y: -28)
        }
        // heroHeight is the leftover space after every OTHER card is
        // measured — on devices where that leftover is more generous than
        // the card's own natural content, centering (the frame default)
        // left the whole shelf — and "Ziggy is happy" with it — floating
        // too high, with a dead gap between it and the next card below.
        // Bottom-anchoring pins the actual content to the bottom of that
        // reserved space, so it fills the space that was going empty.
        .frame(maxWidth: .infinity, maxHeight: heroHeight, alignment: .bottom)
    }

    // Follows whatever image Ziggy is actually showing right now — an
    // ephemeral emotion, a pending Instant, or the loveScore mood — rather
    // than only reflecting the loveScore tier.
    private var moodWord: String {
        switch currentEmotionImage {
        case "ziggy_loveeyes":       return "in love"
        case "ziggy_happie":         return "happy"
        case "ziggy_sleep":          return "sleeping"
        case "ziggu_cry":            return "sad"
        case "ziggy_tears":          return "missing you"
        case "ziggy_angrywithmark":  return "annoyed"
        case "ziggy_fireangry":      return "heartbroken"
        case "31":                   return "curious"
        default:                     return "happy"
        }
    }

    // Plain left-side text — mood title plus the low-priority activity
    // line — instead of a pill competing with the speech bubble.
    private var moodTitleText: some View {
        VStack(alignment: .leading, spacing: 8) {

            VStack(alignment: .leading, spacing: 0) {
                Text("\(petVM.pet.name) is")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDarkHeroBackground ? .white : .black)
                Text(moodWord)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(
                        isDarkHeroBackground
                        ? Color(red: 1.0, green: 0.42, blue: 0.42)
                        : Color(red: 0.82, green: 0.12, blue: 0.14)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }

            Text(cuteActivityText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDarkHeroBackground ? .white : .black)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Over the sunlit afternoon room: black text and a deep red mood
        // word, lifted by a white halo. Over the dark night/rainy rooms
        // that palette vanishes, so it flips to white text and a lighter
        // coral red, with a dark shadow instead.
        .shadow(
            color: isDarkHeroBackground ? .black.opacity(0.55) : .white.opacity(0.75),
            radius: isDarkHeroBackground ? 5 : 4,
            y: isDarkHeroBackground ? 1 : 0
        )
    }

    // Same cozy room, day and night — sleeping gets the night version,
    // every other mood gets the sunny afternoon one, both replacing the
    // plain gradient. scaledToFill + clipped inside a GeometryReader crops
    // to whatever size the card renders at, so it looks right on every
    // iPhone without needing a per-device fixed crop.
    @ViewBuilder
    private var heroBackground: some View {
        GeometryReader { geo in
            Image(heroBackgroundName)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 40))
    }

    private var heroBackgroundName: String {
        switch currentEmotionImage {
        case "ziggy_sleep": return "nightbackground"
        case "ziggu_cry":   return "cry"
        default:            return "Afternoon"
        }
    }

    /// The rainy and night rooms are both dark enough that the black text
    /// used over the sunlit afternoon room disappears into them.
    private var isDarkHeroBackground: Bool {
        heroBackgroundName != "Afternoon"
    }

    private var speechBubble: some View {
        Text(speechBubbleText)
            .font(.footnote).fontWeight(.bold)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .lineLimit(5).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .bottom) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
                    .rotationEffect(.degrees(180))
                    .offset(y: 9)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    private var feedBar: some View {
        Button {
            showFeedView = true
        } label: {
            HStack(spacing: 5) {
                Text("🍗")
                    .font(.system(size: 15))
                Text("Feed")
                    .font(.subheadline)
                    .fontWeight(.black)
                    .foregroundStyle(.pink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily Question Card

    private var dailyQuestionCard: some View {
        let q          = dailyQ.question
        let myAnswered = !(q?.myAnswer.isEmpty ?? true)
        let bothDone   = q?.bothAnswered ?? false

        return Button { showAnswerSheet = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("🐾").font(.system(size: 13))
                        Text("\(petVM.pet.name) asks today")
                            .font(.caption2).fontWeight(.black)
                            .foregroundStyle(.secondary)
                    }
                    Text(dailyQ.todayQuestion)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(spacing: 3) {
                    if bothDone {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.pink)
                        Text("See answers")
                            .font(.caption2).fontWeight(.black)
                            .foregroundStyle(.pink)
                    } else if myAnswered {
                        Image(systemName: "hourglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.purple)
                        Text("Waiting")
                            .font(.caption2).fontWeight(.black)
                            .foregroundStyle(.purple)
                    } else {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.pink)
                        Text("Answer")
                            .font(.caption2).fontWeight(.black)
                            .foregroundStyle(.pink)
                    }
                }
                .frame(width: 70)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.93, blue: 0.97),
                        Color(red: 0.94, green: 0.93, blue: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.pink.opacity(0.20), lineWidth: 1.5)
            )
            .shadow(color: .pink.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Dock

    // Icon/card size scales with the device's actual width so a wider phone
    // gets proportionally bigger icons instead of the same fixed size
    // looking small and cramped inside a wider card.
    private func actionDock(containerWidth: CGFloat) -> some View {
        let iconSize = min(max(containerWidth * 0.115, 38), 48)
        let cardHeight = min(max(containerWidth * 0.235, 80), 100)

        return HStack(spacing: 12) {
            actionCard(
                systemImage: "paintbrush.pointed.fill", title: "Doodle", subtitle: "Draw",
                color: .purple, iconSize: iconSize, cardMinHeight: cardHeight
            ) { showDoodleView = true }
            actionCard(
                systemImage: "gamecontroller.fill", title: "Play", subtitle: "Games",
                color: .green, iconSize: iconSize, cardMinHeight: cardHeight
            ) { showDrawingGameView = true }
            actionCard(
                systemImage: "camera.fill",
                title: "Instant",
                subtitle: petVM.hasPendingInstant ? "New" : "Snap",
                color: .pink,
                showDot: petVM.hasPendingInstant,
                iconSize: iconSize,
                cardMinHeight: cardHeight
            ) {
                petVM.markInstantSeen()
                showInstantView = true
            }
        }
    }

    // MARK: - Message Panel

    private var messagePanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("Send a little love").font(.subheadline).fontWeight(.black)
                Text("💌").font(.caption)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {

                    addQuickPill

                    ForEach(sortedQuickMessages) { msg in
                        if msg.isCustom {
                            quickPill(msg) { sendQuick(msg) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteCustomQuickMessage(msg)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else {
                            quickPill(msg) { sendQuick(msg) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            customMessageComposer
        }
        .padding(14)
        .background(.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 6)
    }

    private var addQuickPill: some View {
        Button {
            newQuickText = ""
            newQuickEmoji = "💌"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showNewQuickPopup = true
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.caption)
                    .fontWeight(.black)
                Text("New")
                    .font(.caption)
                    .fontWeight(.black)
            }
            .foregroundStyle(.pink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.pink.opacity(0.12)))
            .overlay(
                Capsule().strokeBorder(
                    Color.pink.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
            )
        }
        .buttonStyle(.plain)
    }

    // Compose a reusable one-tap pill. Rides above the keyboard using the
    // same measured keyboard height the floating note bar uses, so the
    // field it focuses is never hidden behind it.
    private var newQuickPopup: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismissNewQuickPopup() }

            VStack {

                Spacer(minLength: 0)

                VStack(spacing: 14) {

                    Text("New one-tap message")
                        .font(.headline)
                        .fontWeight(.black)

                    Text("Save it once, then send it with a single tap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(newQuickEmojiChoices, id: \.self) { emoji in
                                Button {
                                    newQuickEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(
                                            Circle().fill(
                                                newQuickEmoji == emoji
                                                ? Color.pink.opacity(0.22)
                                                : Color.black.opacity(0.05)
                                            )
                                        )
                                        .overlay(
                                            Circle().stroke(
                                                newQuickEmoji == emoji
                                                ? Color.pink.opacity(0.7)
                                                : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    HStack(spacing: 10) {
                        Text(newQuickEmoji)
                            .font(.headline)

                        TextField("Miss you already…", text: $newQuickText)
                            .focused($newQuickFocused)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.next)
                            .onSubmit { goToNewQuickEmotionStep() }
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.pink.opacity(0.25), lineWidth: 1)
                    )
                    // Hard-stops typing at the limit rather than letting it
                    // overrun and truncating on save, so what you see in the
                    // field is exactly what the pill will say.
                    .onChange(of: newQuickText) { _, value in
                        if value.count > quickMessageCharLimit {
                            newQuickText = String(value.prefix(quickMessageCharLimit))
                        }
                    }

                    HStack {
                        Spacer()
                        Text("\(newQuickText.count)/\(quickMessageCharLimit)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                newQuickText.count >= quickMessageCharLimit
                                ? .pink
                                : .secondary
                            )
                    }

                    HStack(spacing: 12) {

                        Button {
                            dismissNewQuickPopup()
                        } label: {
                            Text("Cancel")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Capsule())
                        }

                        Button {
                            goToNewQuickEmotionStep()
                        } label: {
                            Text("Next")
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    newQuickTextIsEmpty
                                    ? AnyShapeStyle(Color.gray.opacity(0.5))
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        .disabled(newQuickTextIsEmpty)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            // Shrinks the area the card centres itself in by exactly the
            // keyboard's height, lifting the whole card clear of it.
            .padding(.bottom, composeKeyboardHeight)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .transition(.opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                newQuickFocused = true
            }
        }
    }

    private var newQuickTextIsEmpty: Bool {
        newQuickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Step two: the face Ziggy wears on your partner's screen whenever this
    // pill is tapped. Same grid as the one-off custom note uses, so both
    // custom flows feel identical.
    private var newQuickEmotionPopup: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { cancelNewQuickEmotionStep() }

            VStack(spacing: 16) {

                Text("How should \(petVM.pet.name) feel? 💭")
                    .font(.headline)
                    .fontWeight(.black)

                HStack(spacing: 8) {
                    Text(newQuickEmoji)
                    Text("\u{201C}\(newQuickText.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                        .italic()
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 14
                ) {
                    ForEach(ziggyEmotions) { emo in
                        Button {
                            saveNewQuickMessage(emotion: emo.id)
                        } label: {
                            VStack(spacing: 6) {
                                Image(emo.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 54)
                                Text(emo.label)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.pink.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.pink.opacity(0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    cancelNewQuickEmotionStep()
                } label: {
                    Text("Back")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                }
            }
            .padding(22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    // Cute popup to pick Ziggy's emotion when sending a custom note
    private var emotionPopup: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showEmotionPopup = false }
                }

            VStack(spacing: 16) {

                Text("How should \(petVM.pet.name) feel? 💭")
                    .font(.headline)
                    .fontWeight(.black)

                Text("\u{201C}\(customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 14
                ) {
                    ForEach(ziggyEmotions) { emo in
                        Button {
                            sendCustomQuickMessage(emotion: emo.id)
                            withAnimation(.easeOut(duration: 0.2)) { showEmotionPopup = false }
                        } label: {
                            VStack(spacing: 6) {
                                Image(emo.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 54)
                                Text(emo.label)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.pink.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.pink.opacity(0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showEmotionPopup = false }
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity)
    }

    // MARK: - Rating Prompt

    /// Shows a cute custom ask once, after a genuinely happy moment (high
    /// love score + a few days together) — only "Yes" triggers Apple's
    /// native review sheet, which decides on its own whether to actually
    /// display it.
    private func checkForRatingPrompt() {
        guard !hasAskedForReview else { return }
        guard
            petVM.pet.loveScore >= 80,
            petVM.pet.relationshipDays >= 3
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showRatingPrompt = true
            }
        }
    }

    private var ratingPromptView: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {

                Image("ziggy_loveeyes")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)

                Text("Enjoying \(petVM.pet.name)? 💕")
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))

                Text("A quick rating helps other couples find us too 🥹")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    hasAskedForReview = true
                    withAnimation(.easeOut(duration: 0.2)) { showRatingPrompt = false }
                    requestReview()
                } label: {
                    Text("Yes, rate us! 😍")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }

                Button {
                    hasAskedForReview = true
                    withAnimation(.easeOut(duration: 0.2)) { showRatingPrompt = false }
                } label: {
                    Text("Not right now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity)
    }

    // MARK: - "You're Connected!" Popup

    /// Watches for the moment BOTH partners are present in the relationship
    /// and celebrates it once — covers whoever generated the code (who's
    /// already on the home screen waiting) and whoever just joined, since
    /// both land here through the same listener.
    private func watchForBothConnected() {
        guard connectedPopupShownForCode != relationshipManager.relationshipCode else { return }

        FirestoreManager.shared.listenForBothConnected { isBothConnected in
            guard isBothConnected else { return }

            DispatchQueue.main.async {
                guard connectedPopupShownForCode != relationshipManager.relationshipCode else { return }
                // Mark shown immediately so a second snapshot can't double-fire.
                connectedPopupShownForCode = relationshipManager.relationshipCode
                FirestoreManager.shared.stopListeningForBothConnected()

                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showConnectedPopup = true
                }
            }
        }
    }

    private var connectedPopupView: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {

                Image("ziggy_loveeyes")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Text("You're Connected! 💞")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))

                Text("You and your partner can now raise \(petVM.pet.name) together 🐾")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showConnectedPopup = false }
                    if !hasShownWidgetWalkthrough {
                        hasShownWidgetWalkthrough = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showWidgetOnboarding = true
                        }
                    }
                } label: {
                    Text("Yay! 🎉")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity)
    }

    // Shown once, on the Home screen, the moment a new doodle arrives —
    // separate from the widget update and from the preview already shown
    // inside Doodle itself.
    private var doodleReceivedPopup: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { petVM.markDoodlePopupSeen() }

            VStack(spacing: 14) {

                Image("ziggy_loveeyes")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Text("New Doodle! 🎨")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))

                Text("\(petVM.doodlePopupSender) drew you something")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                HStack(spacing: 12) {

                    Button {
                        petVM.markDoodlePopupSeen()
                    } label: {
                        Text("Later")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                    }

                    Button {
                        petVM.markDoodlePopupSeen()
                        showDoodleView = true
                    } label: {
                        Text("View 🎨")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity)
    }

    // Shown once, on the Home screen, the moment a new Instant arrives —
    // the mascot expression / action-card badge (driven by
    // `hasPendingInstant`) still persist separately until Instant is opened.
    private var instantReceivedPopup: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { petVM.markInstantPopupSeen() }

            VStack(spacing: 14) {

                Image("ziggy_loveeyes")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Text("New Instant! 📸")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))

                Text("\(petVM.instantPopupSender) sent you a photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                HStack(spacing: 12) {

                    Button {
                        petVM.markInstantPopupSeen()
                    } label: {
                        Text("Later")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                    }

                    Button {
                        petVM.markInstantPopupSeen()
                        petVM.markInstantSeen()
                        showInstantView = true
                    } label: {
                        Text("View 📸")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity)
    }

    // Tapping this opens `floatingComposeBar` right above the keyboard,
    // instead of typing here directly — this row sits mid-page, and typing
    // straight into it left no way to see the text once the keyboard
    // covered it.
    private var customMessageComposer: some View {
        Button {
            // Focus is set from the bar's own onAppear, not a guessed delay
            // here — a fixed delay could fire before the bar has actually
            // mounted, silently failing to raise the keyboard.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showComposeBar = true
            }
        } label: {
            HStack(spacing: 10) {
                Text(customQuickMessage.isEmpty ? "Write your own tiny note" : customQuickMessage)
                    .font(.subheadline)
                    .foregroundColor(customQuickMessage.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(.white.opacity(0.9))
                    .clipShape(Capsule())

                Image(systemName: "paperplane.fill")
                    .font(.headline).foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? .gray : .blue
                    )
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }

    // Pinned above the keyboard by `homeView`'s own keyboard-height
    // tracking — a real floating bar, not a sheet, so there's no modal to
    // dismiss and no delay before the emotion popup that used to cause a
    // second tap.
    private var floatingComposeBar: some View {
        HStack(spacing: 10) {
            TextField("Write your own tiny note", text: $customQuickMessage)
                .focused($composeFocused)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit { sendTappedFromComposer() }
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.pink.opacity(0.25), lineWidth: 1))

            Button {
                sendTappedFromComposer()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline).foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AnyShapeStyle(Color.gray)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .clipShape(Circle())
            }
            .disabled(customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        // Losing focus (tapped outside) with nothing typed closes the bar —
        // otherwise it just sits there empty, looking like a stray second
        // input field once the keyboard goes down.
        .onChange(of: composeFocused) { _, isFocused in
            guard !isFocused,
                  customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showComposeBar = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                composeFocused = true
            }
        }
    }

    private func sendTappedFromComposer() {
        // Resigning focus here (rather than only in the empty-guard below)
        // means the keyboard's own Send key, when the field is empty, goes
        // through the exact same "unfocus with nothing typed closes the
        // bar" path as tapping outside — one rule, not two.
        composeFocused = false

        let trimmed = customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Both changes in the same animation block — no artificial delay
        // between them, which is what caused the "click again" bug (the
        // bar was still mid-dismiss when the popup tried to appear).
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showComposeBar = false
            showEmotionPopup = true
        }
    }

    // MARK: - Helpers

    private func sendQuick(_ msg: QuickMessage) {

        FirestoreManager.shared.sendEmotion(
            title: msg.payload,
            from: UserManager.shared.username,
            type: "love",
            emotion: msg.emotion
        )

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            messageUsage[msg.id, default: 0] += 1
        }
        saveUsage()
    }

    private func sendCustomQuickMessage(emotion: String = "love") {

        let trimmed = customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        FirestoreManager.shared.sendEmotion(
            title: "custom:\(trimmed)",
            from: UserManager.shared.username,
            type: "love",
            emotion: emotion
        )

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            customQuickMessage = ""
        }
    }

    private func goToNewQuickEmotionStep() {

        guard !newQuickTextIsEmpty else { return }

        // Drop the keyboard first so the emotion grid isn't sitting behind
        // it when it appears.
        newQuickFocused = false

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showNewQuickPopup = false
            showNewQuickEmotionPopup = true
        }
    }

    private func cancelNewQuickEmotionStep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showNewQuickEmotionPopup = false
            showNewQuickPopup = true
        }
    }

    private func saveNewQuickMessage(emotion: String) {

        let trimmed = newQuickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = QuickMessage(
            id: "custom_\(UUID().uuidString)",
            emoji: newQuickEmoji,
            label: trimmed,
            // The "custom:" prefix is what the partner's app and the widget
            // already use to render a free-written note, so these send and
            // display exactly like the one-off custom notes do.
            payload: "custom:\(trimmed)",
            emotion: emotion,
            isCustom: true
        )

        customQuickMessages.insert(message, at: 0)
        saveCustomQuickMessages()

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        dismissNewQuickPopup()
    }

    private func dismissNewQuickPopup() {
        newQuickFocused = false
        withAnimation(.easeOut(duration: 0.2)) {
            showNewQuickPopup = false
            showNewQuickEmotionPopup = false
        }
    }

    private func deleteCustomQuickMessage(_ msg: QuickMessage) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            customQuickMessages.removeAll { $0.id == msg.id }
        }
        messageUsage[msg.id] = nil
        saveCustomQuickMessages()
        saveUsage()
    }

    private func loadCustomQuickMessages() {
        if let data = UserDefaults.standard.data(forKey: customQuickKey),
           let list = try? JSONDecoder().decode([QuickMessage].self, from: data) {
            customQuickMessages = list
        }
    }

    private func saveCustomQuickMessages() {
        if let data = try? JSONEncoder().encode(customQuickMessages) {
            UserDefaults.standard.set(data, forKey: customQuickKey)
        }
    }

    private func loadUsage() {
        if let data = UserDefaults.standard.data(forKey: usageKey),
           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
            messageUsage = dict
        }
    }

    private func saveUsage() {
        if let data = try? JSONEncoder().encode(messageUsage) {
            UserDefaults.standard.set(data, forKey: usageKey)
        }
    }
}

// MARK: - Invite Connection View

struct InviteConnectionView: View {

    let inviteCode: String
    let onConnected: () -> Void

    @State private var isConnecting = false
    @State private var failed = false

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            FloatingHearts()
                .opacity(0.45)

            VStack(spacing: 22) {
                Image("ziggy_loveeyes")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 170)
                    .shadow(radius: 12)

                VStack(spacing: 8) {
                    Text(failed ? "Invite needs a retry" : "Joining your Ziggy")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.27, green: 0.24, blue: 0.21))

                    Text(failed ? "Check your connection and try again." : "One moment while Ziggy connects you two.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if failed {
                    Button {
                        connect()
                    } label: {
                        Text("Try Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(red: 0.27, green: 0.24, blue: 0.21))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 28)
                } else {
                    ProgressView()
                        .tint(.pink)
                        .scaleEffect(1.1)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            connect()
        }
    }

    private func connect() {
        guard !isConnecting else { return }

        let code = inviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !code.isEmpty else { return }

        isConnecting = true
        failed = false

        FirestoreManager.shared.joinRelationship(code: code) {
            DispatchQueue.main.async {
                RelationshipManager.shared.saveCode(code)
                onConnected()
                isConnecting = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if isConnecting {
                isConnecting = false
                failed = true
            }
        }
    }
}

// MARK: - Answer Sheet View
// Standalone so it owns its own reveal state cleanly

struct AnswerSheetView: View {

    @ObservedObject var dailyQ: DailyQuestionManager
    var petName: String = "Ziggy"
    let onDismiss: () -> Void

    @State private var revealed      = false
    @State private var showConfetti  = false
    @State private var pulseScale: CGFloat = 1.0

    private var q:          DailyQuestion? { dailyQ.question }
    private var myAnswered: Bool           { !(q?.myAnswer.isEmpty ?? true) }
    private var bothDone:   Bool           { q?.bothAnswered ?? false }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.93, blue: 0.97),
                    Color(red: 0.94, green: 0.93, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Confetti hearts layer
            if showConfetti {
                ConfettiHeartsView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 20)

                Text("🐾 \(petName) asks today")
                    .font(.caption).fontWeight(.black)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                Text(dailyQ.todayQuestion)
                    .font(.title3).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)

                // State content
                if bothDone {
                    if revealed {
                        revealedContent
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        lockedContent
                    }
                } else if myAnswered {
                    waitingContent
                } else {
                    inputContent
                }

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(32)
    }

    // STATE 1 — Input
    private var inputContent: some View {
        VStack(spacing: 12) {
            TextField("Your answer…", text: $dailyQ.myAnswerDraft, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)

            Button {
                let trimmed = dailyQ.myAnswerDraft
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                dailyQ.submitAnswer(trimmed)
                onDismiss()
            } label: {
                Group {
                    if dailyQ.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Label("Send to \(petName)", systemImage: "paperplane.fill")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    dailyQ.myAnswerDraft
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.gray : Color.pink
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(
                dailyQ.myAnswerDraft
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || dailyQ.isSubmitting
            )
        }
        .padding(.horizontal, 24)
    }

    // STATE 2 — I answered, waiting for partner
    private var waitingContent: some View {
        VStack(spacing: 14) {
            if let q {
                answerBubble(name: "You", text: q.myAnswer, tint: .pink)
            }
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.purple.opacity(0.6))
                Text("Waiting for \(q?.partnerName ?? "your partner") to answer…")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.white.opacity(0.7))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
    }

    // STATE 3a — Both answered but LOCKED (pulsing card)
    private var lockedContent: some View {
        VStack(spacing: 16) {
            // Pulsing locked card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.pink.opacity(0.35), lineWidth: 2)
                    )

                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.pink)
                    Text("Both of you answered 💕")
                        .font(.subheadline).fontWeight(.black)
                    Text("Tap to reveal each other's answers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .scaleEffect(pulseScale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.03
                }
            }

            Button { triggerReveal() } label: {
                Label("Reveal Answers ✨", systemImage: "sparkles")
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .pink.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    // STATE 3b — Revealed
    private var revealedContent: some View {
        VStack(spacing: 10) {
            if let q {
                answerBubble(name: "You", text: q.myAnswer, tint: .pink)
                answerBubble(name: q.partnerName, text: q.partnerAnswer, tint: .purple)
            }
            Text("💞 You both answered today")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    private func answerBubble(name: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.subheadline).fontWeight(.black)
                        .foregroundStyle(tint)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.caption2).fontWeight(.black)
                    .foregroundStyle(tint)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func triggerReveal() {
        // Strong haptic — feels like unlocking something
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            revealed = true
        }

        // Success haptic after reveal settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        // Confetti burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { showConfetti = true }
        }
    }
}

// MARK: - Confetti Hearts

struct ConfettiHeartsView: View {

    @State private var animate = false

    private struct Heart: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
        let delay: Double
        let color: Color
    }

    private let hearts: [Heart] = (0..<18).map { i in
        Heart(
            x: CGFloat.random(in: 0.05...0.95),
            size: CGFloat.random(in: 12...26),
            delay: Double(i) * 0.06,
            color: [Color.pink, .purple, .red, .orange].randomElement()!
        )
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(hearts) { h in
                Image(systemName: "heart.fill")
                    .font(.system(size: h.size))
                    .foregroundStyle(h.color.opacity(0.85))
                    .position(
                        x: geo.size.width * h.x,
                        y: animate ? -60 : geo.size.height * 0.55
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.2)
                        .delay(h.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Supporting Types

struct QuickMessage: Identifiable, Codable {
    let id: String
    let emoji: String
    let label: String
    let payload: String
    var emotion: String = "love"
    // User-written pills are stored in UserDefaults and can be deleted;
    // the built-in ones can't.
    var isCustom: Bool = false
}

// MARK: - Ziggy emotions you can send

struct ZiggyEmotion: Identifiable, Equatable {
    let id: String
    let emoji: String
    let image: String
    let label: String
}

let ziggyEmotions: [ZiggyEmotion] = [
    ZiggyEmotion(id: "love",   emoji: "😍", image: "ziggy_loveeyes",      label: "Love"),
    ZiggyEmotion(id: "happy",  emoji: "😊", image: "ziggy_happie",        label: "Happy"),
    ZiggyEmotion(id: "sleepy", emoji: "😴", image: "ziggy_sleep",         label: "Sleepy"),
    ZiggyEmotion(id: "sad",    emoji: "🥺", image: "ziggu_cry",           label: "Sad"),
    ZiggyEmotion(id: "miss",   emoji: "😢", image: "ziggy_tears",         label: "Miss U"),
    ZiggyEmotion(id: "grr",    emoji: "😤", image: "ziggy_angrywithmark", label: "Grr")
]

func ziggyEmotionImage(for id: String) -> String {
    ziggyEmotions.first { $0.id == id }?.image ?? ""
}

@ViewBuilder
func quickPill(_ msg: QuickMessage, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 9) {
            Text(msg.emoji).font(.headline)
            Text(msg.label).font(.caption).fontWeight(.black).foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Capsule().fill(.white.opacity(0.94)))
        .overlay(Capsule().stroke(Color.orange.opacity(0.18), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.08), radius: 7, y: 3)
    }
    .buttonStyle(.plain)
}

func actionCard(
    systemImage: String,
    title: String,
    subtitle: String,
    color: Color,
    showDot: Bool = false,
    iconSize: CGFloat = 38,
    cardMinHeight: CGFloat = 80,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize * 0.44, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: iconSize, height: iconSize)
                    .background(Circle().fill(color.opacity(0.16)))
                    .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1.5))
                if showDot {
                    Circle().fill(.red).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
            VStack(spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.black).foregroundStyle(.primary)
                Text(subtitle).font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.78)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.20), lineWidth: 1.5))
        .shadow(color: color.opacity(0.12), radius: 10, y: 6)
    }
    .buttonStyle(.plain)
}

#Preview {
    ContentView()
}
