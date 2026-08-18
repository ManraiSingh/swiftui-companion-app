//
//  ZiggyPhotoSaver.swift
//  Ziggy
//
//  Putting a picture in the user's own photo library.
//
//  Asks for add-only permission rather than full library access: Ziggy has no
//  business reading anybody's photos, and iOS shows a noticeably gentler prompt
//  for the narrower request.
//

import Photos
import UIKit

enum ZiggyPhotoSaver {

    enum Outcome {
        case saved
        case denied
        case failed
    }

    /// Saves an image, asking permission the first time.
    ///
    /// The completion always lands on the main queue — the Photos framework
    /// answers on its own, and every caller here is a view.
    static func save(_ image: UIImage, completion: @escaping (Outcome) -> Void) {

        func finish(_ outcome: Outcome) {
            DispatchQueue.main.async { completion(outcome) }
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            guard status == .authorized || status == .limited else {
                finish(.denied)
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                finish(success ? .saved : .failed)
            }
        }
    }
}
