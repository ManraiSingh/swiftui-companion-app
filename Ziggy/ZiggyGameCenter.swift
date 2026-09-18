//
//  ZiggyGameCenter.swift
//  Ziggy
//
//  Game Center, wrapped so nothing else in the app has to care whether it
//  is actually available.
//
//  Everything here is best-effort and silent on failure. If the player is
//  signed out of Game Center, has it switched off, or the build simply does
//  not carry the entitlement yet, `authenticate()` leaves `isAuthenticated`
//  false and every other call becomes a no-op. Ziggy Jump keeps its own best
//  score in UserDefaults either way, so the game is completely playable with
//  Game Center unavailable — it just doesn't have anyone to compare against.
//
//  That matters more than it sounds. The entitlement has to be granted on the
//  App ID before it does anything, and until then this file must not be able
//  to break a screen or throw an alert at somebody.
//

import Combine
import GameKit
import SwiftUI
import UIKit

final class ZiggyGameCenter: ObservableObject {

    static let shared = ZiggyGameCenter()

    /// Must match the leaderboard's ID in App Store Connect exactly.
    static let jumpLeaderboardID = "ziggy_jump_high_score"

    @Published private(set) var isAuthenticated = false

    /// Authentication is a one-shot handler that GameKit then owns; setting
    /// it twice re-runs the whole sign-in flow, which can put its own screen
    /// up a second time.
    private var didStart = false

    private init() {}

    func authenticate() {

        guard !didStart else { return }
        didStart = true

        GKLocalPlayer.local.authenticateHandler = { controller, error in

            // GameKit calls this on the main thread, but the closure itself
            // carries no isolation, and a view controller cannot be handed
            // across to one.
            MainActor.assumeIsolated {

                if let controller {
                    Self.topViewController()?.present(controller, animated: true)
                    return
                }

                Self.shared.isAuthenticated = GKLocalPlayer.local.isAuthenticated

                if let error, !GKLocalPlayer.local.isAuthenticated {
                    NSLog("Game Center is unavailable: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Posts a run to the leaderboard. Quietly does nothing if there is
    /// nobody signed in to post it for.
    func submit(score: Int) {

        guard isAuthenticated, score > 0 else { return }

        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.jumpLeaderboardID]
        ) { error in
            if let error {
                NSLog("Could not post the score: \(error.localizedDescription)")
            }
        }
    }

    /// Whatever is currently on screen, so GameKit's sign-in sheet has
    /// something to present from.
    static func topViewController() -> UIViewController? {

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController

        while let presented = top?.presentedViewController {
            top = presented
        }

        return top
    }
}

// MARK: - The leaderboard screen

/// Game Center's own leaderboard UI, as a SwiftUI sheet.
struct GameCenterLeaderboard: UIViewControllerRepresentable {

    @Environment(\.dismiss) private var dismiss

    let leaderboardID: String

    func makeUIViewController(context: Context) -> GKGameCenterViewController {

        let controller = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator { dismiss() }
    }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {

        private let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            onDone()
        }
    }
}
