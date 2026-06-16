import SwiftUI
import UIKit

/// Holds + evolves each task's mascot. Throttled: the character renders at most twice a
/// cycle — calm (0%) and feral (100%) — and only when it crosses a *new* threshold for
/// its current instance (tracked persistently, so it does NOT regenerate every launch).
/// A reset re-arms it to calm. Generation is serialized; images are background-cut with
/// Vision and cached to disk. The chosen animal per task is remembered so regenerations
/// stay the same creature.
@MainActor
@Observable
final class CharacterStore {
    private let service = Characters.service()
    private(set) var images: [String: UIImage] = [:]
    private(set) var generating: Set<String> = []

    private var animals: [String: String] = [:]            // taskId -> animal (persisted)
    private struct RenderState { var inst: String; var threshold: Double }
    private var rendered: [String: RenderState] = [:]       // taskId -> last rendered (persisted)
    private var queue: [TaskDTO] = []
    private var running = false

    var available: Bool { service.available }

    init() { preload() }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }

    func imageURL(for id: String) -> URL? {
        let u = url(id)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// Calm at 0%, feral at 100%. (Richer evolution returns with a lighter generator —
    /// see docs/MASCOT_MODEL_HANDOFF.md.)
    private static let thresholds: [Double] = [0.0, 1.0]

    /// Drive evolution — call each tick. Regenerates only when a task crosses a higher
    /// threshold than last rendered for its current instance (or after a reset).
    func evolve(for tasks: [TaskDTO], now: Date = Date()) {
        guard service.available else { return }
        for task in tasks {
            let ratio = task.recurring ? Urgency.ratio(task, now: now) : 0
            let instKey = task.instance.map { String(Int($0.startedAt.timeIntervalSince1970)) } ?? "static"
            guard let crossed = Self.thresholds.last(where: { ratio >= $0 }) else { continue }
            if let r = rendered[task.id], r.inst == instKey, r.threshold >= crossed { continue }
            if generating.contains(task.id) { continue }
            rendered[task.id] = RenderState(inst: instKey, threshold: crossed)
            saveRendered()
            enqueue(task)
        }
        drain()
    }

    /// Manual reroll from the detail view: a NEW animal at the current mood.
    func generate(for task: TaskDTO) async {
        let animal = Characters.randomAnimal()
        setAnimal(animal, for: task.id)
        await regenerate(task, animal: animal)
    }

    // MARK: internals

    private func enqueue(_ task: TaskDTO) {
        if animals[task.id] == nil { setAnimal(Characters.randomAnimal(), for: task.id) }
        queue.removeAll { $0.id == task.id }
        queue.append(task)
    }

    private func drain() {
        guard !running, !queue.isEmpty else { return }
        running = true
        Task {
            while !queue.isEmpty {
                let task = queue.removeFirst()
                await regenerate(task, animal: animals[task.id] ?? Characters.randomAnimal())
            }
            running = false
        }
    }

    private func regenerate(_ task: TaskDTO, animal: String) async {
        guard service.available, !generating.contains(task.id) else { return }
        generating.insert(task.id)
        defer { generating.remove(task.id) }
        let prompt = Characters.prompt(animal: animal, task: task)   // mood = current urgency
        if let cg = await service.generate(prompt: prompt) {
            let img = BackgroundRemover.cutout(cg)   // transparent cutout
            images[task.id] = img
            if let data = img.pngData() { try? data.write(to: url(task.id)) }
        }
    }

    // MARK: persistence

    private var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("characters", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func url(_ id: String) -> URL { dir.appendingPathComponent("\(id).png") }

    private func setAnimal(_ animal: String, for id: String) {
        animals[id] = animal
        UserDefaults.standard.set(animals, forKey: "fmn.animals")
    }

    private func saveRendered() {
        UserDefaults.standard.set(rendered.mapValues { "\($0.inst)|\($0.threshold)" }, forKey: "fmn.rendered")
    }

    private func preload() {
        if let a = UserDefaults.standard.dictionary(forKey: "fmn.animals") as? [String: String] { animals = a }
        if let r = UserDefaults.standard.dictionary(forKey: "fmn.rendered") as? [String: String] {
            for (k, v) in r {
                let parts = v.split(separator: "|")
                if parts.count == 2, let t = Double(parts[1]) {
                    rendered[k] = RenderState(inst: String(parts[0]), threshold: t)
                }
            }
        }
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "png" {
            if let img = UIImage(contentsOfFile: f.path) {
                images[f.deletingPathExtension().lastPathComponent] = img
            }
        }
    }
}
