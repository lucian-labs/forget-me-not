import Foundation
import CoreGraphics
import ImagePlayground

/// On-device image generation via Apple's Image Playground (`ImageCreator`).
@available(iOS 26.0, *)
struct ImagePlaygroundCharacterService: CharacterService {
    // ImageCreator has no sync availability flag; creation throws if unsupported, which
    // generate() handles. On iOS 26 + Apple Intelligence (e.g. iPhone 17) it's available.
    var available: Bool { true }

    func generate(prompt: String) async -> CGImage? {
        let creator: ImageCreator
        do {
            creator = try await ImageCreator()
        } catch {
            print("[FMN] ImageCreator init FAILED: \(error)")
            return nil
        }
        do {
            for try await image in creator.images(for: [.text(prompt)], style: .animation, limit: 1) {
                return image.cgImage
            }
            print("[FMN] no image returned for: \(prompt.prefix(60))")
        } catch {
            print("[FMN] generate FAILED [\(prompt.prefix(60))]: \(error)")
        }
        return nil
    }
}
