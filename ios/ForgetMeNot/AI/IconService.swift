import Foundation
import CoreGraphics

/// Generates a task's icon — a cartoon alien animal whose mood reflects how overdue
/// the task is. Swappable: today it's on-device Image Playground; later a model trained
/// on Elijah's own drawings can drop in behind this protocol.
protocol IconService: Sendable {
    var available: Bool { get }
    func generate(prompt: String) async -> CGImage?
}

struct UnavailableIconService: IconService {
    var available: Bool { false }
    func generate(prompt: String) async -> CGImage? { nil }
}

enum Icons {
    /// The pool the {animal} token draws from — fully editable in the Prompt Lab.
    static var subjects: [String] {
        PromptField.iconSubjects.value
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func randomAnimal() -> String { subjects.randomElement() ?? "" }

    /// The "state of mind if you don't do it for too long" — editable per tier.
    static func mood(for tier: UrgencyTier) -> String {
        switch tier {
        case .calm: PromptField.moodCalm.value
        case .soon: PromptField.moodSoon.value
        case .due: PromptField.moodDue.value
        case .overdue: PromptField.moodOverdue.value
        }
    }

    /// Per-install style from Settings (woven into every icon prompt via {style}).
    static var style: String {
        (UserDefaults.standard.string(forKey: "fmn.iconStyle") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static var defaultStyle: String { PromptField.iconDefaultStyle.value }

    static func prompt(animal: String, task: TaskDTO) -> String {
        let mood = mood(for: Urgency.tier(for: Urgency.ratio(task)))
        let look = style.isEmpty ? defaultStyle : style
        let details = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return PromptField.iconTemplate.value
            .replacingOccurrences(of: "{style}", with: look)
            .replacingOccurrences(of: "{animal}", with: animal)
            .replacingOccurrences(of: "{task}", with: task.title)
            .replacingOccurrences(of: "{details}", with: details)
            .replacingOccurrences(of: "{mood}", with: mood)
            .replacingOccurrences(of: " ()", with: "")   // details was empty
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Prompts to try in order: the user's full template first, then progressively simpler
    /// fallbacks. If a task's title/details trip the image model's content guardrail (which
    /// silently fails generation — the "waterize" symptom), a barer prompt still yields an
    /// icon instead of leaving the task permanently blank.
    static func promptLadder(animal: String, task: TaskDTO) -> [String] {
        let look = style.isEmpty ? defaultStyle : style
        let m = mood(for: Urgency.tier(for: Urgency.ratio(task)))
        let full = prompt(animal: animal, task: task)
        let simple = "a \(look) \(animal), \(m), friendly, plain solid background"
        let minimal = "a \(look) \(animal)".trimmingCharacters(in: .whitespaces)
        var seen = Set<String>(), ladder: [String] = []
        for p in [full, simple, minimal] where !p.isEmpty && seen.insert(p).inserted { ladder.append(p) }
        return ladder.isEmpty ? ["a friendly icon, plain solid background"] : ladder
    }

    static func service() -> any IconService {
        if #available(iOS 26.0, *) { return ImagePlaygroundIconService() }
        return UnavailableIconService()
    }
}
