import Foundation
import Vision
import CoreImage
import UIKit

/// Image Playground can't emit alpha, so we cut the subject out with Vision's
/// foreground-instance mask — giving a transparent-background mascot that floats on
/// the card. Falls back to the original image if no subject is found.
enum BackgroundRemover {
    static func cutout(_ cgImage: CGImage) -> UIImage {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return UIImage(cgImage: cgImage) }
            let masked = try result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let ci = CIImage(cvPixelBuffer: masked)
            let context = CIContext()
            guard let out = context.createCGImage(ci, from: ci.extent) else {
                return UIImage(cgImage: cgImage)
            }
            return UIImage(cgImage: out)
        } catch {
            return UIImage(cgImage: cgImage)
        }
    }
}
