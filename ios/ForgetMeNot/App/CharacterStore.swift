import SwiftUI
import UIKit

/// Holds each task's generated mascot, cached to disk (Caches/characters/<id>.png) and
/// preloaded on launch so list rendering is a pure read (no mutation during view body).
@MainActor
@Observable
final class CharacterStore {
    private let service = Characters.service()
    private(set) var images: [String: UIImage] = [:]
    private(set) var generating: Set<String> = []

    var available: Bool { service.available }

    init() { preload() }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }

    /// Generate a fresh mascot for the task (a new random animal, mood from current urgency).
    func generate(for task: TaskDTO) async {
        guard service.available, !generating.contains(task.id) else { return }
        generating.insert(task.id)
        defer { generating.remove(task.id) }
        let prompt = Characters.prompt(animal: Characters.randomAnimal(), task: task)
        if let cg = await service.generate(prompt: prompt) {
            let img = UIImage(cgImage: cg)
            images[task.id] = img
            if let data = img.pngData() { try? data.write(to: url(task.id)) }
        }
    }

    // MARK: disk

    private var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("characters", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func url(_ id: String) -> URL { dir.appendingPathComponent("\(id).png") }

    private func preload() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "png" {
            if let img = UIImage(contentsOfFile: f.path) {
                images[f.deletingPathExtension().lastPathComponent] = img
            }
        }
    }
}
