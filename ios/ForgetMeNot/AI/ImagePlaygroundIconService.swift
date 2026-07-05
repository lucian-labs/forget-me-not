import Foundation
import CoreGraphics
import ImagePlayground
import OSLog

/// On-device image generation via Apple's Image Playground (`ImageCreator`).
@available(iOS 26.0, *)
struct ImagePlaygroundIconService: IconService {
    private static let log = Logger(subsystem: "com.lucianlabs.forgetmenot", category: "imageplayground")

    // ImageCreator has no sync availability flag; creation throws if unsupported, which
    // generate() handles. On iOS 26 + Apple Intelligence (e.g. iPhone 17) it's available.
    var available: Bool { true }

    func generate(prompt: String) async -> CGImage? {
        let creator: ImageCreator
        do {
            creator = try await ImageCreator()
        } catch {
            Self.log.error("ImageCreator init failed: \(String(describing: error), privacy: .public)")
            return nil
        }
        do {
            // .animation is the only style that reliably generates on BOTH iOS and Mac
            // Catalyst (.sketch yields an empty stream on Catalyst). The rune/line look comes
            // from GoldInk.treat, which edge-detects this output — so it's platform-independent.
            for try await image in creator.images(for: [.text(prompt)], style: .animation, limit: 1) {
                return image.cgImage
            }
            Self.log.error("no image for: \(prompt, privacy: .public)")
        } catch {
            // The error reason (e.g. a content-guardrail rejection) is what we need to see.
            Self.log.error("generate failed [\(prompt, privacy: .public)]: \(String(describing: error), privacy: .public)")
        }
        return nil
    }
}
