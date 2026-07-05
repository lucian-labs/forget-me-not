import CoreImage
import CoreGraphics
import UIKit

/// Recolors a generated sketch into the app's logo look: gold ink on transparency.
/// Image Playground's `.sketch` gives dark strokes on light paper; we read that as an
/// ink mask, burn the paper away, and fill the strokes with a gold gradient (bright →
/// deep amber) so every task icon reads like the fmn brushstroke logo.
enum GoldInk {
    // CIContext is documented thread-safe; treat() runs off the main actor during generation.
    nonisolated(unsafe) private static let context = CIContext(options: [.cacheIntermediates: false])

    static func treat(_ cg: CGImage) -> UIImage {
        let src = CIImage(cgImage: cg)
        let extent = src.extent
        guard extent.width > 1, extent.height > 1 else { return UIImage(cgImage: cg) }

        // 1. Ink mask: luminance → invert (strokes become bright) → contrast + gamma burn the
        //    light paper down to zero while keeping the strokes, then route that into ALPHA.
        let luma = src.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            "inputGVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            "inputBVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])
        let inkAlpha = luma
            .applyingFilter("CIColorInvert")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0, kCIInputContrastKey: 1.5, kCIInputBrightnessKey: -0.14,
            ])
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 1.5])   // thin the haze
            .applyingFilter("CIColorMatrix", parameters: [                      // luma → alpha
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            ])

        // 2. Gold gradient, bright top → deep amber bottom (the logo's metallic sheen).
        let gradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: extent.midX, y: extent.maxY),
            "inputPoint1": CIVector(x: extent.midX, y: extent.minY),
            "inputColor0": CIColor(red: 1.0, green: 0.855, blue: 0.46),
            "inputColor1": CIColor(red: 0.70, green: 0.47, blue: 0.10),
        ])?.outputImage?.cropped(to: extent)
        let gold = gradient ?? CIImage(color: CIColor(red: 0.95, green: 0.78, blue: 0.33)).cropped(to: extent)

        // 3. Clip the gold to the ink's alpha → gold strokes, everything else transparent.
        let out = gold.applyingFilter("CISourceInCompositing", parameters: [
            kCIInputBackgroundImageKey: inkAlpha,
        ])
        guard let cgOut = context.createCGImage(out, from: extent) else { return UIImage(cgImage: cg) }
        return UIImage(cgImage: cgOut)
    }
}
