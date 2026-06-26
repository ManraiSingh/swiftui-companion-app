////
////  ActivityView.swift
////  Ziggy
////
////  Created by Manrai Singh on 14/06/26.
////
//
//import SwiftUI
//
//struct ActivityView: View {
//
//    @ObservedObject var petVM: PetViewModel
//
//    @State private var showClearConfirm = false
//
//    private let cream = LinearGradient(
//        colors: [
//            Color(red: 0.97, green: 0.95, blue: 0.92),
//            Color(red: 0.95, green: 0.92, blue: 0.88)
//        ],
//        startPoint: .top,
//        endPoint: .bottom
//    )
//
//    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)
//
//    var body: some View {
//
//        NavigationStack {
//
//            ZStack {
//
//                cream.ignoresSafeArea()
//
//                if petVM.pet.events.isEmpty {
//
//                    emptyState
//
//                } else {
//
//                    ScrollView(showsIndicators: false) {
//
//                        VStack(spacing: 12) {
//
//                            ForEach(petVM.pet.events) { event in
//                                eventCard(event)
//                            }
//                        }
//                        .padding(.horizontal)
//                        .padding(.top, 8)
//                        .padding(.bottom, 24)
//                    }
//                }
//            }
//            .navigationTitle("Our Memories 💕")
//            .toolbar {
//
//                ToolbarItem(placement: .topBarTrailing) {
//
//                    if !petVM.pet.events.isEmpty {
//
//                        Button {
//                            showClearConfirm = true
//                        } label: {
//                            Image(systemName: "trash")
//                                .foregroundColor(.pink)
//                        }
//                    }
//                }
//            }
//            .confirmationDialog(
//                "Clear all memories?",
//                isPresented: $showClearConfirm,
//                titleVisibility: .visible
//            ) {
//
//                Button("Clear All", role: .destructive) {
//                    withAnimation {
//                        petVM.clearEvents()
//                    }
//                }
//
//                Button("Cancel", role: .cancel) {}
//
//            } message: {
//                Text("This will remove your whole activity timeline.")
//            }
//        }
//    }
//
//    // MARK: - Event Card
//
//    private func eventCard(_ event: Event) -> some View {
//
//        HStack(spacing: 14) {
//
//            Text(emoji(for: event.title))
//                .font(.system(size: 30))
//                .frame(width: 52, height: 52)
//                .background(
//                    Circle().fill(Color.pink.opacity(0.12))
//                )
//
//            VStack(alignment: .leading, spacing: 4) {
//
//                Text(event.title)
//                    .font(.headline)
//                    .foregroundColor(accent)
//
//                Text("by \(event.person)")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//
//                Text(event.timestamp.formatted(
//                    date: .abbreviated,
//                    time: .shortened
//                ))
//                .font(.caption2)
//                .foregroundColor(.gray)
//            }
//
//            Spacer()
//        }
//        .padding(14)
//        .background(
//            RoundedRectangle(cornerRadius: 22)
//                .fill(.white.opacity(0.9))
//        )
//        .shadow(color: .black.opacity(0.06), radius: 7, y: 3)
//    }
//
//    // MARK: - Empty State
//
//    private var emptyState: some View {
//
//        VStack(spacing: 14) {
//
//            Text("🐾")
//                .font(.system(size: 64))
//
//            Text("No memories yet")
//                .font(.title3)
//                .fontWeight(.semibold)
//                .foregroundColor(accent)
//
//            Text("Feed, play and send love —\nyour moments show up here 💕")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//        }
//        .padding()
//    }
//
//    // MARK: - Emoji mapping
//
//    private func emoji(for title: String) -> String {
//
//        if title.contains("Fed") { return "🍖" }
//        if title.contains("Played") { return "🎾" }
//        if title.contains("Hug") { return "❤️" }
//        if title.contains("Instant") { return "📸" }
//        return "✨"
//    }
//}
//
//#Preview {
//    ActivityView(
//        petVM: PetViewModel()
//    )
//}
//
//  ActivityView.swift
//  Ziggy
//

import SwiftUI

struct ActivityView: View {

    @ObservedObject var petVM: PetViewModel
    @StateObject private var dailyQ = DailyQuestionManager.shared

    @State private var selectedTab = 0   // 0 = Moments, 1 = Questions
    @State private var showClearConfirm = false

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.95, blue: 0.92),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    var body: some View {
        NavigationStack {
            ZStack {
                cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment picker
                    picker
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // Content
                    if selectedTab == 0 {
                        momentsTab
                    } else {
                        questionsTab
                    }
                }
            }
            .navigationTitle("Our Memories 💕")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == 0 && !petVM.pet.events.isEmpty {
                        Button { showClearConfirm = true } label: {
                            Image(systemName: "trash").foregroundColor(.pink)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear all memories?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    withAnimation { petVM.clearEvents() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your whole activity timeline.")
            }
        }
    }

    // MARK: - Segment Picker

    private var picker: some View {
        HStack(spacing: 0) {
            pickerTab(title: "Moments 🐾", index: 0)
            pickerTab(title: "Questions 💌", index: 1)
        }
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func pickerTab(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.subheadline).fontWeight(.black)
                .foregroundStyle(selectedTab == index ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedTab == index
                    ? Color(red: 0.27, green: 0.24, blue: 0.21)
                    : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // MARK: - Moments Tab

    private var momentsTab: some View {
        Group {
            if petVM.pet.events.isEmpty {
                emptyMoments
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(petVM.pet.events) { event in
                            eventCard(event)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func eventCard(_ event: Event) -> some View {
        HStack(spacing: 14) {
            Text(emoji(for: event.title))
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.pink.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(accent)
                Text("by \(event.person)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.9)))
        .shadow(color: .black.opacity(0.06), radius: 7, y: 3)
    }

    private var emptyMoments: some View {
        VStack(spacing: 14) {
            Text("🐾").font(.system(size: 64))
            Text("No memories yet")
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(accent)
            Text("Feed, play and send love —\nyour moments show up here 💕")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private func emoji(for title: String) -> String {
        if title.contains("Fed")     { return "🍖" }
        if title.contains("Played")  { return "🎾" }
        if title.contains("Hug")     { return "❤️" }
        if title.contains("Instant") { return "📸" }
        return "✨"
    }

    // MARK: - Questions Tab

    private var questionsTab: some View {
        Group {
            if dailyQ.isLoadingHistory {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(accent)
                    Spacer()
                }
            } else if dailyQ.history.isEmpty {
                emptyQuestions
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(dailyQ.history) { q in
                            QuestionHistoryCard(q: q)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { dailyQ.fetchHistory() }
    }

    private var emptyQuestions: some View {
        VStack(spacing: 14) {
            Text("💌").font(.system(size: 64))
            Text("No answers yet")
                .font(.title3).fontWeight(.semibold)
                .foregroundColor(accent)
            Text("Answer today's question together —\nyour answers build up here 🐾")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Question History Card

struct QuestionHistoryCard: View {

    let q: DailyQuestion

    // Locked until tapped — only if both answered
    @State private var revealed = false
    @State private var showConfetti = false
    @State private var scale: CGFloat = 1.0

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: q.dateKey) else { return q.dateKey }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Date + question
            VStack(alignment: .leading, spacing: 6) {
                Text(formattedDate)
                    .font(.caption2).fontWeight(.black)
                    .foregroundStyle(.secondary)
                Text(q.text)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 12)

            // Answer area
            if q.bothAnswered {
                if revealed {
                    revealedAnswers
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    lockedView
                }
            } else {
                // Only one person answered
                partialAnswer
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.93, blue: 0.97),
                    Color(red: 0.94, green: 0.93, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.pink.opacity(0.18), lineWidth: 1.5)
        )
        .shadow(color: .pink.opacity(0.07), radius: 8, y: 4)
        .scaleEffect(scale)
    }

    // Locked state — both answered but not yet revealed
    private var lockedView: some View {
        Button {
            triggerReveal()
        } label: {
            HStack(spacing: 12) {
                // Two blurred answer previews side by side
                VStack(alignment: .leading, spacing: 3) {
                    Text("You")
                        .font(.caption2).fontWeight(.black).foregroundStyle(.pink)
                    Text(q.myAnswer)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .blur(radius: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(q.partnerName)
                        .font(.caption2).fontWeight(.black).foregroundStyle(.purple)
                    Text(q.partnerAnswer)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .blur(radius: 4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .background(.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.pink.opacity(0.25), lineWidth: 1.5)
            )
            .overlay(
                Text("Tap to reveal 💕")
                    .font(.caption).fontWeight(.black)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.pink.opacity(0.85))
                    .clipShape(Capsule())
            )
        }
        .buttonStyle(.plain)
    }

    // Revealed state — both answers shown as chat bubbles
    private var revealedAnswers: some View {
        VStack(spacing: 8) {
            answerBubble(name: "You", text: q.myAnswer, tint: .pink)
            answerBubble(name: q.partnerName, text: q.partnerAnswer, tint: .purple)

            if showConfetti {
                Text("💞")
                    .font(.title)
                    .scaleEffect(showConfetti ? 1.4 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: showConfetti)
            }
        }
    }

    private func answerBubble(name: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.caption).fontWeight(.black)
                        .foregroundStyle(tint)
                )
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(10)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Only one person answered
    private var partialAnswer: some View {
        HStack(spacing: 10) {
            if !q.myAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("You answered")
                        .font(.caption2).fontWeight(.black).foregroundStyle(.pink)
                    Text(q.myAnswer)
                        .font(.caption).foregroundStyle(.primary).lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if !q.partnerAnswer.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(q.partnerName)
                        .font(.caption2).fontWeight(.black).foregroundStyle(.purple)
                    Text(q.partnerAnswer)
                        .font(.caption).foregroundStyle(.primary).lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Reveal animation

    private func triggerReveal() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Bounce the card
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            scale = 1.04
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }

        // Reveal after tiny delay so the bounce feels like it "unlocks"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                revealed = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        // Confetti heart after reveal settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    ActivityView(petVM: PetViewModel())
}
