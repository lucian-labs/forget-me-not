import SwiftUI
import UIKit
import OSLog

/// Generates each task's icon once (on app open) and decodes any icon that synced in from
/// another device. The PNG lives on the task itself (AppStore.setIconImage → CloudKit), so a
/// device that can't generate — the Mac — still shows the icon another device made. Symbols
/// live on the task too (task.iconSymbol); this just renders the generated-image path.
@MainActor
@Observable
final class IconStore {
    private let service = Icons.service()
    private(set) var images: [String: UIImage] = [:]   // decoded cache (synced data or fresh gen)
    private(set) var generating: Set<String> = []
    private(set) var failed: Set<String> = []
    private var attempts: [String: Int] = [:]          // capped per session
    private let log = Logger(subsystem: "com.lucianlabs.forgetmenot", category: "icons")

    /// Persist a freshly generated PNG onto the task (wired to AppStore.setIconImage).
    var onGenerated: ((String, Data) -> Void)?
    /// Clear a task's stored image so it regenerates (Prompt Lab → Regenerate).
    var onCleared: ((String) -> Void)?

    var available: Bool { service.available }

    func image(for id: String) -> UIImage? { images[id] }
    func isGenerating(_ id: String) -> Bool { generating.contains(id) }
    func didFail(_ id: String) -> Bool { failed.contains(id) }

    /// Decode any synced icons into the cache (always — even where generation is unavailable),
    /// then generate the still-missing ones (only where the on-device model is available).
    func evolve(for tasks: [TaskDTO], now: Date = Date()) {
        for task in tasks where images[task.id] == nil {
            if let data = task.iconImageData, let img = UIImage(data: data) { images[task.id] = img }
        }
        guard service.available else { return }
        var pending: [TaskDTO] = []
        for task in tasks {
            if task.iconSymbol != nil { continue }       // shows a symbol, not an image
            if images[task.id] != nil { continue }       // already has one (synced or generated)
            if generating.contains(task.id) { continue }
            if (attempts[task.id] ?? 0) >= 3 { continue }
            pending.append(task)
        }
        guard !pending.isEmpty else { return }
        Task { for t in pending { await regenerate(t) } }
    }

    /// Manual reroll: drop the current icon and generate a new one.
    func generate(for task: TaskDTO) async {
        images[task.id] = nil
        generating.remove(task.id)
        failed.remove(task.id)
        await regenerate(task)
    }

    /// Prompt Lab "Regenerate": clear cached + stored icons, then re-generate.
    func regenerateAll(for tasks: [TaskDTO]) {
        images.removeAll()
        attempts.removeAll()
        for t in tasks { onCleared?(t.id) }
        evolve(for: tasks)
    }

    // MARK: internals

    private func regenerate(_ task: TaskDTO) async {
        guard service.available, !generating.contains(task.id) else { return }
        generating.insert(task.id)
        defer { generating.remove(task.id) }
        // Full prompt, then simpler fallbacks (a guardrail-tripping title can't leave it blank).
        for prompt in Icons.promptLadder(task: task) {
            log.info("gen \(task.title, privacy: .public) :: \(String(prompt.prefix(80)), privacy: .public)")
            if let (img, data) = await generateImage(prompt) {
                images[task.id] = img
                attempts[task.id] = 0
                failed.remove(task.id)
                onGenerated?(task.id, data)   // persist on the task → syncs to other devices
                log.info("ok \(task.title, privacy: .public)")
                return
            }
        }
        attempts[task.id, default: 0] += 1
        failed.insert(task.id)
        log.error("fail \(task.title, privacy: .public) attempt=\(self.attempts[task.id] ?? 0, privacy: .public)")
    }

    /// Generate + background-cut one prompt, time-boxed against a stall. Returns the decoded
    /// image and its PNG bytes. Heavy work runs off the main actor; only Data crosses back.
    private func generateImage(_ prompt: String) async -> (UIImage, Data)? {
        let svc = service
        let data = await withTimeout(25) { () -> Data? in
            guard let cg = await svc.generate(prompt: prompt) else { return nil }
            return BackgroundRemover.cutout(cg).pngData()
        }
        guard let data, let img = UIImage(data: data) else { return nil }
        return (img, data)
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
