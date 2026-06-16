import Foundation
import FoundationModels

/// On-device nudge generation via Apple's Foundation Models. Falls back to a static
/// prompt only if the system model reports unavailable or generation errors.
@available(iOS 26.0, *)
struct FoundationModelsNudgeService: NudgeService {
    func nudge(for task: TaskDTO, intensity: Int) async -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            return StaticNudge.text(for: task, intensity: intensity)
        }
        do {
            let session = LanguageModelSession {
                """
                You coach someone to start a task they keep avoiding. The block is the \
                decision, not the doing. Reply with ONE short sentence naming the smallest \
                concrete first physical action. No preamble, no emoji, no quotes. Match the \
                requested urgency exactly.
                """
            }
            let text = try await session.respond(to: prompt(for: task, intensity: intensity))
                .content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? StaticNudge.text(for: task, intensity: intensity) : text
        } catch {
            return StaticNudge.text(for: task, intensity: intensity)
        }
    }

    private func prompt(for task: TaskDTO, intensity: Int) -> String {
        var parts = ["Task: \(task.title)."]
        if !task.description.isEmpty { parts.append("Detail: \(task.description).") }
        if !task.domain.isEmpty { parts.append("Area: \(task.domain).") }
        let tone: String
        switch intensity {
        case 0: tone = "Tone: calm, encouraging. Max 14 words."
        case 1...2: tone = "It is overdue. Tone: urgent and direct. Max 12 words."
        case 3...5: tone = "Badly overdue. Tone: insistent, a little frantic. Max 9 words."
        default: tone = "Extremely overdue. Tone: FRANTIC, near ALL-CAPS, like an alarm. Max 7 words."
        }
        let voice = (UserDefaults.standard.string(forKey: "fmn.nudgeStyle") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let persona = voice.isEmpty ? "" : " Write it as: \(voice)."
        return parts.joined(separator: " ") + " " + tone + persona + " Give the nudge."
    }
}
