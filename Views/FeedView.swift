//
//  FeedView.swift
//  Ziggy
//
//  Created by Manrai Singh on 16/06/26.
//

import SwiftUI

struct FeedView: View {
    @AppStorage("hasSeenFeedTutorial")
    private var hasSeenFeedTutorial = false

    @State private var showTutorial = false
    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    @State private var foodOffset =
        CGSize.zero

    @State private var isEating = false
    @State private var showFood = true
    @State private var frameIndex = 0
    @State private var hungerProgress: CGFloat = 0

    let ziggyTarget = CGSize(width: 0, height: 10)
    let frames = [

        "18",
        "19",
        "20",
        "21",
        "22",
        "23",
        "24",
        "26",
        "27",
        "28",
        "29"
    ]

    var body: some View {

        ZStack {
            Image("foodzone")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            if showTutorial {

                ZStack {

                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {

                        Image("30")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120)

                        Text("I'm Hungry! 🥺")
                            .font(.title2)
                            .bold()

                        Text("Drag my food bowl to my face and feed me!")
                            .multilineTextAlignment(.center)

                        Button {

                            withAnimation(.spring()) {
                                showTutorial = false
                                hasSeenFeedTutorial = true
                            }

                        } label: {

                            Text("Let's Feed Ziggy 🍖")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(25)
                    .background(.ultraThinMaterial)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 30
                        )
                    )
                    .padding(.horizontal, 30)
                }
                .zIndex(999)
            }
            VStack {

                HStack {

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {

                            Image(systemName: "chevron.left")

                            Text("Back")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.9))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    }
                    .padding(.leading, 12)
                    .padding(.top, 25)

                    Spacer()

                    

                    Spacer()
                }
                .padding()

                Spacer()
                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brown.opacity(0))
                        .frame(width: 220, height: 18)

//                    RoundedRectangle(cornerRadius: 10)
//                        .fill(
//                            LinearGradient(
//                                colors: [.orange, .red],
//                                startPoint: .leading,
//                                endPoint: .trailing
//                            )
//                            
//                        )
                        .frame(
                            width: 220 * hungerProgress,
                            height: 18
                        )
                }
                .padding(.bottom, 20)
                ZStack {

                    if isEating {

                        Image(frames[frameIndex])
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .offset(y: -20)

                    } else {
                        
                        if frameIndex == frames.count - 1 {

                            Image("29")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .offset(y: -20)

                        } else {

                            Image("30")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .offset(y: 50)
                                .zIndex(0)
                        }
                    }
                }
               

                Spacer()

                if showFood {

                    Image("ziggyfood")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: 220,
                            height: 220
                        )
                        .zIndex(0)
                        .offset(foodOffset)
                        .offset(y: -50)
                        .gesture(

                            DragGesture()

                                .onChanged { value in

                                    foodOffset =
                                        value.translation
                                }

                                .onEnded { value in

                                    if value.translation.height < -220 {

                                        startEating()

                                    } else {

                                        withAnimation(.spring()) {
                                            foodOffset = .zero
                                        }
                                    }
                                }
                        )
                }

                Spacer()            }
        }
        .onAppear {

            if !hasSeenFeedTutorial {

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.5
                ) {

                    withAnimation(.spring()) {
                        showTutorial = true
                    }
                }
            }
        }
    }

    func startEating() {

        guard !isEating else {
            return
        }
        showFood = false
        frameIndex = 0
        isEating = true
        hungerProgress = 0
        foodOffset = .zero
        withAnimation(.easeIn(duration: 0.4)) {

            foodOffset = ziggyTarget
        }
        Timer.scheduledTimer(
            withTimeInterval: 0.20,
            repeats: true
        ) { timer in

            if frameIndex < frames.count - 1 {
                withAnimation(.linear(duration: 0.15)) {

                    hungerProgress =
                        min(
                            CGFloat(frameIndex + 1)
                            / CGFloat(frames.count),
                            1.0
                        )
                }
                frameIndex += 1
            } else {
                timer.invalidate()

                hungerProgress = 1.0

                isEating = false

                foodOffset = .zero

                petVM.feed()

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 1.0
                ) {
                    
                }
            }

            
        }
    }
}
