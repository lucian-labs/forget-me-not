import SwiftUI
import UIKit

/// Holds + evolves each task's mascot. Reconciles on app open (not on a timer): each
/// mascot renders at most twice a cycle — calm (0%) and feral (100%) — when its on-disk
/// render no longer matches the tier the task is in right now. `rendered` is marked on
/// SUCCESS only and self-heals if an entry exists without an image, so a one-off failure
/// (e.g. a flaky Image Playground call) retries instead of leaving a blank mascot.
/// One pass at a time; images are background-cut with Vision and cached to disk.
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
    private var attempts: [String: Int] = [:]   // per inst+threshold, capped per session
    private var running = false

    var available: Bool { service.available }

    init() { preload() }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }
    func animal(for id: String) -> String? { animals[id] }

    func imageURL(for id: String) -> URL? {
        let u = url(id)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    private static let thresholds: [Double] = [0.0, 1.0]

    /// Reconcile every mascot to the task's CURRENT urgency in a single pass — called when
    /// the app opens, not on a timer. Only tasks whose on-disk render no longer matches the
    /// tier they're in now are (re)generated. The `running` guard means a second open while
    /// a pass is in flight is a no-op rather than a pile-up.
    func evolve(for tasks: [TaskDTO], now: Date = Date()) {
        guard service.available, !running else { return }
        var pending: [PendingGen] = []
        for task in tasks {
            let ratio = task.recurring ? Urgency.ratio(task, now: now) : 0
            let instKey = task.instance.map { String(Int($0.startedAt.timeIntervalSince1970)) } ?? "static"
            guard let crossed = Self.thresholds.last(where: { ratio >= $0 }) else { continue }
            // Skip only if we've rendered this level for this instance AND the image exists.
            if let r = rendered[task.id], r.inst == instKey, r.threshold >= crossed, images[task.id] != nil { continue }
            if generating.contains(task.id) { continue }
            let akey = "\(task.id)|\(instKey)|\(crossed)"
            if (attempts[akey] ?? 0) >= 3 { continue }   // gave up for this session
            if animals[task.id] == nil { setAnimal(Characters.randomAnimal(), for: task.id) }
            pending.append(PendingGen(task: task, inst: instKey, threshold: crossed, akey: akey))
        }
        guard !pending.isEmpty else { return }
        running = true
        Task {
            for p in pending { await regenerate(p) }
            running = false
        }
    }

    /// Wipe every cached mascot and re-render from the CURRENT prompt config — used after
    /// editing prompts in the lab so changes show immediately. Re-picks subjects so
    /// edits to the subject list / template take effect too.
    func regenerateAll(for tasks: [TaskDTO]) {
        running = false
        images.removeAll()
        rendered.removeAll()
        attempts.removeAll()
        animals.removeAll()
        UserDefaults.standard.removeObject(forKey: "fmn.animals")
        UserDefaults.standard.removeObject(forKey: "fmn.rendered")
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension == "png" { try? FileManager.default.removeItem(at: f) }
        }
        evolve(for: tasks)
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
