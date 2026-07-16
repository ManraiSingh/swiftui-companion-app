import SwiftUI
import PencilKit

struct DoodleView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var selectedHex = "#FF4FA3"
    @State private var brushWidth: CGFloat = 8
    @State private var isEraser = false
    @State private var isSending = false
    @State private var showSentToast = false

    @State private var partnerDoodle: UIImage?
    @State private var partnerDoodleSender = ""

    private let cream = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.94, blue: 0.93),
            Color(red: 0.95, green: 0.92, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let accent = Color(red: 0.27, green: 0.24, blue: 0.21)

    private let palette: [(hex: String, color: Color)] = [
        ("#FF4FA3", .pink),
        ("#9B5DE5", .purple),
        ("#00A6FB", .blue),
        ("#2DD4BF", .mint),
        ("#FFD166", .yellow),
        ("#F97316", .orange),
        ("#EF4444", .red),
        ("#111827", .black)
    ]

    private var username: String { UserManager.shared.username }

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                if let partnerDoodle {
                    partnerCard(partnerDoodle)
                }

                canvasCard

                toolbar

                sendButton
            }
            .padding()

            if showSentToast {
                toast
            }
        }
        .onAppear {
            configureTool()
            listenForPartner()
        }
        .onChange(of: selectedHex) { configureTool() }
        .onChange(of: brushWidth) { configureTool() }
        .onChange(of: isEraser) { configureTool() }
        .onDisappear {
            FirestoreManager.shared.stopDoodleListener()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(accent)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.84))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Doodle 🎨")
                    .font(.title2).fontWeight(.black)
                    .foregroundColor(accent)
                Text("Lands on their Home Screen")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Circle().fill(.clear).frame(width: 42, height: 42)
        }
    }

    // MARK: - Partner's latest doodle

    private func partnerCard(_ image: UIImage) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(width: 64, height: 64)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.pink.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("From \(partnerDoodleSender.isEmpty ? "your partner" : partnerDoodleSender)")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(accent)
                Text("Their latest doodle 💕")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Canvas

    private var canvasCard: some View {
        DoodleCanvas(canvasView: canvasView)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(palette, id: \.hex) { item in
                    Button {
                        selectedHex = item.hex
                        isEraser = false
                    } label: {
                        Circle()
                            .fill(item.color)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selectedHex == item.hex && !isEraser {
                                    Circle().stroke(.white, lineWidth: 3)
                                }
                            }
                            .shadow(radius: selectedHex == item.hex ? 3 : 0)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 14) {
                Image(systemName: "pencil.tip").foregroundStyle(.secondary)

                Slider(value: $brushWidth, in: 3...26)

                toolButton(system: "eraser.fill", active: isEraser) {
                    isEraser.toggle()
                }
                toolButton(system: "arrow.uturn.backward", active: false) {
                    canvasView.undoManager?.undo()
                }
                toolButton(system: "trash", active: false, tint: .red) {
                    canvasView.drawing = PKDrawing()
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func toolButton(
        system: String,
        active: Bool,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .foregroundColor(active ? .white : (tint ?? accent))
                .frame(width: 38, height: 38)
                .background(active ? accent : Color.white.opacity(0.85))
                .clipShape(Circle())
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack {
                if isSending { ProgressView().tint(.white) }
                Text(isSending ? "Sending…" : "Send to their widget 🎨")
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.pink, Color(red: 0.95, green: 0.55, blue: 0.6)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .disabled(isSending)
    }

    private var toast: some View {
        Text("Sent 🎉")
            .font(.headline).fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(.black.opacity(0.75))
            .clipShape(Capsule())
    }

    // MARK: - Logic

    private func configureTool() {
        if isEraser {
            canvasView.tool = PKEraserTool(.bitmap)
        } else {
            canvasView.tool = PKInkingTool(
                .pen,
                color: UIColor(hex: selectedHex),
                width: brushWidth
            )
        }
    }

    private func listenForPartner() {
        FirestoreManager.shared.listenForDoodle { data in
            // Compare device IDs, not display names — two partners with the
            // same name would otherwise make every doodle look like "my own."
            guard
                let base64 = data?["imageBase64"] as? String,
                let sender = data?["sender"] as? String,
                let senderDeviceID = data?["senderDeviceID"] as? String,
                senderDeviceID != FirestoreManager.shared.currentDeviceID,
                let raw = Data(base64Encoded: base64),
                let image = UIImage(data: raw)
            else { return }

            // Push the doodle onto our widget too. This covers the app-open
            // case; the Cloud Function push covers the app-closed case.
            WidgetDataManager.shared.cachePartnerDoodle(base64: base64, sender: sender)

            DispatchQueue.main.async {
                partnerDoodle = image
                partnerDoodleSender = sender
            }
        }
    }

    private func send() {
        guard !canvasView.drawing.strokes.isEmpty else { return }
        isSending = true

        let exported = exportDrawing()
        let resized = downscale(exported, maxDimension: 700)
        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            isSending = false
            return
        }
        let base64 = data.base64EncodedString()

        FirestoreManager.shared.sendDoodle(
            imageBase64: base64,
            sender: username
        ) { error in
            DispatchQueue.main.async {
                isSending = false
                guard error == nil else { return }
                canvasView.drawing = PKDrawing()
                withAnimation { showSentToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { showSentToast = false }
                }
            }
        }
    }

    private func exportDrawing() -> UIImage {
        let size = canvasView.bounds.size == .zero
            ? CGSize(width: 600, height: 600)
            : canvasView.bounds.size

        let drawingImage = canvasView.drawing.image(
            from: CGRect(origin: .zero, size: size),
            scale: UIScreen.main.scale
        )

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            drawingImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - PencilKit canvas wrapper

struct DoodleCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

private extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

#Preview {
    DoodleView()
}
