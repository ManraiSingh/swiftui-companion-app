//
//  ZiggyParkNotes.swift
//  Ziggy
//
//  Love notes, hidden in the park for each other.
//
//  Stand anywhere — under the cherry blossom, at the end of the wisteria,
//  on the bank of the heart-shaped lake — and leave a note right there. It
//  waits for your partner as a little pink envelope floating in the air,
//  sparkling, with a soft beam of light above it so it can be spotted from
//  across the park. When they open the park, a compass at the top of the
//  screen says a note is waiting and which way to walk; when they reach
//  it, they open it, and it bursts into hearts. You hear that they found it.
//
//  So every walk has something to look for, and something to leave.
//
//  Notes live in `relationships/{code}/games/ziggyPark/notes`, one document
//  each, until they are read.
//

import RealityKit
import SwiftUI

struct ParkNote: Identifiable, Equatable {
    let id: String
    let text: String
    let position: SIMD2<Float>
    /// Left by you, waiting for your partner — rather than one for you.
    let mine: Bool
    let name: String
    let at: Date
}

// MARK: - In the world

@available(iOS 18.0, *)
final class ParkNotes {

    let root = Entity()

    private struct Shown {
        let note: ParkNote
        let entity: Entity
        let letter: Entity
        let sparkles: [Entity]
        let phase: Float
    }

    private var shown: [String: Shown] = [:]
    private var clock: Float = 0

    /// Shows exactly these notes: new ones appear, read ones go.
    func show(_ notes: [ParkNote]) {
        let ids = Set(notes.map(\.id))
        for (id, item) in shown where !ids.contains(id) {
            item.entity.removeFromParent()
            shown[id] = nil
        }
        for note in notes where shown[note.id] == nil {
            shown[note.id] = make(note)
        }
    }

    /// The unread note for you closest to `p`, if you are beside it.
    func nearestForMe(to p: SIMD3<Float>, within reach: Float) -> ParkNote? {
        shown.values
            .filter { !$0.note.mine }
            .map { ($0.note, simd_distance($0.note.position, SIMD2(p.x, p.z))) }
            .filter { $0.1 < reach }
            .min { $0.1 < $1.1 }?.0
    }

    /// The closest note waiting for you anywhere in the park.
    func closestForMe(to p: SIMD3<Float>) -> ParkNote? {
        shown.values.map(\.note).filter { !$0.mine }
            .min { simd_distance($0.position, SIMD2(p.x, p.z)) < simd_distance($1.position, SIMD2(p.x, p.z)) }
    }

    /// Takes a note away once it is opened, and says where it was.
    func open(_ id: String) -> SIMD3<Float>? {
        guard let item = shown[id] else { return nil }
        let at = item.letter.position(relativeTo: nil)
        item.entity.removeFromParent()
        shown[id] = nil
        return at
    }

    private func make(_ note: ParkNote) -> Shown {
        let holder = Entity()
        holder.position = [note.position.x, 0, note.position.y]
        let letter = Entity()
        let paper: UInt32 = note.mine ? 0xE6DBFF : 0xFFD3DF
        let flap: UInt32 = note.mine ? 0xCBB8F5 : 0xFF9DB7
        var body = MeshBatch(), fold = MeshBatch(), seal = MeshBatch()
        body.box([0, 0, 0], [0.36, 0.24, 0.03])
        fold.blade([-0.18, 0.12, 0.018], [0.18, 0.12, 0.018], [0, -0.01, 0.018])
        fold.blade([-0.18, 0.12, -0.018], [0.18, 0.12, -0.018], [0, -0.01, -0.018])
        seal.blob([-0.022, 0.005, 0.03], [0.028, 0.028, 0.01], rings: 5, segments: 8)
        seal.blob([0.022, 0.005, 0.03], [0.028, 0.028, 0.01], rings: 5, segments: 8)
        seal.tube(base: [0, -0.045, 0.03], height: 0.04, radius: 0, topRadius: 0.042, segments: 10)
        if let e = body.entity(ParkPaint.glow(UIColor(paper))) { letter.addChild(e) }
        if let e = fold.entity(ParkPaint.glow(UIColor(flap))) { letter.addChild(e) }
        if let e = seal.entity(ParkPaint.glow(UIColor(note.mine ? 0x9B7FE6 : 0xF0436A))) { letter.addChild(e) }
        letter.attach(ParkMesh.sphere(0.34), ParkPaint.clear(UIColor(paper), opacity: 0.18, roughness: 1))
        letter.position = [0, 1.15, 0]
        holder.addChild(letter)

        var sparkles: [Entity] = []
        if !note.mine {
            // A soft beam of light straight up, so it can be found from
            // across the park.
            holder.attach(.generateCylinder(height: 7, radius: 0.12), ParkPaint.clear(UIColor(0xFFB3C7), opacity: 0.16, roughness: 1), at: [0, 4.3, 0])
            for _ in 0..<4 {
                let s = ModelEntity(mesh: ParkMesh.sphere(0.025), materials: [ParkPaint.glow(UIColor(0xFFF2B0))])
                holder.addChild(s)
                sparkles.append(s)
            }
        } else {
            letter.scale = .init(repeating: 0.75)
        }
        root.addChild(holder)
        return Shown(note: note, entity: holder, letter: letter, sparkles: sparkles, phase: .random(in: 0...6))
    }

    func update(deltaTime dt: Float) {
        clock += dt
        for item in shown.values {
            let t = clock + item.phase
            item.letter.position.y = (item.note.mine ? 0.9 : 1.15) + sin(t * 1.6) * 0.08
            item.letter.orientation = spin(t * 0.9, [0, 1, 0]) * spin(sin(t * 1.3) * 0.15, [0, 0, 1])
            for (k, s) in item.sparkles.enumerated() {
                let a = t * 1.4 + Float(k) / Float(item.sparkles.count) * 2 * .pi
                s.position = [cos(a) * 0.38, 1.15 + sin(t * 2 + Float(k)) * 0.2, sin(a) * 0.38]
                s.scale = .init(repeating: 0.6 + abs(sin(t * 3 + Float(k))) * 0.8)
            }
        }
    }
}

// MARK: - On screen

private let pink = Color(red: 0.93, green: 0.36, blue: 0.53)

/// "Manrai's note · 42 m", with an arrow pointing the way.
@available(iOS 18.0, *)
struct ParkNoteCompass: View {

    let name: String
    let metres: Int
    /// Which way to walk, relative to straight up the screen, in degrees.
    let bearing: Double
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(pink))
                .symbolEffect(.bounce, options: .repeating.speed(0.4))
            VStack(alignment: .leading, spacing: 0) {
                Text(count > 1 ? "\(count) notes from \(name)" : "A note from \(name)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(pink)
                Text(metres < 3 ? "Right here!" : "\(metres) m away")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(pink)
                .rotationEffect(.degrees(bearing))
                .animation(.easeOut(duration: 0.3), value: bearing)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.94)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

/// Pops up when you are standing at a note.
@available(iOS 18.0, *)
struct ParkOpenNoteButton: View {

    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.74), pink], startPoint: .top, endPoint: .bottom)))
                    .overlay(alignment: .topTrailing) {
                        ParkHeartShape().fill(.white).frame(width: 11, height: 10)
                            .overlay(ParkHeartShape().fill(pink).padding(1.5))
                            .offset(x: 2, y: -1)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Open \(name)'s note")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(pink)
                    Text("Left here just for you")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.96)))
            .overlay(Capsule().stroke(pink.opacity(0.5), lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// Bottom left: leave a note where you are standing.
@available(iOS 18.0, *)
struct ParkLeaveNoteButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(
                        LinearGradient(colors: [Color(red: 0.99, green: 0.6, blue: 0.72), Color(red: 0.8, green: 0.55, blue: 0.95)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                Text("Leave a note")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The note, opened: a little paper card with washi tape across the top.
@available(iOS 18.0, *)
struct ParkNoteCard: View {

    let note: ParkNote
    let close: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("From \(note.name.isEmpty ? "your love" : note.name)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(pink)
                Spacer()
                Text(note.at, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(note.text)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(Color(red: 0.32, green: 0.22, blue: 0.26))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 70)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { k in
                    Image(systemName: "heart.fill").font(.system(size: 9 + CGFloat(k) * 3)).foregroundStyle(pink.opacity(0.35 + Double(k) * 0.2))
                }
            }
            Button(action: close) {
                Text("Keep walking")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(pink))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 18)
        .frame(width: 290)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 1, green: 0.985, blue: 0.96))
                .shadow(color: .black.opacity(0.22), radius: 18, y: 6)
        )
        .overlay(alignment: .top) {
            // Washi tape holding it up.
            Rectangle()
                .fill(Color(red: 1, green: 0.72, blue: 0.8).opacity(0.85))
                .frame(width: 90, height: 22)
                .rotationEffect(.degrees(-4))
                .offset(y: -9)
        }
        .rotationEffect(.degrees(shown ? -1.5 : -8))
        .scaleEffect(shown ? 1 : 0.6)
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.45)) { shown = true } }
    }
}
