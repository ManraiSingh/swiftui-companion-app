//
//  InstantView.swift
//  Ziggy
//
//  Created by Manrai Singh on 18/06/26.
//

import SwiftUI
import PhotosUI

struct InstantView: View {

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
    @State private var sendErrorMessage = ""

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.95, blue: 0.92),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

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
    private var partnerImage: UIImage? {
        guard
            let b64 = instantData?["imageBase64"] as? String,
            let data = Data(base64Encoded: b64)
        else { return nil }
        return UIImage(data: data)
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
                .foregroundColor(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            }

            Spacer()

            Text("Instant")
                .font(.headline)
                .foregroundColor(accent)

            Spacer()

            // invisible balancer to keep title centered
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
        .padding(.bottom, 6)
    }

    // MARK: - Partner Instant (opens directly)

    private var partnerInstantView: some View {

        VStack(spacing: 18) {

            Spacer()

            if let img = partnerImage {

                photoCard(
                    image: img,
                    caption: instantCaption ?? "",
                    captionPos: instantCaptionPos,
                    interactive: false
                )
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            }

            if let sender {
                Text("From \(sender)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

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
            .padding(.bottom, 24)
        }
    }

    // MARK: - Waiting View

    private var waitingView: some View {

        VStack(spacing: 18) {

            Spacer()

            if let img = partnerImage {

                photoCard(
                    image: img,
                    caption: instantCaption ?? "",
                    captionPos: instantCaptionPos,
                    interactive: false,
                    maxWidth: 240
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.black.opacity(0.04))
                )
                .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(accent.opacity(0.7))
                Text("Sent")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            Spacer()

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
            .padding(.bottom, 24)
        }
    }

    // MARK: - Send View

    private var sendView: some View {

        ScrollView {

            VStack(spacing: 18) {

                if let image = selectedImage {

                    photoCard(
                        image: image,
                        caption: caption,
                        captionPos: captionPos,
                        interactive: true
                    )
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    .padding(.top, 10)

                } else {

                    RoundedRectangle(cornerRadius: 26)
                        .fill(.white.opacity(0.7))
                        .frame(height: 340)
                        .overlay {

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 46, weight: .light))
                                .foregroundColor(accent.opacity(0.35))
                        }
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }

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

                TextField("Add a caption", text: $caption)
                    .padding(14)
                    .background(.white.opacity(0.85))
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
                        ? accent.opacity(0.3)
                        : accent
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(selectedImage == nil || isSending)
                .padding(.horizontal)
                .padding(.top, 4)

                Spacer(minLength: 30)
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
                .background(accent)
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
                .background(.white.opacity(0.9))
                .foregroundColor(accent)
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
        maxWidth: CGFloat = 320
    ) -> some View {

        let aspect = image.size.width / max(image.size.height, 1)

        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .aspectRatio(aspect, contentMode: .fit)
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

                petVM.pet.loveScore += 15
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

    /// Produces a small base64 JPEG so instants upload/download fast
    /// (kept well under ~220 KB — Firestore's limit is 1 MB).
    func instantBase64(maxBytes: Int = 220_000) -> String? {

        // Try progressively smaller dimensions until it fits.
        for maxSide in [480, 400, 320, 260] as [CGFloat] {

            let resized = resizedForInstant(maxSide: maxSide)
            var quality: CGFloat = 0.5

            while quality >= 0.25 {

                if let data = resized.jpegData(compressionQuality: quality),
                   data.count <= maxBytes {
                    return data.base64EncodedString()
                }
                quality -= 0.1
            }
        }

        // Last resort: smallest size, lowest quality.
        return resizedForInstant(maxSide: 280)
            .jpegData(compressionQuality: 0.25)?
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
