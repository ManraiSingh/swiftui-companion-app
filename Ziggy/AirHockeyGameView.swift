//
//  AirHockeyGameView.swift
//  Ziggy
//
//  Networked 2-device air hockey. Host runs the puck physics and syncs
//  state via Firestore; each player controls their own paddle. First to 11.
//

import SwiftUI
import Combine

struct AirHockeyGameView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var petVM: PetViewModel

    // Virtual field (shared coordinate space across both devices)
    private let VW: CGFloat = 300
    private let VH: CGFloat = 600
    private let puckR: CGFloat = 15
    private let paddleR: CGFloat = 32
    private let goalW: CGFloat = 130
    private let winning = 11
    private let maxSpeed: CGFloat = 14

    // Networking / role
    @State private var role: String? = nil          // "host" / "guest"
    @State private var status = "connecting"          // connecting/waiting/lobby/playing/finished
    @State private var winner = ""
    @State private var hostScore = 0
    @State private var guestScore = 0
    @State private var hostReady = false
    @State private var guestReady = false

    // Entities (virtual coords)
    @State private var puck = CGPoint(x: 150, y: 300)
    @State private var vel = CGVector(dx: 0, dy: 0)
    @State private var puckTarget = CGPoint(x: 150, y: 300)   // guest authoritative target
    @State private var hostPaddle = CGPoint(x: 150, y: 520)
    @State private var guestPaddle = CGPoint(x: 150, y: 80)

    @State private var served = false
    @State private var lastWrite = Date.distantPast

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var isHost: Bool { role == "host" }
    private var myScore: Int { isHost ? hostScore : guestScore }
    private var partnerScore: Int { isHost ? guestScore : hostScore }
    private var myReady: Bool { isHost ? hostReady : guestReady }
    private var partnerReady: Bool { isHost ? guestReady : hostReady }

    var body: some View {

        GeometryReader { geo in

            let scale = min(geo.size.width / VW, geo.size.height / VH) * 0.99
            let fieldW = VW * scale
            let fieldH = VH * scale
            let origin = CGPoint(
                x: (geo.size.width - fieldW) / 2,
                y: (geo.size.height - fieldH) / 2
            )

            ZStack {

                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.14, blue: 0.20),
                             Color(red: 0.18, green: 0.16, blue: 0.26)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                field(origin: origin, w: fieldW, h: fieldH, scale: scale)

                // Opponent paddle (top), my paddle (bottom)
                paddle(.pink)
                    .frame(width: paddleR * 2 * scale, height: paddleR * 2 * scale)
                    .position(toScreen(isHost ? guestPaddle : hostPaddle, origin: origin, scale: scale))
                paddle(.cyan)
                    .frame(width: paddleR * 2 * scale, height: paddleR * 2 * scale)
                    .position(toScreen(isHost ? hostPaddle : guestPaddle, origin: origin, scale: scale))

                // Puck
                Circle()
                    .fill(.white)
                    .frame(width: puckR * 2 * scale, height: puckR * 2 * scale)
                    .shadow(color: .cyan.opacity(0.7), radius: 8)
                    .position(toScreen(puck, origin: origin, scale: scale))

                // Drag surface — moves my paddle (clamped to my half)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                moveMyPaddle(to: toVirtual(v.location, origin: origin, scale: scale))
                            }
                    )

                scoreboard

                overlay
            }
            .onAppear { join() }
            .onDisappear { FirestoreManager.shared.stopAirHockeyListener() }
            .onReceive(timer) { _ in tick() }
        }
        .statusBarHidden(true)
    }

    // MARK: - Field chrome

    private func field(origin: CGPoint, w: CGFloat, h: CGFloat, scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.42, blue: 0.55),
                                 Color(red: 0.16, green: 0.30, blue: 0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.55), lineWidth: 3))
                .frame(width: w, height: h)
                .position(x: origin.x + w / 2, y: origin.y + h / 2)

            // center line + circle
            Rectangle().fill(.white.opacity(0.5))
                .frame(width: w, height: 2)
                .position(x: origin.x + w / 2, y: origin.y + h / 2)
            Circle().stroke(.white.opacity(0.5), lineWidth: 2)
                .frame(width: 90 * scale, height: 90 * scale)
                .position(x: origin.x + w / 2, y: origin.y + h / 2)

            // goal mouths (top = opponent/pink, bottom = me/cyan)
            Capsule().fill(Color.pink.opacity(0.85))
                .frame(width: goalW * scale, height: 9)
                .position(x: origin.x + w / 2, y: origin.y)
            Capsule().fill(Color.cyan.opacity(0.85))
                .frame(width: goalW * scale, height: 9)
                .position(x: origin.x + w / 2, y: origin.y + h)
        }
    }

    private func paddle(_ color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.9))
            Circle().fill(.white.opacity(0.35)).scaleEffect(0.55)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private var scoreboard: some View {
        VStack {
            HStack {
                chip("Partner  \(partnerScore)", .pink).rotationEffect(.degrees(180))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.subheadline).bold()
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 52)

            Spacer()

            HStack {
                chip("You  \(myScore)", .cyan)
                Spacer()
                chip("First to \(winning)", .white.opacity(0.6))
            }
            .padding(.horizontal, 20).padding(.bottom, 42)
        }
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.headline).fontWeight(.black)
            .foregroundColor(color == .cyan ? .cyan : (color == .pink ? .pink : .white))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.white.opacity(0.12)).clipShape(Capsule())
    }

    @ViewBuilder
    private var overlay: some View {

        if status == "connecting" {
            messageCard("Connecting… 🏒", sub: nil)
        } else if status == "waiting" {
            messageCard("Waiting for your partner", sub: "Ask them to open Play → Air Hockey")
        } else if status == "lobby" {
            readyCard(title: "Get Ready! 🏒", showResult: false)
        } else if status == "finished" || !winner.isEmpty {
            readyCard(title: nil, showResult: true)
        }
    }

    /// Lobby + rematch screen — both players ready up; first to both ready starts.
    private func readyCard(title: String?, showResult: Bool) -> some View {

        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {

                if showResult {
                    Text(winner == role ? "🏆" : "💪").font(.system(size: 56))
                    Text(winner == role ? "You win!" : "Partner wins!")
                        .font(.title).fontWeight(.black).foregroundColor(.white)
                    Text("\(myScore) – \(partnerScore)")
                        .font(.title3).foregroundColor(.white.opacity(0.85))
                } else if let title {
                    Text(title).font(.title).fontWeight(.black).foregroundColor(.white)
                    Text("Tap ready when you're set!")
                        .font(.subheadline).foregroundColor(.white.opacity(0.8))
                }

                // My ready toggle
                Button {
                    if let role {
                        FirestoreManager.shared.setAirHockeyReady(role: role, ready: !myReady)
                    }
                } label: {
                    Text(myReady
                         ? "Ready ✓  (tap to cancel)"
                         : (showResult ? "Rematch 🏒" : "I'm Ready 🏒"))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(myReady ? Color.green.opacity(0.85) : .cyan)
                        .foregroundColor(myReady ? .white : accent)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                // Partner status
                HStack(spacing: 8) {
                    Image(systemName: partnerReady ? "checkmark.circle.fill" : "clock")
                        .foregroundColor(partnerReady ? .green : .white.opacity(0.7))
                    Text(partnerReady ? "Partner is ready" : "Waiting for partner…")
                        .font(.subheadline).foregroundColor(.white.opacity(0.85))
                }

                Button("Close") { dismiss() }
                    .foregroundColor(.white.opacity(0.85)).fontWeight(.semibold)
                    .padding(.top, 4)
            }
            .padding(26).frame(maxWidth: 320)
        }
    }

    private func messageCard(_ title: String, sub: String?) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(title).font(.title2).fontWeight(.black).foregroundColor(.white)
                if let sub {
                    Text(sub).font(.subheadline).foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Coordinate transforms (guest sees the table rotated 180°)

    private func toScreen(_ v: CGPoint, origin: CGPoint, scale: CGFloat) -> CGPoint {
        if isHost {
            return CGPoint(x: origin.x + v.x * scale, y: origin.y + v.y * scale)
        } else {
            return CGPoint(x: origin.x + (VW - v.x) * scale, y: origin.y + (VH - v.y) * scale)
        }
    }

    private func toVirtual(_ s: CGPoint, origin: CGPoint, scale: CGFloat) -> CGPoint {
        if isHost {
            return CGPoint(x: (s.x - origin.x) / scale, y: (s.y - origin.y) / scale)
        } else {
            return CGPoint(x: VW - (s.x - origin.x) / scale, y: VH - (s.y - origin.y) / scale)
        }
    }

    private func moveMyPaddle(to v: CGPoint) {
        let x = min(max(v.x, paddleR), VW - paddleR)
        if isHost {
            let y = min(max(v.y, VH / 2 + paddleR), VH - paddleR)
            hostPaddle = CGPoint(x: x, y: y)
        } else {
            let y = min(max(v.y, paddleR), VH / 2 - paddleR)
            guestPaddle = CGPoint(x: x, y: y)
        }
    }

    // MARK: - Networking

    private func join() {
        FirestoreManager.shared.joinAirHockey(
            name: UserManager.shared.username
        ) { assigned in
            role = assigned
            FirestoreManager.shared.listenAirHockey { data in
                applyRemote(data)
            }
        }
    }

    private func applyRemote(_ data: [String: Any]) {
        DispatchQueue.main.async {

            let newStatus = data["status"] as? String ?? self.status

            // Match (re)starting → reset the board locally so the host serves.
            if newStatus == "playing" && self.status != "playing" {
                self.served = false
                self.puck = CGPoint(x: self.VW / 2, y: self.VH / 2)
                self.vel = .zero
                self.puckTarget = CGPoint(x: self.VW / 2, y: self.VH / 2)
            }

            self.status = newStatus
            self.winner = data["winner"] as? String ?? ""
            self.hostScore = data["hostScore"] as? Int ?? self.hostScore
            self.guestScore = data["guestScore"] as? Int ?? self.guestScore
            self.hostReady = data["hostReady"] as? Bool ?? false
            self.guestReady = data["guestReady"] as? Bool ?? false

            if self.isHost {
                // Host owns puck/scores; only reads opponent (guest) paddle.
                self.guestPaddle = CGPoint(
                    x: data["guestPaddleX"] as? Double ?? Double(self.guestPaddle.x),
                    y: data["guestPaddleY"] as? Double ?? Double(self.guestPaddle.y)
                )
                // A reset from rematch clears the winner & zeroes scores.
                if self.winner.isEmpty && self.hostScore == 0 && self.guestScore == 0 {
                    self.served = false
                }
            } else {
                // Guest reads puck position + velocity (for prediction),
                // host paddle, and scores.
                self.puckTarget = CGPoint(
                    x: data["puckX"] as? Double ?? Double(self.puckTarget.x),
                    y: data["puckY"] as? Double ?? Double(self.puckTarget.y)
                )
                self.vel = CGVector(
                    dx: data["velX"] as? Double ?? 0,
                    dy: data["velY"] as? Double ?? 0
                )
                self.hostPaddle = CGPoint(
                    x: data["hostPaddleX"] as? Double ?? Double(self.hostPaddle.x),
                    y: data["hostPaddleY"] as? Double ?? Double(self.hostPaddle.y)
                )
            }
        }
    }

    // MARK: - Game loop

    private func tick() {
        guard role != nil else { return }

        if isHost {
            guard status == "playing", winner.isEmpty else { return }

            if vel.dx == 0 && vel.dy == 0 && !served {
                served = true
                serve()
            }
            simulate()
            maybeWriteHost()
        } else {
            // Guest: predict using last known velocity (dead reckoning) and
            // gently correct toward the authoritative position — keeps the
            // puck moving smoothly between network updates instead of jumping.
            puck.x += vel.dx + (puckTarget.x - puck.x) * 0.18
            puck.y += vel.dy + (puckTarget.y - puck.y) * 0.18
            if status == "playing" && winner.isEmpty {
                maybeWriteGuestPaddle()
            }
        }
    }

    private func serve() {
        puck = CGPoint(x: VW / 2, y: VH / 2)
        vel = .zero
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard isHost, winner.isEmpty, status == "playing" else { return }
            vel = CGVector(dx: CGFloat.random(in: -2.5...2.5),
                           dy: Bool.random() ? 5.5 : -5.5)
        }
    }

    private func simulate() {
        var p = puck
        var v = vel
        let cx = VW / 2

        p.x += v.dx
        p.y += v.dy

        if p.x < puckR { p.x = puckR; v.dx = -v.dx }
        if p.x > VW - puckR { p.x = VW - puckR; v.dx = -v.dx }

        // Top goal (guest side) → host scores
        if p.y < puckR {
            if abs(p.x - cx) < goalW / 2 { hostScore += 1; afterGoal(); return }
            p.y = puckR; v.dy = -v.dy
        }
        // Bottom goal (host side) → guest scores
        if p.y > VH - puckR {
            if abs(p.x - cx) < goalW / 2 { guestScore += 1; afterGoal(); return }
            p.y = VH - puckR; v.dy = -v.dy
        }

        for pad in [hostPaddle, guestPaddle] {
            let dx = p.x - pad.x, dy = p.y - pad.y
            let dist = max(sqrt(dx * dx + dy * dy), 0.0001)
            let minD = puckR + paddleR
            if dist < minD {
                let nx = dx / dist, ny = dy / dist
                p.x = pad.x + nx * minD
                p.y = pad.y + ny * minD
                let speed = min(sqrt(v.dx * v.dx + v.dy * v.dy) + 3.5, maxSpeed)
                v.dx = nx * speed; v.dy = ny * speed
            }
        }

        v.dx *= 0.999; v.dy *= 0.999
        let sp = sqrt(v.dx * v.dx + v.dy * v.dy)
        if sp > maxSpeed { v.dx = v.dx / sp * maxSpeed; v.dy = v.dy / sp * maxSpeed }

        puck = p
        vel = v
    }

    private func afterGoal() {
        vel = .zero
        if hostScore >= winning {
            winner = "host"; pushHost(status: "finished")
        } else if guestScore >= winning {
            winner = "guest"; pushHost(status: "finished")
        } else {
            served = false
            pushHost(status: "playing")
        }
    }

    private func maybeWriteHost() {
        guard Date().timeIntervalSince(lastWrite) > 0.045 else { return }
        lastWrite = Date()
        pushHost(status: "playing")
    }

    private func pushHost(status: String) {
        FirestoreManager.shared.writeAirHockeyHost(
            puckX: Double(puck.x), puckY: Double(puck.y),
            velX: Double(vel.dx), velY: Double(vel.dy),
            hostScore: hostScore, guestScore: guestScore,
            hostPaddleX: Double(hostPaddle.x), hostPaddleY: Double(hostPaddle.y),
            status: status, winner: winner
        )
    }

    private func maybeWriteGuestPaddle() {
        guard Date().timeIntervalSince(lastWrite) > 0.045 else { return }
        lastWrite = Date()
        FirestoreManager.shared.writeAirHockeyGuestPaddle(
            x: Double(guestPaddle.x), y: Double(guestPaddle.y)
        )
    }
}

#Preview {
    AirHockeyGameView(petVM: PetViewModel())
}
