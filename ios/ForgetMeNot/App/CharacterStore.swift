import SwiftUI
import UIKit

/// Holds + evolves each task's mascot. The character changes at 25/50/75% of the cycle,
/// then follows the nudge cadence (90/100%+ escalating) — same animal throughout a cycle,
/// mood degrading from content to feral. A reset re-arms it back to calm. Image generation
/// is serialized (one at a time) so Image Playground isn't overloaded. Cached to disk;
/// the chosen animal per task is remembered so regenerations stay the same creature.
@MainActor
@Observable
final class CharacterStore {
    private let service = Characters.service()
    private(set) var images: [String: UIImage] = [:]
    private(set) var generating: Set<String> = []

    private var animals: [String: String] = [:]   // taskId -> animal (persisted)
    private var fired: Set<String> = []            // "taskId|instanceStart|threshold"
    private var queue: [TaskDTO] = []              // pending regens (latest mood per task)
    private var running = false

    var available: Bool { service.available }

    init() { preload() }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }

    func imageURL(for id: String) -> URL? {
        let u = url(id)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// 0% (initial), 25/50/75%, then the nudge cadence: 90/100% and escalating overdue steps.
    private static let thresholds: [Double] = {
        var ts = [0.0, 0.25, 0.5, 0.75, 0.9]
        var t = 1.0, gap = 0.1
        for _ in 0..<14 { ts.append(t); t += gap; gap = max(0.02, gap - 0.015) }
        return ts
    }()

    /// Drive evolution — call each tick. Enqueues a regeneration whenever a task crosses
    /// a new threshold for its current instance.
    func evolve(for tasks: [TaskDTO], now: Date = Date()) {
        guard service.available else { return }
        for task in tasks {
            let ratio = task.recurring ? Urgency.ratio(task, now: now) : 0
            let instKey = task.instance.map { String($0.startedAt.timeIntervalSince1970) } ?? "static"
            for threshold in Self.thresholds where ratio >= threshold {
                let key = "\(task.id)|\(instKey)|\(threshold)"
                if fired.contains(key) { continue }
                fired.insert(key)
                enqueue(task)
            }
        }
        drain()
    }

    /// Manual reroll from the detail view: a NEW animal at the current mood.
    func generate(for task: TaskDTO) async {
        let animal = Characters.randomAnimal()
        setAnimal(animal, for: task.id)
        await regenerate(task, animal: animal)
    }

    // MARK: evolution internals

    private func enqueue(_ task: TaskDTO) {
        if animals[task.id] == nil { setAnimal(Characters.randomAnimal(), for: task.id) }
        queue.removeAll { $0.id == task.id }   // collapse to the latest mood per task
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
            let img = UIImage(cgImage: cg)
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

    private func preload() {
        if let saved = UserDefaults.standard.dictionary(forKey: "fmn.animals") as? [String: String] {
            animals = saved
        }
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "png" {
            if let img = UIImage(contentsOfFile: f.path) {
                images[f.deletingPathExtension().lastPathComponent] = img
            }
        }
    }
}
