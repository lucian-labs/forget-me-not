import Foundation
import CoreGraphics

/// Generates a task's icon from its title/description, with a mood that reflects how
/// overdue it is. Swappable: today it's on-device Image Playground; later a model trained
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

    static func prompt(task: TaskDTO) -> String {
        let mood = mood(for: Urgency.tier(for: Urgency.ratio(task)))
        let look = style.isEmpty ? defaultStyle : style
        let details = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return PromptField.iconTemplate.value
            .replacingOccurrences(of: "{style}", with: look)
            .replacingOccurrences(of: "{animal}", with: "")   // subjects removed; tolerate old overrides
            .replacingOccurrences(of: "{task}", with: task.title)
            .replacingOccurrences(of: "{details}", with: details)
            .replacingOccurrences(of: "{mood}", with: mood)
            .replacingOccurrences(of: " ()", with: "")   // details was empty
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Prompts to try in order: the user's full template first, then progressively simpler
    /// fallbacks built from the task's description/title. If the full prompt trips the image
    /// model's content guardrail (which silently fails generation — the "waterize" symptom),
    /// a barer prompt still yields an icon instead of leaving the task permanently blank.
    static func promptLadder(task: TaskDTO) -> [String] {
        let look = style.isEmpty ? defaultStyle : style
        let details = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let what = details.isEmpty ? task.title : details
        let full = prompt(task: task)
        // Fallbacks drop the mood (the most likely guardrail trigger at high urgency), then
        // go bare — described by what the task IS, not a random subject.
        let noMood = "a \(look) icon for \(what), plain solid background"
        let minimal = "a \(look) icon for \(what)".trimmingCharacters(in: .whitespaces)
        // Final attempt is task-agnostic — a weird title ("waterize") can't leave it blank.
        let generic = "a \(look) icon, plain solid background"
        var seen = Set<String>(), ladder: [String] = []
        for p in [full, noMood, minimal, generic] where !p.isEmpty && seen.insert(p).inserted { ladder.append(p) }
        return ladder.isEmpty ? ["a simple icon, plain solid background"] : ladder
    }

    static func service() -> any IconService {
        if #available(iOS 26.0, *) { return ImagePlaygroundIconService() }
        return UnavailableIconService()
    }
}
