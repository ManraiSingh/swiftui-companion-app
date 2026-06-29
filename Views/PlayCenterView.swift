import SwiftUI

struct PlayCenterView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var showTraceGame = false
    @State private var showPizzaGame = false
    @State private var showAirHockey = false

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

                        Text("Ziggy Play Center")
                            .font(.title2)
                            .fontWeight(.black)

                        Text("Pick a tiny date-night game and make Ziggy very, very spoiled.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 24))

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
                        emoji: "🍕",
                        title: "Pizza for Ziggy",
                        subtitle: "Build Ziggy's dream pizza together, bake it, then feed him.",
                        tint: .orange
                    ) {
                        showPizzaGame = true
                    }

                    gameCard(
                        emoji: "🏒",
                        title: "Air Hockey",
                        subtitle: "Grab one phone, a paddle each — first to 11 wins!",
                        tint: .blue
                    ) {
                        showAirHockey = true
                    }
                }

                Spacer()
            }
            .padding()
        }
        .fullScreenCover(
            isPresented: $showTraceGame
        ) {

            DrawingGameView(
                petVM: petVM
            )
        }
        .fullScreenCover(
            isPresented: $showPizzaGame
        ) {

            PizzaMakingGameView(
                petVM: petVM
            )
        }
        .fullScreenCover(
            isPresented: $showAirHockey
        ) {

            AirHockeyGameView(
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
    }

    private func gameCard(
        emoji: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 14) {

                Text(emoji)
                    .font(.system(size: 38))
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
}

#Preview {
    PlayCenterView(
        petVM: PetViewModel()
    )
}
