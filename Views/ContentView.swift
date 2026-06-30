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

struct ContentView: View {
    @AppStorage("ziggy_username")
    private var username = ""
    @StateObject private var petVM = PetViewModel()
    @StateObject private var dailyQ = DailyQuestionManager.shared

    @State private var showFeedView        = false
    @State private var showInstantView     = false
    @State private var showDrawingGameView = false
    @State private var showAnswerSheet     = false

    @StateObject private var relationshipManager = RelationshipManager.shared

    @State private var messageUsage: [String: Int] = [:]
    @State private var customQuickMessage = ""
    private let usageKey = "ziggy_quick_usage"

    @FocusState private var noteFocused: Bool

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

    private var sortedQuickMessages: [QuickMessage] {
        allQuickMessages
            .enumerated()
            .sorted { a, b in
                let ua = messageUsage[a.element.id] ?? 0
                let ub = messageUsage[b.element.id] ?? 0
                if ua != ub { return ua > ub }
                return a.offset < b.offset
            }
            .map { $0.element }
    }

    // MARK: - Body

    var body: some View {
        if !hasSeenWelcome {
            WelcomeCarouselView {
                withAnimation { hasSeenWelcome = true }
            }
        } else if username.isEmpty {
            OnboardingView()
        } else if !relationshipManager.isConnected {
            RelationshipSetupView()
        } else {
            TabView {
                homeView
                    .tabItem { Label("Home", systemImage: "house.fill") }
                ActivityView(petVM: petVM)
                    .tabItem { Label("Activity", systemImage: "clock.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .onAppear {
                loadUsage()
                dailyQ.startListening()
                UserDefaults(suiteName: "group.com.manrai.ziggy")?
                    .set(Date(), forKey: "last_app_open_time")
            }
        }
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
        switch petVM.pet.lastAction {
        case "Fed Ziggy 🍖":            return "🍖 \(person) fed me!"
        case "Played with Ziggy 🎾":    return "❤️ I love seeing you guys play together ❤️"
        case "Made Pizza for Ziggy 🍕": return "🍕 Ziggy devoured your couple pizza!"
        case "Sent a Hug ❤️":           return "\(person) hugged me!"
        default:                         return "🐶 Waiting for someone..."
        }
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

            VStack(spacing: 13) {
                compactHeader
                ziggyHero
                dailyQuestionCard
                actionDock
                messagePanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if showEmotionPopup {
                emotionPopup
                    .zIndex(10)
            }
        }
        .fullScreenCover(isPresented: $showFeedView)        { FeedView(petVM: petVM) }
        .fullScreenCover(isPresented: $showInstantView)     { InstantView(petVM: petVM) }
        .fullScreenCover(isPresented: $showDrawingGameView) { PlayCenterView(petVM: petVM) }
        .sheet(isPresented: $showAnswerSheet) {
            AnswerSheetView(dailyQ: dailyQ) {
                showAnswerSheet = false
            }
        }
    }

    // MARK: - Header

    private var compactHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You two & Ziggy 💞")
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

    private var ziggyHero: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 40)
                .fill(LinearGradient(
                    colors: moodSurfaceColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(alignment: .topLeading) { sparkleCluster.padding(20) }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(22)
                }

            VStack(spacing: 2) {
                speechBubble.padding(.horizontal, 18)
                Image(currentEmotionImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 130)
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)

            activityTag.padding(.bottom, 14)
        }
        .frame(height: 270)
    }

    private var moodSurfaceColors: [Color] {
        switch petVM.pet.loveScore {
        case 80...100: return [Color(red: 1.0, green: 0.86, blue: 0.72), Color(red: 0.82, green: 0.95, blue: 0.87)]
        case 50..<80:  return [Color(red: 0.83, green: 0.93, blue: 1.0), Color(red: 0.93, green: 0.90, blue: 1.0)]
        default:       return [Color(red: 1.0, green: 0.83, blue: 0.78), Color(red: 0.87, green: 0.90, blue: 0.95)]
        }
    }

    private var sparkleCluster: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sparkle")
            Image(systemName: "heart.fill").font(.caption)
            Image(systemName: "sparkles")
        }
        .foregroundStyle(.white.opacity(0.8))
    }

    private var speechBubble: some View {
        Text(speechBubbleText)
            .font(.headline).fontWeight(.bold)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .lineLimit(3).minimumScaleFactor(0.84)
            .padding(.horizontal, 18).padding(.vertical, 13)
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

    private var activityTag: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.orange)
            Text(cuteActivityText)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 15).padding(.vertical, 9)
        .background(.white.opacity(0.97))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.orange.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 9, y: 4)
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
                        Text("Ziggy asks today")
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

    private var actionDock: some View {
        HStack(spacing: 12) {
            actionCard(systemImage: "fork.knife",         title: "Feed",    subtitle: "Care",  color: .orange) { showFeedView = true }
            actionCard(systemImage: "gamecontroller.fill", title: "Play",   subtitle: "Games", color: .green)  { showDrawingGameView = true }
            actionCard(
                systemImage: "camera.fill",
                title: "Instant",
                subtitle: petVM.hasPendingInstant ? "New" : "Snap",
                color: .pink,
                showDot: petVM.hasPendingInstant
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
                    ForEach(sortedQuickMessages) { msg in
                        quickPill(msg) { sendQuick(msg) }
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

    // Cute popup to pick Ziggy's emotion when sending a custom note
    private var emotionPopup: some View {

        ZStack {

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showEmotionPopup = false }
                }

            VStack(spacing: 16) {

                Text("How should Ziggy feel? 💭")
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

    private var customMessageComposer: some View {
        HStack(spacing: 10) {
            TextField("Write your own tiny note", text: $customQuickMessage)
                .focused($noteFocused)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit {
                    guard !customQuickMessage
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showEmotionPopup = true
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(.white.opacity(0.9))
                .clipShape(Capsule())

            Button {
                noteFocused = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showEmotionPopup = true
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline).foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? .gray : .blue
                    )
                    .clipShape(Circle())
            }
            .disabled(customQuickMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

// MARK: - Answer Sheet View
// Standalone so it owns its own reveal state cleanly

struct AnswerSheetView: View {

    @ObservedObject var dailyQ: DailyQuestionManager
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

                Text("🐾 Ziggy asks today")
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
                        Label("Send to Ziggy", systemImage: "paperplane.fill")
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

struct QuickMessage: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let payload: String
    var emotion: String = "love"
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
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(color.opacity(0.16)))
                    .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1.5))
                if showDot {
                    Circle().fill(.red).frame(width: 13, height: 13)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
            VStack(spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.black).foregroundStyle(.primary)
                Text(subtitle).font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.78)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.20), lineWidth: 1.5))
        .shadow(color: color.opacity(0.12), radius: 10, y: 6)
    }
    .buttonStyle(.plain)
}

#Preview {
    ContentView()
}
