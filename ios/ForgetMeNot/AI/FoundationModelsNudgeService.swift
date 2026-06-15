import Foundation
import FoundationModels

/// On-device nudge generation via Apple's Foundation Models. Falls back to a static
/// prompt only if the system model reports unavailable or generation errors.
@available(iOS 26.0, *)
struct FoundationModelsNudgeService: NudgeService {
    func nudge(for task: TaskDTO) async -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            return StaticNudge.text(for: task)
        }
        do {
            let session = LanguageModelSession {
                """
                You are a calm, concrete coach helping someone start a task they keep \
                putting off. The block is the decision, not the doing. Reply with ONE \
                short sentence (max 14 words) naming the smallest concrete first physical \
                action to begin right now. No preamble, no emoji, no quotes.
                """
            }
            let response = try await session.respond(to: prompt(for: task))
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? StaticNudge.text(for: task) : text
        } catch {
            return StaticNudge.text(for: task)
        }
    }

    private func prompt(for task: TaskDTO) -> String {
        var parts = ["Task: \(task.title)."]
        if !task.domain.isEmpty { parts.append("Area: \(task.domain).") }
        let ratio = Urgency.ratio(task)
        if ratio >= 1 { parts.append("It is overdue.") }
        else if ratio >= 0.75 { parts.append("It is due very soon.") }
        return parts.joined(separator: " ") + " Give the nudge."
    }
}
