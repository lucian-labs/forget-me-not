import SwiftUI
import UIKit

/// Holds + evolves each task's mascot. Throttled: renders at most twice a cycle — calm
/// (0%) and feral (100%) — only when crossing a new threshold for the current instance.
/// `rendered` is marked on SUCCESS only and self-heals if an entry exists without an
/// image, so a one-off generation failure (e.g. a flaky Image Playground call) retries
/// instead of leaving a permanently-blank mascot. Generation is serialized; images are
/// background-cut with Vision and cached to disk; the animal per task is remembered.
@MainActor
@Observable
final class CharacterStore {
    private let service = Characters.service()
    private(set) var images: [String: UIImage] = [:]
    private(set) var generating: Set<String> = []

    private var animals: [String: String] = [:]
    private struct RenderState { var inst: String; var threshold: Double }
    private var rendered: [String: RenderState] = [:]
    private struct PendingGen { let task: TaskDTO; let inst: String; let threshold: Double; let akey: String }
    private var queue: [PendingGen] = []
    private var attempts: [String: Int] = [:]   // per inst+threshold, capped per session
    private var running = false

    var available: Bool { service.available }

    init() { preload() }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }

    func imageURL(for id: String) -> URL? {
        let u = url(id)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    private static let thresholds: [Double] = [0.0, 1.0]

    func evolve(for tasks: [TaskDTO], now: Date = Date()) {
        guard service.available else { return }
        for task in tasks {
            let ratio = task.recurring ? Urgency.ratio(task, now: now) : 0
            let instKey = task.instance.map { String(Int($0.startedAt.timeIntervalSince1970)) } ?? "static"
            guard let crossed = Self.thresholds.last(where: { ratio >= $0 }) else { continue }
            // Skip only if we've rendered this level for this instance AND the image exists.
            if let r = rendered[task.id], r.inst == instKey, r.threshold >= crossed, images[task.id] != nil { continue }
            if generating.contains(task.id) { continue }
            if queue.contains(where: { $0.task.id == task.id }) { continue }
            let akey = "\(task.id)|\(instKey)|\(crossed)"
            if (attempts[akey] ?? 0) >= 3 { continue }   // gave up for this session
            if animals[task.id] == nil { setAnimal(Characters.randomAnimal(), for: task.id) }
            queue.append(PendingGen(task: task, inst: instKey, threshold: crossed, akey: akey))
        }
        drain()
    }

    /// Manual reroll from the detail view: a NEW animal at the current mood.
    func generate(for task: TaskDTO) async {
        let animal = Characters.randomAnimal()
        setAnimal(animal, for: task.id)
        let ratio = task.recurring ? Urgency.ratio(task) : 0
        let instKey = task.instance.map { String(Int($0.startedAt.timeIntervalSince1970)) } ?? "static"
        let crossed = Self.thresholds.last(where: { ratio >= $0 }) ?? 0
        await regenerate(PendingGen(task: task, inst: instKey, threshold: crossed, akey: "\(task.id)|manual"))
    }

    // MARK: internals

    private func drain() {
        guard !running, !queue.isEmpty else { return }
        running = true
        Task {
            while !queue.isEmpty {
                await regenerate(queue.removeFirst())
            }
            running = false
        }
    }

    private func regenerate(_ p: PendingGen) async {
        guard service.available, !generating.contains(p.task.id) else { return }
        generating.insert(p.task.id)
        defer { generating.remove(p.task.id) }
        let animal = animals[p.task.id] ?? Characters.randomAnimal()
        let prompt = Characters.prompt(animal: animal, task: p.task)
        print("[FMN] regenerate '\(p.task.title)' as \(animal) @\(p.threshold)")
        if let cg = await service.generate(prompt: prompt) {
            let img = BackgroundRemover.cutout(cg)
            images[p.task.id] = img
            if let data = img.pngData() { try? data.write(to: url(p.task.id)) }
            rendered[p.task.id] = RenderState(inst: p.inst, threshold: p.threshold)
            saveRendered()
            attempts[p.akey] = 0
            print("[FMN] OK '\(p.task.title)' size=\(img.size)")
        } else {
            attempts[p.akey, default: 0] += 1
            setAnimal(Characters.randomAnimal(), for: p.task.id)   // vary the creature on failure
            print("[FMN] FAIL '\(p.task.title)' attempt=\(attempts[p.akey] ?? 0)")
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
