//
//  PhotoboothCamera.swift
//  Ziggy
//
//  The lens, and the trick that puts a backdrop behind you.
//
//  A booth needs a live preview and a shutter that fires on a countdown, so
//  this is a real `AVCaptureSession` rather than the image picker the Instant
//  screen uses — a picker is modal and waits for a tap, which is the one
//  thing a synchronised countdown cannot do.
//

import SwiftUI
@preconcurrency import AVFoundation
import Combine
import Vision
import UIKit

// MARK: - The lens

@MainActor
final class PhotoboothCamera: NSObject, ObservableObject {

    /// Whether there is a live preview to show. False on a simulator, which
    /// has no camera at all, and false until the session actually starts.
    @Published private(set) var isRunning = false

    /// Set when the person has said no, so the screen can explain itself
    /// instead of showing a black rectangle forever.
    @Published private(set) var accessDenied = false

    /// No camera on this device — a simulator, in practice.
    @Published private(set) var unavailable = false

    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "ziggy.photobooth.camera")
    private var configured = false
    private var pending: ((UIImage?) -> Void)?

    // MARK: Lifecycle

    func start() {

        #if targetEnvironment(simulator)
        // A simulator has no camera, which would leave anyone testing this
        // with one phone and one simulator unable to try the booth at all.
        // The stand-in lens makes the simulator a real second person: it
        // joins, counts down and hands up three frames like any other phone.
        //
        // Compiled in only for the simulator, so it cannot reach a shipped
        // build — a device build has no branch to take.
        isRunning = true
        return
        #else

        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            configureAndRun()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted { self.configureAndRun() } else { self.accessDenied = true }
                }
            }

        default:
            accessDenied = true
        }
        #endif
    }

    func stop() {
        guard configured else { return }
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        isRunning = false
    }

    private func configureAndRun() {

        guard !configured else {
            queue.async { [session] in
                if !session.isRunning { session.startRunning() }
            }
            isRunning = true
            return
        }

        // Front camera: a booth is a mirror you sit in front of.
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) ?? AVCaptureDevice.default(for: .video) else {
            unavailable = true
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            unavailable = true
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        configured = true

        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
        isRunning = true
    }

    // MARK: Shutter

    func capture(_ completion: @escaping (UIImage?) -> Void) {

        #if targetEnvironment(simulator)
        standInShot += 1
        completion(PhotoboothStandIn.frame(number: standInShot))
        return
        #else

        guard configured, isRunning else {
            completion(nil)
            return
        }

        pending = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        output.capturePhoto(with: settings, delegate: self)
        #endif
    }

    #if targetEnvironment(simulator)
    /// Which stand-in frame comes next, so the three shots are told apart.
    private var standInShot: Int {
        get { Self.standInCounter }
        set { Self.standInCounter = newValue }
    }
    private static var standInCounter = 0
    #endif
}

extension PhotoboothCamera: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {

        let raw: UIImage? = {
            guard error == nil,
                  let data = photo.fileDataRepresentation()
            else { return nil }
            return UIImage(data: data)
        }()

        Task { @MainActor in
            // The front camera records what the lens saw, not what you saw in
            // the preview. Mirroring it back is what makes the photo match
            // the person who just posed for it.
            let image = raw?.mirroredHorizontally()
            let handler = self.pending
            self.pending = nil
            handler?(image)
        }
    }
}

// MARK: - Preview

/// The live view, wrapped so SwiftUI can hold it.
struct PhotoboothPreview: View {

    let session: AVCaptureSession

    var body: some View {
        #if targetEnvironment(simulator)
        PhotoboothStandIn.PreviewCard()
        #else
        LivePreview(session: session)
        #endif
    }
}

/// The real thing, wrapped so SwiftUI can hold it.
struct LivePreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layer.session = session
        view.layer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.layer.session !== session { uiView.layer.session = session }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        override var layer: AVCaptureVideoPreviewLayer {
            super.layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Cutting you out

/// Replaces everything that isn't a person with a backdrop.
///
/// Vision returns a soft mask rather than a hard outline, which is what keeps
/// hair from turning into a cardboard edge — the mask is used as a blend, not
/// as a stencil. When it can't find anybody it returns the photo untouched,
/// so a backdrop can never turn a picture into a silhouette of nothing.
enum PhotoboothCutout {

    static func place(_ image: UIImage, on backdrop: PhotoboothBackdrop) -> UIImage {

        guard let colours = backdrop.colours,
              let cg = image.cgImage else { return image }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])

        guard (try? handler.perform([request])) != nil,
              let buffer = request.results?.first?.pixelBuffer
        else { return image }

        let source = CIImage(cgImage: cg)
        var mask = CIImage(cvPixelBuffer: buffer)

        // The mask comes back at Vision's own working size.
        mask = mask.transformed(by: CGAffineTransform(
            scaleX: source.extent.width / mask.extent.width,
            y: source.extent.height / mask.extent.height
        ))

        let behind = gradient(colours, extent: source.extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = behind
        blend.maskImage = mask

        guard let out = blend.outputImage,
              let result = PhotoboothDarkroom.context
                .createCGImage(out, from: source.extent)
        else { return image }

        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    private static func gradient(_ colours: [UIColor], extent: CGRect) -> CIImage {

        let g = CIFilter.linearGradient()
        g.point0 = CGPoint(x: extent.midX, y: extent.maxY)
        g.point1 = CGPoint(x: extent.midX, y: extent.minY)
        g.color0 = CIColor(color: colours.first ?? .gray)
        g.color1 = CIColor(color: colours.last ?? .darkGray)

        return g.outputImage?.cropped(to: extent)
            ?? CIImage(color: CIColor(color: colours.first ?? .gray)).cropped(to: extent)
    }
}

// MARK: - Helpers

extension UIImage {

    /// Flips left-for-right, keeping the pixels upright.
    func mirroredHorizontally() -> UIImage {

        guard let cg = cgImage else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: size.width, y: 0)
            c.scaleBy(x: -1, y: 1)
            UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
                .draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
