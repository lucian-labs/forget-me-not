import SwiftUI
import UIKit
import OSLog

/// Holds + evolves each task's icon. Reconciles on app open (not on a timer): each
/// icon renders at most twice a cycle — calm (0%) and feral (100%) — when its on-disk
/// render no longer matches the tier the task is in right now. `rendered` is marked on
/// SUCCESS only and self-heals if an entry exists without an image, so a one-off failure
/// (e.g. a flaky Image Playground call) retries instead of leaving a blank icon.
/// One pass at a time; images are background-cut with Vision and cached to disk.
@MainActor
@Observable
final class IconStore {
    private let service = Icons.service()
    private(set) var images: [String: UIImage] = [:]
    private(set) var generating: Set<String> = []

    private var animals: [String: String] = [:]
    private var symbols: [String: String] = [:]   // task id → SF Symbol name (overrides the image)
    private struct RenderState { var inst: String; var threshold: Double }
    private var rendered: [String: RenderState] = [:]
    private struct PendingGen { let task: TaskDTO; let inst: String; let threshold: Double; let akey: String }
    private var attempts: [String: Int] = [:]   // per inst+threshold, capped per session
    private let log = Logger(subsystem: "com.lucianlabs.forgetmenot", category: "icons")

    var available: Bool { service.available }

    init() { preload() }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }
    func animal(for id: String) -> String? { animals[id] }

    /// An SF Symbol name set for this task, if any. When set, it's shown instead of a
    /// generated image and no image is generated for the task.
    func symbol(for id: String) -> String? { symbols[id] }

    /// Set (or clear, with nil) the task's SF Symbol. Setting one drops any generated image
    /// so the symbol shows; clearing lets generation take over again.
    func setSymbol(_ name: String?, for id: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            symbols[id] = trimmed
            images[id] = nil
            rendered[id] = nil
            try? FileManager.default.removeItem(at: url(id))
        } else {
            symbols[id] = nil
        }
        UserDefaults.standard.set(symbols, forKey: "fmn.iconSymbols")
    }

    func imageURL(for id: String) -> URL? {
        let u = url(id)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    private static let thresholds: [Double] = [0.0, 1.0]

    /// Reconcile every icon to the task's CURRENT urgency in a single pass — called when the
    /// app opens, not on a timer. Only tasks whose on-disk render no longer matches the tier
    /// they're in now are (re)generated. Per-task `generating` guards dedupe overlap, so no
    /// global "running" latch is needed (a stuck latch was a way to wedge all generation).
    func evolve(for tasks: [TaskDTO], now: Date = Date()) {
        guard service.available else { return }
        var pending: [PendingGen] = []
        for task in tasks {
            if symbols[task.id] != nil { continue }   // task uses an SF Symbol, not a generated image
            let ratio = task.recurring ? Urgency.ratio(task, now: now) : 0
            let instKey = task.instance.map { String(Int($0.startedAt.timeIntervalSince1970)) } ?? "static"
            guard let crossed = Self.thresholds.last(where: { ratio >= $0 }) else { continue }
            // Skip only if we've rendered this level for this instance AND the image exists.
            if let r = rendered[task.id], r.inst == instKey, r.threshold >= crossed, images[task.id] != nil { continue }
            if generating.contains(task.id) { continue }
            let akey = "\(task.id)|\(instKey)|\(crossed)"
            if (attempts[akey] ?? 0) >= 3 { continue }   // gave up for this session
            if animals[task.id] == nil { setAnimal(Icons.randomAnimal(), for: task.id) }
            pending.append(PendingGen(task: task, inst: instKey, threshold: crossed, akey: akey))
        }
        guard !pending.isEmpty else { return }
        Task { for p in pending { await regenerate(p) } }
    }

    /// Wipe every cached icon and re-render from the CURRENT prompt config — used after
    /// editing prompts in the lab so changes show immediately. Re-picks subjects so
    /// edits to the subject list / template take effect too.
    func regenerateAll(for tasks: [TaskDTO]) {
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

    /// Manual reroll from the detail view: generate a NEW image (and drop any SF Symbol).
    /// Clears any stuck per-task state first so a wedged task can always be retried by hand.
    func generate(for task: TaskDTO) async {
        if symbols[task.id] != nil { setSymbol(nil, for: task.id) }
        generating.remove(task.id)
        let animal = Icons.randomAnimal()
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
        let animal = animals[p.task.id] ?? Icons.randomAnimal()
        // Try the full prompt, then simpler fallbacks — so a guardrail-tripping title can't
        // leave the task permanently blank. Each attempt is time-boxed against a stall.
        for prompt in Icons.promptLadder(animal: animal, task: p.task) {
            log.info("gen \(p.task.title, privacy: .public) @\(p.threshold, privacy: .public) :: \(String(prompt.prefix(80)), privacy: .public)")
            if let img = await generateImage(prompt) {
                images[p.task.id] = img
                if let data = img.pngData() { try? data.write(to: url(p.task.id)) }
                rendered[p.task.id] = RenderState(inst: p.inst, threshold: p.threshold)
                saveRendered()
                attempts[p.akey] = 0
                log.info("ok \(p.task.title, privacy: .public)")
                return
            }
        }
        attempts[p.akey, default: 0] += 1
        setAnimal(Icons.randomAnimal(), for: p.task.id)   // vary the subject for the next pass
        log.error("fail \(p.task.title, privacy: .public) attempt=\(self.attempts[p.akey] ?? 0, privacy: .public)")
    }

    /// Generate + background-cut one prompt, time-boxed so a hung image call can't wedge the
    /// `generating` flag. Heavy work happens off the main actor; only PNG bytes cross back.
    private func generateImage(_ prompt: String) async -> UIImage? {
        let svc = service
        let data = await withTimeout(25) { () -> Data? in
            guard let cg = await svc.generate(prompt: prompt) else { return nil }
            return BackgroundRemover.cutout(cg).pngData()
        }
        return data.flatMap(UIImage.init(data:))
    }

    // MARK: persistence

    private var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("icons", isDirectory: true)
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
        if let s = UserDefaults.standard.dictionary(forKey: "fmn.iconSymbols") as? [String: String] { symbols = s }
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

/// Race an async op against a deadline; returns nil on timeout. Keeps a stalled on-device
/// model call from wedging state forever.
func withTimeout<T: Sendable>(_ seconds: Double, _ op: @Sendable @escaping () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await op() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
