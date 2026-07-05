import CoreImage
import CoreGraphics
import UIKit

/// Recolors a generated cartoon into the app's logo look: gold ink line-work on
/// transparency. Edge-detects the image so the subject becomes bright strokes on black
/// (its outline + interior contours — a "rune" of the thing), then fills those strokes
/// with a gold gradient so every task icon reads like the fmn brushstroke logo. Works on
/// any source (no dependence on Image Playground's `.sketch`, unavailable on Catalyst).
enum GoldInk {
    // CIContext is documented thread-safe; treat() runs off the main actor during generation.
    nonisolated(unsafe) private static let context = CIContext(options: [.cacheIntermediates: false])

    static func treat(_ cg: CGImage) -> UIImage {
        let src = CIImage(cgImage: cg)
        let extent = src.extent
        guard extent.width > 1, extent.height > 1 else { return UIImage(cgImage: cg) }

        // 1. Ink = edges. CIEdges makes the subject glow as bright line-work on black; brighten
        //    hard (gamma <1 + contrast) so strokes read BOLD not faint, dilate to fatten them
        //    into ink, then route the edge luminance straight into ALPHA (bright edge = opaque).
        //    Tuned against a Python prototype — bold gold outline, not a thin wireframe.
        let inkAlpha = src
            .applyingFilter("CIEdges", parameters: ["inputIntensity": 10.0])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0, kCIInputContrastKey: 1.5, kCIInputBrightnessKey: 0.08,
            ])
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.5])   // brighten strokes
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 2.0])  // fatten ink
            .applyingFilter("CIColorMatrix", parameters: [                      // luma → alpha
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0),
            ])
            .cropped(to: extent)   // morphology bleeds the edge; clamp back to the source frame

        // 2. Gold gradient, bright top → deep amber bottom (the logo's metallic sheen).
        let gradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: extent.midX, y: extent.maxY),
            "inputPoint1": CIVector(x: extent.midX, y: extent.minY),
            "inputColor0": CIColor(red: 1.0, green: 0.84, blue: 0.40),
            "inputColor1": CIColor(red: 0.86, green: 0.62, blue: 0.16),
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
