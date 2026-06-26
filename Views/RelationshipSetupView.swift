import SwiftUI

struct RelationshipSetupView: View {

    @State private var joinCode = ""
    @State private var generatedCode = ""
    @State private var showGeneratedCode = false
    @State private var bounce = false

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var canJoin: Bool {
        !joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            FloatingHearts()
                .opacity(0.45)

            ScrollView(showsIndicators: false) {

                VStack(spacing: 24) {

                    Spacer(minLength: 30)

                    ZStack {

                        Circle()
                            .fill(Color.pink.opacity(0.14))
                            .frame(width: 200, height: 200)

                        Image("ziggy_loveeyes")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                            .scaleEffect(bounce ? 1.05 : 0.97)
                            .animation(
                                .easeInOut(duration: 1.4)
                                    .repeatForever(autoreverses: true),
                                value: bounce
                            )
                    }

                    VStack(spacing: 8) {

                        Text("One Ziggy, Two Hearts 💞")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(accent)
                            .multilineTextAlignment(.center)

                        Text("Connect with your partner so you\ncan raise Ziggy together 🐾")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Generate code card
                    VStack(spacing: 14) {

                        Text("Start a new connection")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(accent)

                        Button {

                            generatedCode = generateCode()
                            showGeneratedCode = true

                        } label: {

                            Label("Generate Code", systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(
                                        colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.9))
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    .padding(.horizontal, 22)

                    // OR divider
                    HStack {
                        line
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        line
                    }
                    .padding(.horizontal, 40)

                    // Join code card
                    VStack(spacing: 14) {

                        Text("Already have a code?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(accent)

                        HStack(spacing: 10) {

                            Image(systemName: "key.fill")
                                .foregroundColor(.pink.opacity(0.7))

                            TextField("Enter your love code", text: $joinCode)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                        }
                        .padding(14)
                        .background(.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button {

                            let code = joinCode
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .uppercased()

                            guard !code.isEmpty else { return }

                            RelationshipManager.shared.saveCode(code)

                        } label: {

                            Text("Join 💕")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(canJoin ? accent : accent.opacity(0.35))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!canJoin)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.9))
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    .padding(.horizontal, 22)

                    Spacer(minLength: 30)
                }
            }
        }
        .onAppear { bounce = true }
        .alert(
            "Your Love Code 💞",
            isPresented: $showGeneratedCode
        ) {

            Button("Copy") {
                UIPasteboard.general.string = generatedCode
            }

            Button("OK") {
                RelationshipManager.shared.saveCode(generatedCode)
                FirestoreManager.shared.createRelationshipIfNeeded()
            }

        } message: {

            Text(
                """
                Share this code with your partner:

                \(generatedCode)
                """
            )
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1)
    }

    func generateCode() -> String {

        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let numbers = "123456789"

        let randomLetters = String(
            (0..<3).map { _ in letters.randomElement()! }
        )

        let randomNumbers = String(
            (0..<3).map { _ in numbers.randomElement()! }
        )

        return randomLetters + randomNumbers
    }
}

#Preview {
    RelationshipSetupView()
}
