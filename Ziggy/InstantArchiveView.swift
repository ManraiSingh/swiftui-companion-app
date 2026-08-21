//
//  InstantArchiveView.swift
//  Ziggy
//
//  Every instant the two of you have sent.
//
//  An instant is deliberately fleeting — the next one replaces it, which is
//  what makes sending one feel light. This is the other half of that: the
//  photos are kept as well, so a year later there is something to scroll back
//  through.
//
//  Lives in `Ziggy/` rather than `Views/` because that folder is a synchronised
//  group in the project — a file added there joins the target on its own,
//  where one added to `Views/` would not build until somebody opened Xcode.
//

import SwiftUI

/// One instant that was kept.
struct ArchivedInstant: Identifiable, Equatable {
    let id: String
    let imageBase64: String
    let caption: String
    let sender: String
    let senderDeviceID: String
    let sentAt: Date
}

// MARK: - Decoded photo cache

/// Base64 to UIImage, once per photo.
///
/// A grid of a hundred thumbnails would otherwise decode every one of them on
/// every scroll pass, which is the difference between a list that glides and
/// one that stutters.
private final class InstantImageCache {

    static let shared = InstantImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() { cache.countLimit = 120 }

    func image(for id: String, base64: String) -> UIImage? {

        if let hit = cache.object(forKey: id as NSString) { return hit }

        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }

        cache.setObject(image, forKey: id as NSString)
        return image
    }

    func forget(_ id: String) {
        cache.removeObject(forKey: id as NSString)
    }
}

// MARK: - The grid

struct InstantArchiveView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var kept: [ArchivedInstant] = []
    @State private var opened: ArchivedInstant?
    @State private var isLoading = true
    @State private var paywall: PaywallReason?

    @StateObject private var subscription = ZiggySubscription.shared

    /// Whether this one is past the free tier's reach.
    ///
    /// Old instants stay in the grid, frosted, rather than disappearing. A
    /// photograph you can see but not open is an argument for subscribing;
    /// a photograph quietly removed just reads as the app having lost it.
    private func locked(_ instant: ArchivedInstant) -> Bool {
        guard let horizon = subscription.instantHorizon else { return false }
        return instant.sentAt < horizon
    }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                if isLoading {
                    Spacer()
                    ProgressView().tint(accent)
                    Spacer()
                } else if kept.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    grid
                }
            }
        }
        .onAppear {
            FirestoreManager.shared.startInstantArchive { instants in
                kept = instants
                isLoading = false
            }
        }
        .onDisappear {
            FirestoreManager.shared.stopInstantArchive()
        }
        .fullScreenCover(item: $opened) { instant in
            InstantDetailView(instant: instant)
        }
        .paywall($paywall)
    }

    private var header: some View {

        HStack {

            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back").fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }

            Spacer()

            Text(kept.isEmpty ? "Memories" : "\(kept.count) Memories")
                .font(.headline)
                .foregroundColor(accent)

            Spacer()

            // Balances the back button so the title stays centred.
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back").fontWeight(.semibold)
            }
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var grid: some View {

        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(kept) { instant in
                    thumbnail(instant)
                        .onTapGesture {
                            if locked(instant) {
                                paywall = .oldInstants
                            } else {
                                opened = instant
                            }
                        }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
    }

    private func thumbnail(_ instant: ArchivedInstant) -> some View {

        ZStack(alignment: .bottomLeading) {

            // The picture is cut to the tile *before* anything is laid on top
            // of it. Filling overflows the tile by design, so a stack sized to
            // the overflowing image put the date below the visible area and
            // the clip took the bottom half of it off.
            Group {
                if let image = InstantImageCache.shared.image(
                    for: instant.id,
                    base64: instant.imageBase64
                ) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .clipped()
            .blur(radius: locked(instant) ? 11 : 0)
            .overlay {
                if locked(instant) {
                    ZStack {
                        Color.white.opacity(0.28)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    }
                }
            }

            // A date on every tile, because the whole point of looking back is
            // knowing when.
            Text(instant.sentAt, format: .dateTime.day().month(.abbreviated))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(6)
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {

        VStack(spacing: 12) {

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(accent.opacity(0.5))

            Text("No instants yet")
                .font(.headline)
                .foregroundColor(accent)

            Text("Every instant you send each other\nis kept here from now on 💕")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - One instant, full screen

private struct InstantDetailView: View {

    let instant: ArchivedInstant

    @Environment(\.dismiss) private var dismiss

    @State private var toast = ""
    @State private var showingDeleteConfirm = false
    @State private var paywall: PaywallReason?

    private var isMine: Bool { FirestoreManager.shared.isMine(instant) }

    private var image: UIImage? {
        InstantImageCache.shared.image(for: instant.id, base64: instant.imageBase64)
    }

    var body: some View {

        ZStack {

            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {

                Spacer(minLength: 0)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 14)
                }

                if !instant.caption.isEmpty {
                    Text(instant.caption)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                VStack(spacing: 3) {

                    Text(isMine ? "You sent this" : "From \(displaySender)")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(instant.sentAt, format: .dateTime.weekday(.wide)
                            .day().month(.wide).year())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                actions
            }

            if !toast.isEmpty {
                Text(toast)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.black.opacity(0.75)))
                    .transition(.opacity)
                    .padding(.bottom, 140)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .confirmationDialog(
            "Delete this instant?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                FirestoreManager.shared.deleteArchivedInstant(instant.id)
                InstantImageCache.shared.forget(instant.id)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It will be gone for both of you.")
        }
        .paywall($paywall)
    }

    private var displaySender: String {
        instant.sender.isEmpty ? "your partner" : instant.sender
    }

    private var actions: some View {

        HStack(spacing: 10) {

            action("Close", "xmark") { dismiss() }

            action("Save", "square.and.arrow.down") {
                guard let image else { return }
                guard ZiggySubscription.shared.canSaveToPhotos else {
                    paywall = .savePhoto
                    return
                }
                ZiggyPhotoSaver.save(image) { outcome in
                    switch outcome {
                    case .saved:  flash("Saved to Photos 📸")
                    case .denied: flash("Allow photo access in Settings")
                    case .failed: flash("Could not save, try again")
                    }
                }
            }

            // Only what you sent. Taking back your own is fair; deleting what
            // your partner gave you is not yours to do.
            if isMine {
                action("Delete", "trash", tint: Color(red: 1, green: 0.45, blue: 0.45)) {
                    showingDeleteConfirm = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private func action(
        _ label: String,
        _ icon: String,
        tint: Color = .white,
        perform: @escaping () -> Void
    ) -> some View {

        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = "" }
        }
    }
}
