//
//  InstantView.swift
//  Ziggy
//
//  Created by Manrai Singh on 18/06/26.
//

import SwiftUI
import PhotosUI

struct InstantView: View {

    @ObservedObject private var themes = ThemeManager.shared

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var petVM: PetViewModel

    // Live instant data from Firestore
    @State private var instantData: [String: Any]? = nil
    @State private var isLoading = true

    // Send UI
    @State private var showSendUI = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var caption = ""
    @State private var captionPos = CGPoint(x: 0.5, y: 0.85)
    @State private var isSending = false
    @State private var showCamera = false
    @State private var showSendError = false
    @State private var showArchive = false
    @State private var sendErrorMessage = ""

    private var cream: LinearGradient { themes.theme.gradient }

    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private var me: String { UserManager.shared.username }

    private var sender: String? { instantData?["sender"] as? String }
    private var instantCaption: String? { instantData?["caption"] as? String }
    private var instantCaptionPos: CGPoint {
        CGPoint(
            x: instantData?["captionX"] as? Double ?? 0.5,
            y: instantData?["captionY"] as? Double ?? 0.85
        )
    }
    /// Their photo, decoded once.
    ///
    /// This used to be a computed property that ran `Data(base64Encoded:)`
    /// and `UIImage(data:)` every time it was read — and `body` reads it
    /// twice. So a full-size photo was being decoded twice per render, on
    /// the main thread, for every unrelated state change on the screen.
    /// Decoded off the main thread when the data actually changes instead,
    /// and held here.
    @State private var partnerImage: UIImage?

    /// The base64 the held image was decoded from, so an identical update
    /// from the listener doesn't decode it all over again.
    @State private var partnerImageKey = ""

    private func refreshPartnerImage(from data: [String: Any]?) {

        let b64 = data?["imageBase64"] as? String ?? ""
        guard b64 != partnerImageKey else { return }
        partnerImageKey = b64

        guard !b64.isEmpty else {
            partnerImage = nil
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let decoded = Data(base64Encoded: b64).flatMap(UIImage.init(data:))
            DispatchQueue.main.async {
                // A newer instant may have landed while this was decoding.
                guard b64 == partnerImageKey else { return }
                partnerImage = decoded
            }
        }
    }
    private var isMyInstant: Bool { sender == me }
    private var hasPartnerInstant: Bool {
        instantData != nil && sender != nil && !isMyInstant
    }

    var body: some View {

        ZStack {

            cream.ignoresSafeArea()

            VStack(spacing: 0) {

                header

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(accent)
                    Spacer()
                } else if hasPartnerInstant && !showSendUI {
                    partnerInstantView
                } else if isMyInstant && !showSendUI {
                    waitingView
                } else {
                    sendView
                }
            }
        }
        .onAppear {
            listenForInstant()
        }
        .onDisappear {
            FirestoreManager.shared.stopInstantViewListener()
        }
        .onChange(of: selectedItem) { _, newValue in

            Task {

                if let data = try? await newValue?.loadTransferable(
                    type: Data.self
                ) {
                    await MainActor.run {
                        selectedImage = UIImage(data: data)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {

            CameraPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showArchive) {
            InstantArchiveView()
        }
        .alert("Oops", isPresented: $showSendError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendErrorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {

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
                .foregroundColor(themes.theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(themes.theme.surface(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }

            Spacer()

            Text("Instant")
                .font(.headline)
                .foregroundColor(themes.theme.ink)

            Spacer()

            // The space the invisible balancer was holding, put to use. An
            // instant is replaced by the next one, so this is the only way
            // back to the ones already sent.
            Button {
                showArchive = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                    Text("Memories").fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(themes.theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(themes.theme.surface(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Partner Instant (opens directly)

    private var partnerInstantView: some View {

        VStack(spacing: 12) {

            // A single flexible gap above and below the photo+label block
            // keeps them together and centred, instead of a Spacer between
            // them shoving the label down to the bottom of the screen.
            Spacer(minLength: 0)

            if let img = partnerImage {

                photoCard(
                    image: img,
                    caption: instantCaption ?? "",
                    captionPos: instantCaptionPos,
                    interactive: false
                )
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                .padding(.horizontal, 16)
            }

            if let sender {
                Text("From \(sender)")
                    .font(.subheadline)
                    .foregroundColor(themes.theme.inkSoft)
            }

            Spacer(minLength: 0)

            primaryButton(
                title: "Reply",
                systemImage: "arrow.uturn.left"
            ) {
                withAnimation {
                    showSendUI = true
                    resetComposer()
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Waiting View

    private var waitingView: some View {

        VStack(spacing: 12) {

            Spacer(minLength: 0)

            if let img = partnerImage {

                photoCard(
                    image: img,
                    caption: instantCaption ?? "",
                    captionPos: instantCaptionPos,
                    interactive: false
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.black.opacity(0.04))
                )
                .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
                .padding(.horizontal, 16)
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(accent.opacity(0.7))
                Text("Sent")
                    .foregroundColor(themes.theme.inkSoft)
            }
            .font(.subheadline)

            Spacer(minLength: 0)

            secondaryButton(
                title: "Send another",
                systemImage: "camera"
            ) {
                withAnimation {
                    showSendUI = true
                    resetComposer()
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Send View

    private var sendView: some View {

        GeometryReader { proxy in

        ScrollView {

            VStack(spacing: 14) {

                if let image = selectedImage {

                    photoCard(
                        image: image,
                        caption: caption,
                        captionPos: captionPos,
                        interactive: true
                    )
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)

                } else {

                    // An aspect ratio rather than a fixed 340pt height, so
                    // the drop zone scales with the device's width instead
                    // of leaving a gap on big phones / crowding small ones.
                    RoundedRectangle(cornerRadius: 26)
                        .fill(themes.theme.surface(0.7))
                        .aspectRatio(4.0 / 5.0, contentMode: .fit)
                        .overlay {

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 46, weight: .light))
                                .foregroundColor(accent.opacity(0.35))
                        }
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                        .padding(.horizontal, 16)
                }

                // The picture belongs at the top; everything you actually
                // tap belongs at the bottom, within thumb reach — same shape
                // as the game lobbies.
                Spacer(minLength: 16)

                HStack(spacing: 12) {

                    primaryButton(
                        title: "Take Photo",
                        systemImage: "camera.fill"
                    ) {
                        showCamera = true
                    }

                    secondaryButton(
                        title: "Gallery",
                        systemImage: "photo"
                    ) {}
                    .overlay {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images
                        ) {
                            Color.clear
                        }
                    }
                }
                .padding(.horizontal)

                TextField(
                    "",
                    text: $caption,
                    prompt: Text("Add a caption")
                        .foregroundColor(themes.theme.inkSoft)
                )
                    .foregroundStyle(themes.theme.ink)
                    .padding(14)
                    .background(themes.theme.surface(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    Task { await sendInstant() }
                } label: {

                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedImage == nil
                        ? themes.theme.surface(0.9)
                        : themes.theme.solidButton(accent)
                    )
                    .foregroundColor(
                        selectedImage == nil ? themes.theme.inkSoft : .white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(selectedImage == nil || isSending)
                .padding(.horizontal)
            }
            .padding(.top, 6)
            .padding(.bottom, 20)
            // At least a screenful, so the Spacer above has room to push the
            // buttons to the bottom. Taller content still scrolls normally.
            .frame(minHeight: proxy.size.height, alignment: .top)
        }
        }
    }

    // MARK: - Buttons

    private func primaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            Label(title, systemImage: systemImage)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(themes.theme.solidButton(accent))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func secondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            Label(title, systemImage: systemImage)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(themes.theme.surface(0.9))
                .foregroundColor(themes.theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
    }

    // MARK: - Photo Card (no cropping, draggable caption)

    @ViewBuilder
    private func photoCard(
        image: UIImage,
        caption: String,
        captionPos: CGPoint,
        interactive: Bool,
        maxWidth: CGFloat = .infinity
    ) -> some View {

        // scaledToFit alone preserves the photo's aspect ratio, so the
        // caller can hand this whatever space is going spare and the
        // photo grows to fill it instead of sitting at a fixed size with
        // dead margins around it.
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay {

                GeometryReader { geo in

                    if !caption.isEmpty {

                        captionPill(text: caption)
                            .position(
                                x: captionPos.x * geo.size.width,
                                y: captionPos.y * geo.size.height
                            )
                            .gesture(
                                interactive
                                ? DragGesture()
                                    .onChanged { value in
                                        self.captionPos = CGPoint(
                                            x: min(max(value.location.x / geo.size.width, 0.08), 0.92),
                                            y: min(max(value.location.y / geo.size.height, 0.06), 0.94)
                                        )
                                    }
                                : nil
                            )
                    }
                }
            }
    }

    private func captionPill(text: String) -> some View {

        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.black.opacity(0.45))
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 220)
    }

    // MARK: - Logic

    private func resetComposer() {
        selectedImage = nil
        selectedItem = nil
        caption = ""
        captionPos = CGPoint(x: 0.5, y: 0.85)
    }

    private func listenForInstant() {

        FirestoreManager.shared.listenForInstantView { data in

            refreshPartnerImage(from: data)

            withAnimation(.easeInOut(duration: 0.4)) {
                instantData = data
                isLoading = false
            }
        }
    }

    private func sendInstant() async {

        guard let image = selectedImage else { return }
        isSending = true

        guard let base64 = image.instantBase64() else {
            isSending = false
            sendErrorMessage = "Couldn't prepare that photo. Try another one 💕"
            showSendError = true
            return
        }

        FirestoreManager.shared.sendInstant(
            imageBase64: base64,
            caption: caption.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            captionX: Double(captionPos.x),
            captionY: Double(captionPos.y),
            sender: me
        ) { error in

            DispatchQueue.main.async {

                isSending = false

                if error != nil {

                    sendErrorMessage = "Couldn't send. Check your connection 💕"
                    showSendError = true
                    return
                }

                petVM.pet.loveScore = min(100, petVM.pet.loveScore + 15)
                petVM.addEvent(
                    title: "Sent an Instant 📸",
                    person: me
                )

                withAnimation {
                    showSendUI = false
                    resetComposer()
                }
            }
        }
    }
}

// MARK: - Camera Picker (in-app camera)

private struct CameraPicker: UIViewControllerRepresentable {

    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {

        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate {

        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(
            _ picker: UIImagePickerController
        ) {
            parent.dismiss()
        }
    }
}

private extension UIImage {

    /// A base64 JPEG that still fits a Firestore document once base64 has
    /// added its third.
    ///
    /// This used to start at 480px and quality 0.5 inside a 220 KB budget,
    /// which is why instants arrived soft — an instant is shown nearly
    /// full-screen, and 480px across a phone's width is roughly a third of
    /// the pixels the screen asks for. The ceiling was never the reason for
    /// it: Firestore allows 1,048,576 bytes a document, and a scrapbook
    /// photo in this same app already ships at 1600px inside 500 KB.
    ///
    /// Matched to that now. 500 KB encodes to about 667 KB of base64, which
    /// leaves comfortable room for the caption and the rest of the fields.
    /// The ladder still steps down until something fits, so a send can't
    /// start failing on a photo that used to go through.
    func instantBase64(maxBytes: Int = 500_000) -> String? {

        // Try progressively smaller dimensions until it fits.
        for maxSide in [1600, 1280, 1024, 800] as [CGFloat] {

            let resized = resizedForInstant(maxSide: maxSide)
            var quality: CGFloat = 0.78

            while quality >= 0.4 {

                if let data = resized.jpegData(compressionQuality: quality),
                   data.count <= maxBytes {
                    return data.base64EncodedString()
                }
                quality -= 0.08
            }
        }

        // Last resort — still far above where this used to start.
        return resizedForInstant(maxSide: 640)
            .jpegData(compressionQuality: 0.4)?
            .base64EncodedString()
    }

    func resizedForInstant(maxSide: CGFloat) -> UIImage {

        let scale = min(maxSide / size.width, maxSide / size.height, 1.0)
        let newSize = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )

        // Force scale 1 so pixel size == logical size (no 2x/3x blow-up).
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(
            size: newSize,
            format: format
        )
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
